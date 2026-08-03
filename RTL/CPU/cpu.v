`include "alu_defs.vh"
`timescale 1ns/1ps
module cpu #(
    parameter PROG = "program.hex"      // program image loaded by $readmemh
)(
    input  wire        clk,
    input  wire        reset,
    output wire        halt,
    // ---- debug / observation ports ----
    output wire [7:0]  pc_out,
    output wire [31:0] instr_out,
    // ---- exception state (Bonus Task 2) ----
    output wire [7:0]  epc_out,
    output wire [7:0]  cause_out,
    output wire        exception_out
);

    // =========================================================================
    //  Inter-stage wires declared up front (EX feeds back to IF)
    // =========================================================================
    wire [1:0] pc_sel;
    wire [7:0] branch_target, jump_target, jr_target;
    wire       ex_redirect;                 // 1 = control transfer taken in EX

    wire       hz_pc_write, hz_if_id_write, hz_bubble, hz_stall;
    wire       hz_flush_if_id, hz_flush_id_ex, hz_flush_ex_mem, hz_flush_mem_wb;
    wire       exc_taken;                   // ECU commit strobe
    wire [7:0] exc_vector, epc, cause;
    wire [7:0] wb_data;                     // WB result, also forwarded to EX

    // =========================================================================
    //  STAGE 1 : IF -- Instruction Fetch
    // =========================================================================
    wire [7:0]  if_pc, if_pc_plus1;
    wire [31:0] if_instr;

    wire id_halt;                            // HLT decoded in ID (below)
    wire pc_write = (exc_taken | ex_redirect) ? 1'b1 : (hz_pc_write & ~id_halt);

    Program_Counter PC (
        .Clock        (clk),
        .Reset        (reset),
        .Pc_Write     (pc_write),
        .Pc_Sel       (pc_sel),
        .Jr_Target    (jr_target),
        .Jump_Target  (jump_target),
        .Branch_Target(branch_target),
        .Exc_Taken    (exc_taken),
        .Exc_Vector   (exc_vector),
        .Pc           (if_pc),
        .Pc_Next      (if_pc_plus1)
    );

    Instruction_Memory #(.MEM_FILE(PROG)) IMEM (
        .Address(if_pc),
        .Instr  (if_instr)
    );

    assign pc_out    = if_pc;
    assign instr_out = if_instr;

    // ------------------------------ IF/ID ------------------------------------
    wire [7:0]  id_pc, id_pc_plus1;
    wire [31:0] id_instr;

    if_id_reg IF_ID (
        .clk            (clk),
        .reset          (reset),
        .stall          (~hz_if_id_write | id_halt),  // hold on load-use or HLT freeze
        .flush          (hz_flush_if_id),              // wrong-path squash OR fault
        .pc_in          (if_pc),
        .pc_plus1_in    (if_pc_plus1),
        .instruction_in (if_instr),
        .pc_out         (id_pc),
        .pc_plus1_out   (id_pc_plus1),
        .instruction_out(id_instr)
    );

    // =========================================================================
    //  STAGE 2 : ID -- Decode / Register read / Control
    // =========================================================================
    wire [5:0] id_opcode = id_instr[31:26];
    wire [4:0] id_rs     = id_instr[25:21];
    wire [4:0] id_rt     = id_instr[20:16];
    wire [4:0] id_rd     = id_instr[15:11];
    wire [4:0] id_shamt  = id_instr[10:6];
    wire [5:0] id_funct  = id_instr[5:0];
    wire [7:0] id_imm8   = id_instr[7:0];

    wire [1:0] id_reg_dst, id_mem_to_reg;
    wire       id_alu_src, id_branch, id_jump, id_jal, id_jump_reg;
    wire       id_reg_write, id_mem_read, id_mem_write;
    wire [2:0] id_alu_op;
    wire       id_illegal, id_trap, id_ov_en, id_cp0_read, id_cp0_sel;

    control_unit CU (
        .opcode    (id_opcode),
        .funct     (id_funct),
        .reg_dst   (id_reg_dst),
        .alu_src   (id_alu_src),
        .mem_to_reg(id_mem_to_reg),
        .branch    (id_branch),
        .jump      (id_jump),
        .jal       (id_jal),
        .jump_reg  (id_jump_reg),
        .reg_write (id_reg_write),
        .mem_read  (id_mem_read),
        .mem_write (id_mem_write),
        .alu_op    (id_alu_op),
        .halt      (id_halt),
        .illegal   (id_illegal),
        .trap      (id_trap),
        .ov_en     (id_ov_en),
        .cp0_read  (id_cp0_read),
        .cp0_sel   (id_cp0_sel)
    );

    // Register file: read in ID, written from WB (same edge -> internal bypass)
    wire [7:0] id_read_data_1, id_read_data_2;
    wire [4:0] wb_dest_reg;
    wire       wb_reg_write;

    register_file #(.DATA_WIDTH(8), .NUM_REGS(32)) RF (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (wb_reg_write),
        .read_reg_1 (id_rs),
        .read_reg_2 (id_rt),
        .write_reg  (wb_dest_reg),
        .write_data (wb_data),
        .read_data_1(id_read_data_1),
        .read_data_2(id_read_data_2)
    );

    // ------------------------------ ID/EX ------------------------------------
    
    wire [7:0] ex_pc, ex_pc_plus1, ex_read_data_1, ex_read_data_2, ex_imm8;
    wire       ex_illegal, ex_trap, ex_ov_en, ex_cp0_read, ex_cp0_sel;
    wire [4:0] ex_shamt_5;
    wire [5:0] ex_funct, ex_opcode;
    wire [4:0] ex_rs, ex_rt, ex_rd;
    wire       ex_reg_write, ex_alu_src, ex_mem_read, ex_mem_write;
    wire [1:0] ex_mem_to_reg, ex_reg_dst;
    wire       ex_branch, ex_jump, ex_jal, ex_jump_reg, ex_halt;
    wire [2:0] ex_alu_op;

    id_ex_reg ID_EX (
        .clk           (clk),
        .reset         (reset),
        .stall         (1'b0),
        .flush         (hz_flush_id_ex),            // bubble, squash, or fault
        .pc_in         (id_pc),
        .pc_plus1_in   (id_pc_plus1),
        .read_data1_in (id_read_data_1),
        .read_data2_in (id_read_data_2),
        .immediate_in  (id_imm8),
        .shamt_in      (id_shamt),
        .funct_in      (id_funct),
        .opcode_in     (id_opcode),
        .rs_in         (id_rs),
        .rt_in         (id_rt),
        .rd_in         (id_rd),
        .reg_write_in  (id_reg_write),
        .alu_src_in    (id_alu_src),
        .mem_read_in   (id_mem_read),
        .mem_write_in  (id_mem_write),
        .mem_to_reg_in (id_mem_to_reg),
        .reg_dst_in    (id_reg_dst),
        .branch_in     (id_branch),
        .jump_in       (id_jump),
        .jal_in        (id_jal),
        .jump_reg_in   (id_jump_reg),
        .halt_in       (id_halt),
        .alu_op_in     (id_alu_op),
        .illegal_in    (id_illegal),
        .trap_in       (id_trap),
        .ov_en_in      (id_ov_en),
        .cp0_read_in   (id_cp0_read),
        .cp0_sel_in    (id_cp0_sel),
        .pc_out        (ex_pc),
        .pc_plus1_out  (ex_pc_plus1),
        .read_data1_out(ex_read_data_1),
        .read_data2_out(ex_read_data_2),
        .immediate_out (ex_imm8),
        .shamt_out     (ex_shamt_5),
        .funct_out     (ex_funct),
        .opcode_out    (ex_opcode),
        .rs_out        (ex_rs),
        .rt_out        (ex_rt),
        .rd_out        (ex_rd),
        .reg_write_out (ex_reg_write),
        .alu_src_out   (ex_alu_src),
        .mem_read_out  (ex_mem_read),
        .mem_write_out (ex_mem_write),
        .mem_to_reg_out(ex_mem_to_reg),
        .reg_dst_out   (ex_reg_dst),
        .branch_out    (ex_branch),
        .jump_out      (ex_jump),
        .jal_out       (ex_jal),
        .jump_reg_out  (ex_jump_reg),
        .halt_out      (ex_halt),
        .alu_op_out    (ex_alu_op),
        .illegal_out   (ex_illegal),
        .trap_out      (ex_trap),
        .ov_en_out     (ex_ov_en),
        .cp0_read_out  (ex_cp0_read),
        .cp0_sel_out   (ex_cp0_sel)
    );

    // =========================================================================
    //  STAGE 3 : EX -- Forwarding / ALU / branch resolution
    // =========================================================================
    wire [7:0] mem_alu_result;
    wire [4:0] mem_dest_reg;
    wire       mem_reg_write;
    wire [7:0] mem_write_data, mem_pc_plus1;   // hoisted: used by the forward mux
    wire       mem_mem_read, mem_mem_write, mem_halt;
    wire [1:0] mem_mem_to_reg;
    wire [7:0] mem_pc, mem_cause;
    wire       mem_exc;

    wire [1:0] forwardA, forwardB;

    forwarding_unit FU (
        .id_ex_rs        (ex_rs),
        .id_ex_rt        (ex_rt),
        .ex_mem_rd       (mem_dest_reg),
        .ex_mem_reg_write(mem_reg_write),
        .mem_wb_rd       (wb_dest_reg),
        .mem_wb_reg_write(wb_reg_write),
        .forwardA        (forwardA),
        .forwardB        (forwardB)
    );

    wire [7:0] mem_fwd_value = (mem_mem_to_reg == 2'b10) ? mem_pc_plus1 : mem_alu_result;

    // 3:1 operand muxes  (00 = register file, 10 = EX/MEM, 01 = MEM/WB)
    reg [7:0] fwd_a, fwd_b;
    always @(*) begin
        case (forwardA)
            2'b10:   fwd_a = mem_fwd_value;
            2'b01:   fwd_a = wb_data;
            default: fwd_a = ex_read_data_1;
        endcase
        case (forwardB)
            2'b10:   fwd_b = mem_fwd_value;
            2'b01:   fwd_b = wb_data;
            default: fwd_b = ex_read_data_2;
        endcase
    end

    wire [4:0] alu_ctrl;          // 5 bits: ALU opcode space extended for MUL/DIV
    alu_control ALUCTL (
        .alu_op     (ex_alu_op),
        .funct      (ex_funct),
        .alu_control(alu_ctrl)
    );

    // fwd_b is the forwarded rt value: it feeds the ALU only when alu_src=0,
    // but it is ALWAYS the store data for SW (which uses alu_src=1 for the
    // address), so it is captured separately into EX/MEM below.
    wire [7:0] alu_b = ex_alu_src ? ex_imm8 : fwd_b;
    wire [7:0] ex_alu_result;
    wire       flag_z, flag_n, flag_c, flag_v, less_than, carry;

    alu ALU (
        .a          (fwd_a),
        .b          (alu_b),
        .shamt      (ex_shamt_5),
        .alu_control(alu_ctrl),
        .result     (ex_alu_result),
        .less_than  (less_than),
        .carry      (carry),
        .flag_z     (flag_z),
        .flag_n     (flag_n),
        .flag_c     (flag_c),
        .flag_v     (flag_v)
    );

    // =====================================================================
    //  EX-stage fault detection  (Bonus Task 2)
    // =====================================================================
    //  Cause encoding -- must match the constants the handler compares against.
    localparam [7:0] CAUSE_NONE = 8'h00,
                     CAUSE_OVF  = 8'h01,   // signed arithmetic overflow
                     CAUSE_ILL  = 8'h02,   // illegal instruction
                     CAUSE_TRAP = 8'h03,   // TRAP instruction
                     CAUSE_DIV0 = 8'h04;   // divide by zero (bonus 4th cause)

    wire ex_overflow = ex_ov_en & flag_v;                 // V only counts on
                                                          // signed ADD/SUB class
    wire ex_div0     = (alu_ctrl == `ALU_DIV) & (alu_b == 8'd0);

    wire [7:0] ex_cause = ex_illegal ? CAUSE_ILL  :       // decode faults first
                          ex_trap    ? CAUSE_TRAP :
                          ex_div0    ? CAUSE_DIV0 :
                          ex_overflow? CAUSE_OVF  : CAUSE_NONE;
    wire       ex_exc   = (ex_cause != CAUSE_NONE);

    wire [7:0] cp0_value = ex_cp0_sel ? epc : cause;
    wire [7:0] ex_result = ex_cp0_read ? cp0_value : ex_alu_result;

    // Branch / jump resolution. bne is decoded from opcode[0]: BEQ(0x04)->0,
    // BNE(0x05)->1, so both share one control word.
    wire ex_bne = ex_opcode[0];

    branch_unit BU (
        .branch       (ex_branch),
        .bne          (ex_bne),
        .jump         (ex_jump),
        .jump_reg     (ex_jump_reg),
        .flag_z       (flag_z),
        .pc_plus1     (ex_pc_plus1),
        .imm8         (ex_imm8),
        .rs_val       (fwd_a),              // forwarded, for JR
        .branch_target(branch_target),
        .jump_target  (jump_target),
        .jr_target    (jr_target),
        .branch_taken (),
        .pc_sel       (pc_sel)
    );

    assign ex_redirect = (pc_sel != 2'b00);

    // Destination-register mux (RegDst)
    reg [4:0] ex_dest_reg;
    always @(*) begin
        case (ex_reg_dst)
            2'b00:   ex_dest_reg = ex_rt;     // I-type
            2'b01:   ex_dest_reg = ex_rd;     // R-type
            2'b10:   ex_dest_reg = 5'd31;     // JAL -> $ra
            default: ex_dest_reg = ex_rt;
        endcase
    end

    // ------------------------------ EX/MEM -----------------------------------
    ex_mem_reg EX_MEM (
        .clk           (clk),
        .reset         (reset),
        .stall         (1'b0),
        .flush         (hz_flush_ex_mem),    // fault: kill the younger instr
        .alu_result_in (ex_result),          // ALU result, or CP0 read data
        .write_data_in (fwd_b),              // forwarded store data
        .pc_plus1_in   (ex_pc_plus1),
        .pc_in         (ex_pc),
        .dest_reg_in   (ex_dest_reg),
        .reg_write_in  (ex_reg_write),
        .mem_read_in   (ex_mem_read),
        .mem_write_in  (ex_mem_write),
        .mem_to_reg_in (ex_mem_to_reg),
        .halt_in       (ex_halt),
        .exc_in        (ex_exc),
        .cause_in      (ex_cause),
        .alu_result_out(mem_alu_result),
        .write_data_out(mem_write_data),
        .pc_plus1_out  (mem_pc_plus1),
        .pc_out        (mem_pc),
        .dest_reg_out  (mem_dest_reg),
        .reg_write_out (mem_reg_write),
        .mem_read_out  (mem_mem_read),
        .mem_write_out (mem_mem_write),
        .mem_to_reg_out(mem_mem_to_reg),
        .halt_out      (mem_halt),
        .exc_out       (mem_exc),
        .cause_out     (mem_cause)
    );

    // =========================================================================
    //  STAGE 4 : MEM -- Data memory
    // =========================================================================
    wire [7:0] mem_read_data;

    // THE containment guarantee: a faulting instruction never writes memory,
    // and neither does anything younger (they are already flushed out of MEM).
    wire mem_write_eff = mem_mem_write & ~exc_taken;

    data_memory #(.DATA_WIDTH(8), .ADDR_WIDTH(8), .MEM_DEPTH(256)) DMEM (
        .clk      (clk),
        .rst      (reset),
        .memRead  (mem_mem_read),
        .memWrite (mem_write_eff),
        .address  (mem_alu_result),
        .writeData(mem_write_data),
        .readData (mem_read_data)
    );

    // ---------------------- Exception Control Unit ---------------------------
    exception_unit #(.VECTOR(8'h20)) ECU (
        .clk       (clk),
        .reset     (reset),
        .mem_exc   (mem_exc),
        .mem_cause (mem_cause),
        .mem_pc    (mem_pc),
        .epc       (epc),
        .cause     (cause),
        .exc_taken (exc_taken),
        .exc_vector(exc_vector)
    );

    assign epc_out       = epc;
    assign cause_out     = cause;
    assign exception_out = exc_taken;

    // ------------------------------ MEM/WB -----------------------------------
    wire [7:0] wb_mem_data, wb_alu_result, wb_pc_plus1;
    wire [1:0] wb_mem_to_reg;
    wire       wb_halt;

    mem_wb_reg MEM_WB (
        .clk           (clk),
        .reset         (reset),
        .stall         (1'b0),
        .flush         (hz_flush_mem_wb),   // fault: cancel its own write-back
        .mem_data_in   (mem_read_data),
        .alu_result_in (mem_alu_result),
        .pc_plus1_in   (mem_pc_plus1),
        .dest_reg_in   (mem_dest_reg),
        .reg_write_in  (mem_reg_write),
        .mem_to_reg_in (mem_mem_to_reg),
        .halt_in       (mem_halt),
        .mem_data_out  (wb_mem_data),
        .alu_result_out(wb_alu_result),
        .pc_plus1_out  (wb_pc_plus1),
        .dest_reg_out  (wb_dest_reg),
        .reg_write_out (wb_reg_write),
        .mem_to_reg_out(wb_mem_to_reg),
        .halt_out      (wb_halt)
    );

    // =========================================================================
    //  STAGE 5 : WB -- Write back
    // =========================================================================
    assign wb_data = (wb_mem_to_reg == 2'b00) ? wb_alu_result :   // WB_ALU
                     (wb_mem_to_reg == 2'b01) ? wb_mem_data   :   // WB_MEM (LW)
                     (wb_mem_to_reg == 2'b10) ? wb_pc_plus1   :   // WB_PC1 (JAL)
                                                wb_alu_result;

    // Halt only once HLT has retired -> pipeline is fully drained.
    assign halt = wb_halt;

    // =========================================================================
    //  Hazard detection (load-use)
    // =========================================================================
    hazard_detection_unit HDU (
        .id_ex_mem_read(ex_mem_read),
        .id_ex_rt      (ex_rt),
        .if_id_rs      (id_rs),
        .if_id_rt      (id_rt),
        .ex_redirect   (ex_redirect),
        .exception     (exc_taken),
        .pc_write      (hz_pc_write),
        .if_id_write   (hz_if_id_write),
        .bubble        (hz_bubble),
        .stall         (hz_stall),
        .flush_if_id   (hz_flush_if_id),
        .flush_id_ex   (hz_flush_id_ex),
        .flush_ex_mem  (hz_flush_ex_mem),
        .flush_mem_wb  (hz_flush_mem_wb)
    );

endmodule
