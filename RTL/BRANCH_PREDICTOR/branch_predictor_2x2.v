// =====================================================================
// branch_predictor_2x2.v
//
// A "2 by 2" dynamic branch predictor:
//   - 2 entries (rows)
//   - 2-bit saturating counter each (columns)
//
// Target machine: 8-bit address bus, 32-bit (4-byte) instructions.
// Since instructions are word-aligned, PC[1:0] is always 00, so the
// only PC bit that actually changes which "row" a branch lands in is
// PC[2]. That single bit selects one of the 2 entries.
//
//      row 0  <- branches where PC[2] = 0
//      row 1  <- branches where PC[2] = 1
//
// Each row is a 2-bit counter:
//      00 = Strong Not-Taken   01 = Weak Not-Taken
//      10 = Weak Taken         11 = Strong Taken
// Prediction = the counter's MSB (1 = predict taken).
//
// Usage in a 5-stage pipeline:
//      IF stage : pc_predict -> predict_taken   (read every cycle)
//      EX stage : once a branch's real outcome is known,
//                 pulse update_en for one cycle with pc_update /
//                 actual_taken -> counter adjusts by 1, saturating.
// =====================================================================

module branch_predictor_2x2 #(
    parameter PC_WIDTH = 8      // address width; change to match your bus
)(
    input  wire                  clk,
    input  wire                  rst,

    // ---- Prediction (read) port: used in IF, every cycle ----
    input  wire [PC_WIDTH-1:0]   pc_predict,
    output wire                  predict_taken,

    // ---- Update (write) port: used when a branch resolves ----
    input  wire                  update_en,      // 1-cycle pulse
    input  wire [PC_WIDTH-1:0]   pc_update,
    input  wire                  actual_taken
);

    // The whole predictor: 2 rows x 2 bits.
    reg [1:0] counter [0:1];

    wire row_predict = pc_predict[2];   // which of the 2 rows to read
    wire row_update  = pc_update[2];    // which of the 2 rows to write

    assign predict_taken = counter[row_predict][1];   // MSB = prediction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter[0] <= 2'b01;   // both rows reset to "weakly not taken"
            counter[1] <= 2'b01;
        end
        else if (update_en) begin
            if (actual_taken) begin
                if (counter[row_update] != 2'b11)
                    counter[row_update] <= counter[row_update] + 2'b01;   // move toward Taken
            end else begin
                if (counter[row_update] != 2'b00)
                    counter[row_update] <= counter[row_update] - 2'b01;   // move toward Not-Taken
            end
        end
    end

endmodule


// =====================================================================
// Testbench: proves the counters behave correctly.
//   Row 0 (branch A) : taken, taken, taken, not-taken, taken   (a loop-like pattern)
//   Row 1 (branch B) : not-taken, not-taken, taken, taken, taken
// =====================================================================
module branch_predictor_2x2_tb;

    reg clk = 0;
    reg rst = 1;
    reg [7:0] pc_predict = 0;
    reg update_en = 0;
    reg [7:0] pc_update = 0;
    reg actual_taken = 0;
    wire predict_taken;

    branch_predictor_2x2 #(.PC_WIDTH(8)) dut (
        .clk(clk), .rst(rst),
        .pc_predict(pc_predict), .predict_taken(predict_taken),
        .update_en(update_en), .pc_update(pc_update), .actual_taken(actual_taken)
    );

    always #5 clk = ~clk;

    // Small helper: drive one branch resolution and print before/after state
    task resolve_branch;
        input [7:0] pc;
        input       taken;
        begin
            pc_predict = pc;
            #1; // let combinational prediction settle
            $display("  PC=%0d (row %0d) | predicted=%b | actual=%b | counter before=%b",
                       pc, pc[2], predict_taken, taken, dut.counter[pc[2]]);
            @(negedge clk);
            pc_update = pc; actual_taken = taken; update_en = 1;
            @(negedge clk);
            update_en = 0;
            $display("                              counter after =%b", dut.counter[pc[2]]);
        end
    endtask

    initial begin
        #7 rst = 0;
        #10;

        $display("\n--- Row 0 (PC=0x00, branch A): T,T,T,NT,T ---");
        resolve_branch(8'h00, 1'b1);
        resolve_branch(8'h00, 1'b1);
        resolve_branch(8'h00, 1'b1);
        resolve_branch(8'h00, 1'b0);
        resolve_branch(8'h00, 1'b1);

        $display("\n--- Row 1 (PC=0x04, branch B): NT,NT,T,T,T ---");
        resolve_branch(8'h04, 1'b0);
        resolve_branch(8'h04, 1'b0);
        resolve_branch(8'h04, 1'b1);
        resolve_branch(8'h04, 1'b1);
        resolve_branch(8'h04, 1'b1);

        $display("\nFinal state: row0=%b row1=%b", dut.counter[0], dut.counter[1]);
        #10 $finish;
    end

endmodule
