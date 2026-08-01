// =====================================================================
// branch_predictor_btb16.v
//
// Dynamic branch predictor for an 8-bit-addressed, 32-bit-instruction
// machine, with:
//    - 16-entry BHT of 2-bit saturating counters (4-bit index)
//    - 16-entry tagged BTB (target address cache)
//    - Full pipeline integration: predicts in IF, carries the
//      prediction to EX, compares against the real outcome, and
//      generates flush + redirect signals on a misprediction.
//
// All 4 pieces (bht, btb, top-level unit, testbench) live in this one
// file for convenience.
//
// -----------------------------------------------------------------
// PIPELINE PICTURE
// -----------------------------------------------------------------
//     IF          ID          EX
//   predict ---------------> resolve
//   (BHT+BTB                (compare vs prediction,
//    lookup)                 update BHT/BTB,
//                             flush + redirect on miss)
//
// Because this design resolves branches in EX, a misprediction costs
// a 2-cycle bubble: the instructions sitting in IF and ID at the
// moment the branch resolves were fetched under the wrong assumption
// and must be squashed.
// =====================================================================


// =====================================================================
// bht  --  16 x 2-bit saturating counters
//   00 = Strong Not-Taken   01 = Weak Not-Taken
//   10 = Weak Taken         11 = Strong Taken
//   Prediction = MSB of the counter.
// =====================================================================
module bht #(
    parameter PC_WIDTH   = 8,
    parameter INDEX_BITS = 4          // 4 bits -> 16 entries
)(
    input  wire                  clk,
    input  wire                  rst,

    // Read port (IF, combinational)
    input  wire [PC_WIDTH-1:0]   pc_read,
    output wire                  predict_taken,

    // Write port (EX, one cycle after a branch resolves)
    input  wire                  update_en,
    input  wire [PC_WIDTH-1:0]   pc_write,
    input  wire                  actual_taken
);
    localparam DEPTH = (1 << INDEX_BITS);

    reg [1:0] counter [0:DEPTH-1];

    wire [INDEX_BITS-1:0] rd_idx = pc_read [INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] wr_idx = pc_write[INDEX_BITS+1:2];

    reg [1:0] next_val;
    always @(*) begin
        if (actual_taken)
            next_val = (counter[wr_idx] == 2'b11) ? 2'b11 : counter[wr_idx] + 2'b01;
        else
            next_val = (counter[wr_idx] == 2'b00) ? 2'b00 : counter[wr_idx] - 2'b01;
    end

    // Read-during-write forwarding, so a branch re-fetched the very next
    // cycle after its own update sees the fresh value, not a stale one.
    wire same_entry = update_en && (rd_idx == wr_idx);
    assign predict_taken = same_entry ? next_val[1] : counter[rd_idx][1];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                counter[i] <= 2'b01;      // reset: weakly not-taken
        end else if (update_en) begin
            counter[wr_idx] <= next_val;
        end
    end
endmodule


// =====================================================================
// btb  --  16-entry tagged, direct-mapped Branch Target Buffer
//   Stores the target address of previously-taken branches so IF can
//   redirect fetch immediately, without waiting for EX. Tagged, so a
//   different address that happens to alias to the same index doesn't
//   silently hand back the wrong target.
// =====================================================================
module btb #(
    parameter PC_WIDTH   = 8,
    parameter INDEX_BITS = 4
)(
    input  wire                  clk,
    input  wire                  rst,

    // Lookup port (IF)
    input  wire [PC_WIDTH-1:0]   pc_lookup,
    output wire                  hit,
    output wire [PC_WIDTH-1:0]   target_out,

    // Update port (EX, when a branch resolves taken)
    input  wire                  update_en,
    input  wire [PC_WIDTH-1:0]   pc_update,
    input  wire [PC_WIDTH-1:0]   target_in
);
    localparam DEPTH    = (1 << INDEX_BITS);
    localparam TAG_BITS = PC_WIDTH - INDEX_BITS - 2;

    reg                  valid  [0:DEPTH-1];
    reg [TAG_BITS-1:0]   tag    [0:DEPTH-1];
    reg [PC_WIDTH-1:0]   target [0:DEPTH-1];

    wire [INDEX_BITS-1:0] rd_idx = pc_lookup[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   rd_tag = pc_lookup[PC_WIDTH-1:INDEX_BITS+2];

    wire [INDEX_BITS-1:0] wr_idx = pc_update[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   wr_tag = pc_update[PC_WIDTH-1:INDEX_BITS+2];

    assign hit        = valid[rd_idx] && (tag[rd_idx] == rd_tag);
    assign target_out = target[rd_idx];

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                valid[i] <= 1'b0;
        end else if (update_en) begin
            valid [wr_idx] <= 1'b1;
            tag   [wr_idx] <= wr_tag;
            target[wr_idx] <= target_in;
        end
    end
endmodule


// =====================================================================
// branch_predictor_unit  --  top level: wires BHT + BTB into the
// pipeline, carries the prediction from IF down to EX, and generates
// misprediction / flush / redirect signals.
// =====================================================================
module branch_predictor_unit #(
    parameter PC_WIDTH   = 8,
    parameter INDEX_BITS = 4
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  stall,        // tie to 0 if you have no other hazard stalls

    // ---------------- IF stage ----------------
    input  wire [PC_WIDTH-1:0]   pc_if,
    output wire                  predict_taken_if,
    output wire [PC_WIDTH-1:0]   next_pc,

    // ---------------- EX stage: real branch resolution ----------------
    input  wire [PC_WIDTH-1:0]   pc_ex,          // PC of the branch now in EX
    input  wire                  is_branch_ex,   // 1 if EX instruction is a branch
    input  wire                  actual_taken_ex,
    input  wire [PC_WIDTH-1:0]   actual_target_ex,
    input  wire [PC_WIDTH-1:0]   pc_plus4_ex,    // fall-through address

    // ---------------- Pipeline control outputs ----------------
    output wire                  mispredict,
    output wire [PC_WIDTH-1:0]   correct_pc,
    output wire                  flush_if,       // squash instr currently in IF
    output wire                  flush_id        // squash instr currently in ID
);

    wire                 btb_hit;
    wire [PC_WIDTH-1:0]  btb_target;

    btb #(.PC_WIDTH(PC_WIDTH), .INDEX_BITS(INDEX_BITS)) u_btb (
        .clk        (clk),
        .rst        (rst),
        .pc_lookup  (pc_if),
        .hit        (btb_hit),
        .target_out (btb_target),
        .update_en  (is_branch_ex && actual_taken_ex),
        .pc_update  (pc_ex),
        .target_in  (actual_target_ex)
    );

    wire bht_raw_predict;

    bht #(.PC_WIDTH(PC_WIDTH), .INDEX_BITS(INDEX_BITS)) u_bht (
        .clk           (clk),
        .rst           (rst),
        .pc_read       (pc_if),
        .predict_taken (bht_raw_predict),
        .update_en     (is_branch_ex),
        .pc_write      (pc_ex),
        .actual_taken  (actual_taken_ex)
    );

    // A "taken" prediction only means something if we also have a target
    // for it -- if the BTB hasn't seen this PC, fetch sequentially
    // regardless of what the (possibly stale/aliased) BHT counter says.
    assign predict_taken_if = btb_hit & bht_raw_predict;
    assign next_pc          = predict_taken_if ? btb_target : (pc_if + 4);

    // Shadow latches: carry this cycle's prediction down through the
    // pipeline alongside the instruction, so it's available for
    // comparison once that instruction reaches EX.
    reg                  pred_taken_ifid,  pred_taken_idex;
    reg [PC_WIDTH-1:0]   pred_target_ifid, pred_target_idex;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pred_taken_ifid  <= 1'b0;
            pred_target_ifid <= {PC_WIDTH{1'b0}};
            pred_taken_idex  <= 1'b0;
            pred_target_idex <= {PC_WIDTH{1'b0}};
        end else if (!stall) begin
            pred_taken_ifid  <= flush_if ? 1'b0 : predict_taken_if;
            pred_target_ifid <= next_pc;

            pred_taken_idex  <= flush_id ? 1'b0 : pred_taken_ifid;
            pred_target_idex <= pred_target_ifid;
        end
    end

    // Misprediction check (EX): prediction that was made for this
    // branch back in IF, vs. what actually happened.
    assign mispredict = is_branch_ex &&
                         ( (actual_taken_ex != pred_taken_idex) ||
                           (actual_taken_ex && (actual_target_ex != pred_target_idex)) );

    assign correct_pc = actual_taken_ex ? actual_target_ex : pc_plus4_ex;

    assign flush_if = mispredict;
    assign flush_id = mispredict;

endmodule


// =====================================================================
// Testbench
//
// Program (8-bit, word-aligned addresses):
//   0x00  (ordinary)
//   0x04  (ordinary)                 <- loop body
//   0x08  BRANCH -> 0x04             (taken x4, then falls through)
//   0x0C  (ordinary)                 <- loop exit
//   0x10  BRANCH -> 0x20             (always taken)
//   0x20..0x44  (ordinary, just flowing through)
//   0x48  BRANCH -> 0x4C             (always taken; ALIASES with 0x08:
//                                      with a 16-entry table, index
//                                      repeats every 0x40, and
//                                      0x48 - 0x08 = 0x40)
//   0x4C  (ordinary, end)
// =====================================================================
module tb_branch_predictor_btb16;

    localparam PC_WIDTH   = 8;
    localparam INDEX_BITS = 4;   // 16 entries

    reg clk = 0;
    reg rst = 1;
    reg stall = 0;

    reg [PC_WIDTH-1:0] pc_if_reg;

    wire predict_taken_if;
    wire [PC_WIDTH-1:0] next_pc;
    wire mispredict;
    wire [PC_WIDTH-1:0] correct_pc;
    wire flush_if, flush_id;

    reg                  valid_ifid, valid_idex;
    reg [PC_WIDTH-1:0]   pc_ifid,    pc_idex;

    integer loop_count;

    reg                  is_branch_ex;
    reg                  actual_taken_ex;
    reg [PC_WIDTH-1:0]   actual_target_ex;
    wire [PC_WIDTH-1:0]  pc_ex       = pc_idex;
    wire [PC_WIDTH-1:0]  pc_plus4_ex = pc_idex + 4;

    always @(*) begin
        is_branch_ex     = 1'b0;
        actual_taken_ex  = 1'b0;
        actual_target_ex = {PC_WIDTH{1'b0}};
        if (valid_idex) begin
            case (pc_idex)
                8'h08: begin // loop branch
                    is_branch_ex     = 1'b1;
                    actual_target_ex = 8'h04;
                    actual_taken_ex  = (loop_count < 4);
                end
                8'h10: begin // always-taken branch
                    is_branch_ex     = 1'b1;
                    actual_target_ex = 8'h20;
                    actual_taken_ex  = 1'b1;
                end
                8'h48: begin // aliases with 0x08 in a 16-entry table
                    is_branch_ex     = 1'b1;
                    actual_target_ex = 8'h4C;
                    actual_taken_ex  = 1'b1;
                end
                default: ; // ordinary instruction
            endcase
        end
    end

    branch_predictor_unit #(
        .PC_WIDTH  (PC_WIDTH),
        .INDEX_BITS(INDEX_BITS)
    ) dut (
        .clk              (clk),
        .rst              (rst),
        .stall            (stall),
        .pc_if            (pc_if_reg),
        .predict_taken_if (predict_taken_if),
        .next_pc          (next_pc),
        .pc_ex            (pc_ex),
        .is_branch_ex     (is_branch_ex),
        .actual_taken_ex  (actual_taken_ex),
        .actual_target_ex(actual_target_ex),
        .pc_plus4_ex      (pc_plus4_ex),
        .mispredict       (mispredict),
        .correct_pc       (correct_pc),
        .flush_if         (flush_if),
        .flush_id         (flush_id)
    );

    always #5 clk = ~clk;

    wire [PC_WIDTH-1:0] pc_if_next = mispredict ? correct_pc : next_pc;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_if_reg  <= 8'h00;
            valid_ifid <= 1'b0;
            valid_idex <= 1'b0;
            pc_ifid    <= 8'h00;
            pc_idex    <= 8'h00;
            loop_count <= 0;
        end else if (!stall) begin
            pc_if_reg  <= pc_if_next;

            valid_ifid <= flush_if ? 1'b0 : 1'b1;
            pc_ifid    <= pc_if_reg;

            valid_idex <= flush_id ? 1'b0 : valid_ifid;
            pc_idex    <= pc_ifid;

            if (is_branch_ex && pc_idex == 8'h08)
                loop_count <= loop_count + 1;
        end
    end

    integer cyc;
    initial cyc = 0;

    always @(posedge clk) begin
        if (!rst) begin
            cyc = cyc + 1;
            $display("c%0d | IF pc=%0h pred_t=%b next=%0h | EX pc=%0h valid=%b is_br=%b act_t=%b tgt=%0h | mispred=%b correct=%0h flush(if,id)=%b,%b",
                       cyc, pc_if_reg, predict_taken_if, next_pc,
                       pc_idex, valid_idex, is_branch_ex, actual_taken_ex, actual_target_ex,
                       mispredict, correct_pc, flush_if, flush_id);
        end
    end

    initial begin
        #7 rst = 0;
        #700;
        $display("\n---- Final BHT counters (nonzero-relevant indices) ----");
        $display("  idx 2  (0x08/0x48): %b", dut.u_bht.counter[2]);
        $display("  idx 4  (0x10):      %b", dut.u_bht.counter[4]);
        $display("\n---- Final BTB entries (relevant indices) ----");
        $display("  idx 2 : valid=%b tag=%b target=%0h  (should show 0x48's entry, having evicted 0x08's)",
                   dut.u_btb.valid[2], dut.u_btb.tag[2], dut.u_btb.target[2]);
        $display("  idx 4 : valid=%b tag=%b target=%0h  (0x10's entry)",
                   dut.u_btb.valid[4], dut.u_btb.tag[4], dut.u_btb.target[4]);
        $finish;
    end

endmodule
