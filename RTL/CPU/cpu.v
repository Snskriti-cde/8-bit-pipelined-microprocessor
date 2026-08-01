`timescale 1ns/1ps


module cpu (
    input  wire        clk,
    input  wire        reset,
    output wire        halt,
    output wire [7:0]  pc_out,
    output wire [31:0] instr_out
);

    //GLOBAL CONTROL WIRES==================
    wire       hazard_stall;    // load-use hazard
    wire       ex_take_branch;  
    wire       flush_if_id;     // NOP
    wire       flush_id_ex;     // zero the control bits entering ID/EX
    wire [1:0] forward_a, forward_b;
    wire [7:0] ex_target_addr;  // resolved branch/jump/jr target (declared here, driven in EX)
    wire       id_halt;         // HLT decoded in ID (declared here, driven in ID)

    // =========================================================================
    // 1. FETCH (IF)
    // =========================================================================
    wire [7:0]  if_curr_pc;
    wire [7:0] if_pc_next;
    wire [7:0] if_pc_final;
    wire [31:0] if_inst_raw;
    wire [31:0] if_inst_final;

    assign if_pc_next    = if_curr_pc + 8'd1;
    assign if_pc_final   = ex_take_branch ? ex_target_addr : if_pc_next;
    assign if_inst_final = flush_if_id ? 32'd0 : if_inst_raw;   // NOP on squash

    // Branch always wins the race for both PC and IF/ID; otherwise freeze on
    // a load-use hazard or on a decoded HLT.
    wire pc_write_enable = ex_take_branch ? 1'b1 : (~hazard_stall & ~id_halt);

    pc pc_inst (
        .clk         (clk),
        .reset       (reset),
        .write_enable(pc_write_enable),
        .pc_in       (if_pc_final),
        .pc_out      (if_curr_pc)
    );

    instruction_mem rom_inst (
        .addr       (if_curr_pc),
        .instruction(if_inst_raw)
    );

    assign pc_out    = if_curr_pc;
    assign instr_out = if_inst_raw;

    wire [7:0] id_pc;
    wire [7:0] id_pc_next;
    wire [31:0] id_inst;

    if_id_reg if_id_inst (
        .clk         (clk),
        .reset       (reset),
        .write_enable(pc_write_enable),   // PC and IF/ID always move together
        .pc_in       (if_curr_pc),
        .pc_next_in  (if_pc_next),
        .inst_in     (if_inst_final),
        .pc_out      (id_pc),
        .pc_next_out (id_pc_next),
        .inst_out    (id_inst)
    );

    // 2. DECODE (ID)===================================
    
    wire [5:0] id_opcode = id_inst[31:26];
    wire [4:0] id_rs     = id_inst[25:21];
    wire [4:0] id_rt     = id_inst[20:16];
    wire [4:0] id_rd     = id_inst[15:11];
    wire [4:0] id_shamt  = id_inst[10:6];
    wire [5:0] id_funct  = id_inst[5:0];
    wire [7:0] id_imm    = id_inst[7:0];

    wire [7:0] id_reg_data1, id_reg_data2;

    wire [1:0] id_reg_dst, id_mem_to_reg;
    wire       id_alu_src, id_branch, id_jump, id_jal, id_jump_reg;
    wire       id_reg_write, id_mem_read, id_mem_write;
    wire [2:0] id_alu_op;

    control_unit ctrl_inst (
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
        .halt      (id_halt)
    );

    reg_file regfile_inst (
        .clk        (clk),
        .reset      (reset),
        .write_enable(wb_reg_write),
        .read_reg1  (id_rs),
        .read_reg2  (id_rt),
        .write_reg  (wb_dest_reg),
        .write_data (wb_final_data),
        .read_data1 (id_reg_data1),
        .read_data2 (id_reg_data2)
    );

    hazard_unit hazard_inst (
        .id_rs      (id_rs),
        .id_rt      (id_rt),
        .ex_mem_read(ex_mem_read),
        .ex_rt      (ex_rt),
        .stall      (hazard_stall)
    );

    wire [7:0] ex_pc, ex_pc_next, ex_reg_data1, ex_reg_data2, ex_imm;
    wire [4:0] ex_shamt, ex_rs, ex_rt, ex_rd;
    wire [5:0] ex_funct, ex_opcode;
    wire       ex_reg_write, ex_mem_read, ex_mem_write;
    wire       ex_branch, ex_jump, ex_jal, ex_jump_reg, ex_alu_src, ex_halt;
    wire [2:0] ex_alu_op;
    wire [1:0] ex_reg_dst, ex_mem_to_reg;

    id_ex_reg id_ex_inst (
        .clk          (clk),
        .reset        (reset),
        .flush        (flush_id_ex),    // covers both branch squash and load-use bubble
        .pc_in        (id_pc),
        .pc_next_in   (id_pc_next),
        .reg_data1_in (id_reg_data1),
        .reg_data2_in (id_reg_data2),
        .imm_in       (id_imm),
        .shamt_in     (id_shamt),
        .funct_in     (id_funct),
        .opcode_in    (id_opcode),
        .rs_in        (id_rs),
        .rt_in        (id_rt),
        .rd_in        (id_rd),
        .reg_write_in (id_reg_write),
        .mem_read_in  (id_mem_read),
        .mem_write_in (id_mem_write),
        .branch_in    (id_branch),
        .jump_in      (id_jump),
        .jal_in       (id_jal),
        .jump_reg_in  (id_jump_reg),
        .alu_src_in   (id_alu_src),
        .alu_op_in    (id_alu_op),
        .reg_dst_in   (id_reg_dst),
        .mem_to_reg_in(id_mem_to_reg),
        .halt_in      (id_halt),
        .pc_out       (ex_pc),
        .pc_next_out  (ex_pc_next),
        .reg_data1_out(ex_reg_data1),
        .reg_data2_out(ex_reg_data2),
        .imm_out      (ex_imm),
        .shamt_out    (ex_shamt),
        .funct_out    (ex_funct),
        .opcode_out   (ex_opcode),
        .rs_out       (ex_rs),
        .rt_out       (ex_rt),
        .rd_out       (ex_rd),
        .reg_write_out(ex_reg_write),
        .mem_read_out (ex_mem_read),
        .mem_write_out(ex_mem_write),
        .branch_out   (ex_branch),
        .jump_out     (ex_jump),
        .jal_out      (ex_jal),
        .jump_reg_out (ex_jump_reg),
        .alu_src_out  (ex_alu_src),
        .alu_op_out   (ex_alu_op),
        .reg_dst_out  (ex_reg_dst),
        .mem_to_reg_out(ex_mem_to_reg),
        .halt_out     (ex_halt)
    );

    // 3. EXECUTE (EX) ===== forwarding, ALU, branch resolution

    forwarding_unit fwd_inst (
        .ex_rs        (ex_rs),
        .ex_rt        (ex_rt),
        .mem_dest_reg (mem_dest_reg),
        .mem_reg_write(mem_reg_write),
        .wb_dest_reg  (wb_dest_reg),
        .wb_reg_write (wb_reg_write),
        .forward_a    (forward_a),
        .forward_b    (forward_b)
    );

    // 3:1 operand muxes (00 = ID/EX value, 10 = EX/MEM, 01 = MEM/WB)
    wire [7:0] ex_forwarded_a = (forward_a == 2'b10) ? mem_alu_result :
                                (forward_a == 2'b01) ? wb_final_data  : ex_reg_data1;

    wire [7:0] ex_forwarded_b = (forward_b == 2'b10) ? mem_alu_result :
                                (forward_b == 2'b01) ? wb_final_data  : ex_reg_data2;

    // ex_forwarded_b is also always the SW store data -- captured separately
    // into EX/MEM below, since alu_src steals this mux for the ALU's use.
    wire [7:0] ex_alu_input_b = ex_alu_src ? ex_imm : ex_forwarded_b;

    // RegDst mux: 00 = I-type (rt), 01 = R-type (rd), 10 = JAL (-> $ra)
    wire [4:0] ex_dest_reg = (ex_reg_dst == 2'b01) ? ex_rd  :
                             (ex_reg_dst == 2'b10) ? 5'd31  : ex_rt;

    wire [3:0] ex_alu_ctrl;
    alu_control alu_ctrl_inst (
        .alu_op     (ex_alu_op),
        .funct      (ex_funct),
        .alu_control(ex_alu_ctrl)
    );

    wire [7:0] ex_alu_result;
    wire       ex_flag_zero;

    alu alu_inst (
        .a          (ex_forwarded_a),
        .b          (ex_alu_input_b),
        .shamt      (ex_shamt),
        .alu_control(ex_alu_ctrl),
        .result     (ex_alu_result),
        .less_than  (),
        .carry      (),
        .flag_z     (ex_flag_zero),
        .flag_n     (),
        .flag_c     (),
        .flag_v     ()
    );

    // bne is opcode[0]: BEQ(0x04)->0, BNE(0x05)->1, so one control word
    // covers both.
    wire       ex_bne = ex_opcode[0];
    wire [1:0] ex_pc_sel;
    wire [7:0] ex_branch_target, ex_jump_target, ex_jr_target;

    branch_unit branch_inst (
        .branch       (ex_branch),
        .bne          (ex_bne),
        .jump         (ex_jump),
        .jump_reg     (ex_jump_reg),
        .flag_z       (ex_flag_zero),
        .pc_next      (ex_pc_next),
        .imm          (ex_imm),
        .rs_val       (ex_forwarded_a),   // forwarded, for JR
        .branch_target(ex_branch_target),
        .jump_target  (ex_jump_target),
        .jr_target    (ex_jr_target),
        .branch_taken (),
        .pc_sel       (ex_pc_sel)
    );

    // pc_sel: 00 = no transfer, 01 = branch, 10 = jump, 11 = jump-register
    assign ex_take_branch = (ex_pc_sel != 2'b00);
    assign ex_target_addr = (ex_pc_sel == 2'b01) ? ex_branch_target :
                            (ex_pc_sel == 2'b10) ? ex_jump_target   :
                            (ex_pc_sel == 2'b11) ? ex_jr_target     : 8'd0;

    assign flush_if_id = ex_take_branch;
    assign flush_id_ex = ex_take_branch | hazard_stall;   // branch squash OR load-use bubble

    wire [7:0] mem_alu_result, mem_write_data, mem_pc_next;
    wire [4:0] mem_dest_reg;
    wire       mem_reg_write, mem_mem_read, mem_mem_write, mem_halt;
    wire [1:0] mem_mem_to_reg;

    ex_mem_reg ex_mem_inst (
        .clk           (clk),
        .reset         (reset),
        .alu_result_in (ex_alu_result),
        .write_data_in (ex_forwarded_b),   // forwarded store data
        .pc_next_in    (ex_pc_next),
        .dest_reg_in   (ex_dest_reg),
        .reg_write_in  (ex_reg_write),
        .mem_read_in   (ex_mem_read),
        .mem_write_in  (ex_mem_write),
        .mem_to_reg_in (ex_mem_to_reg),
        .halt_in       (ex_halt),
        .alu_result_out(mem_alu_result),
        .write_data_out(mem_write_data),
        .pc_next_out   (mem_pc_next),
        .dest_reg_out  (mem_dest_reg),
        .reg_write_out (mem_reg_write),
        .mem_read_out  (mem_mem_read),
        .mem_write_out (mem_mem_write),
        .mem_to_reg_out(mem_mem_to_reg),
        .halt_out      (mem_halt)
    );

    // 4. MEMORY (MEM)===============================

    wire [7:0] mem_read_data;

    data_mem dmem_inst (
        .clk       (clk),
        .reset     (reset),
        .mem_read  (mem_mem_read),
        .mem_write (mem_mem_write),
        .addr      (mem_alu_result),
        .write_data(mem_write_data),
        .read_data (mem_read_data)
    );

    wire [7:0] wb_read_data, wb_alu_result, wb_pc_next;
    wire [4:0] wb_dest_reg;
    wire       wb_reg_write, wb_halt;
    wire [1:0] wb_mem_to_reg;

    mem_wb_reg mem_wb_inst (
        .clk           (clk),
        .reset         (reset),
        .read_data_in  (mem_read_data),
        .alu_result_in (mem_alu_result),
        .pc_next_in    (mem_pc_next),
        .dest_reg_in   (mem_dest_reg),
        .reg_write_in  (mem_reg_write),
        .mem_to_reg_in (mem_mem_to_reg),
        .halt_in       (mem_halt),
        .read_data_out (wb_read_data),
        .alu_result_out(wb_alu_result),
        .pc_next_out   (wb_pc_next),
        .dest_reg_out  (wb_dest_reg),
        .reg_write_out (wb_reg_write),
        .mem_to_reg_out(wb_mem_to_reg),
        .halt_out      (wb_halt)
    );

    // 5. WRITEBACK (WB)=================================

    // 00 = ALU result, 01 = loaded memory data (LW), 10 = PC+1 (JAL)
    wire [7:0] wb_final_data = (wb_mem_to_reg == 2'b01) ? wb_read_data :
                               (wb_mem_to_reg == 2'b10) ? wb_pc_next   : wb_alu_result;

    // Halt only once HLT has retired -> pipeline is fully drained.
    assign halt = wb_halt;

endmodule