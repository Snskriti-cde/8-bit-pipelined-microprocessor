`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
//  IF/ID
// -----------------------------------------------------------------------------
module if_id_reg(
    input             clk,
    input             reset,
    input             stall,          // hold current contents (load-use)
    input             flush,          // inject NOP (taken control transfer)
    input      [7:0]  pc_in,
    input      [7:0]  pc_plus1_in,
    input      [31:0] instruction_in,
    output reg [7:0]  pc_out,
    output reg [7:0]  pc_plus1_out,
    output reg [31:0] instruction_out
);
always @(posedge clk) begin
    if (reset || flush) begin
        pc_out          <= 8'd0;
        pc_plus1_out    <= 8'd0;
        instruction_out <= 32'd0;      // opcode 0 / funct 0 = SLL $0,$0,0 = NOP
    end
    else if (!stall) begin
        pc_out          <= pc_in;
        pc_plus1_out    <= pc_plus1_in;
        instruction_out <= instruction_in;
    end
end
endmodule


// -----------------------------------------------------------------------------
//  ID/EX
// -----------------------------------------------------------------------------
module id_ex_reg(
    input             clk,
    input             reset,
    input             stall,
    input             flush,          // load-use bubble OR branch squash
    // datapath
    input      [7:0]  pc_in,             // (T2) own PC -> becomes EPC on a fault
    input      [7:0]  pc_plus1_in,
    input      [7:0]  read_data1_in,
    input      [7:0]  read_data2_in,
    input      [7:0]  immediate_in,
    input      [4:0]  shamt_in,
    input      [5:0]  funct_in,
    input      [5:0]  opcode_in,
    // register addresses
    input      [4:0]  rs_in,
    input      [4:0]  rt_in,
    input      [4:0]  rd_in,
    // control
    input             reg_write_in,
    input             alu_src_in,
    input             mem_read_in,
    input             mem_write_in,
    input      [1:0]  mem_to_reg_in,
    input      [1:0]  reg_dst_in,
    input             branch_in,
    input             jump_in,
    input             jal_in,
    input             jump_reg_in,
    input             halt_in,
    input      [2:0]  alu_op_in,
    // (T2) exception decode
    input             illegal_in,
    input             trap_in,
    input             ov_en_in,
    input             cp0_read_in,
    input             cp0_sel_in,
    // outputs
    output reg [7:0]  pc_out,
    output reg [7:0]  pc_plus1_out,
    output reg [7:0]  read_data1_out,
    output reg [7:0]  read_data2_out,
    output reg [7:0]  immediate_out,
    output reg [4:0]  shamt_out,
    output reg [5:0]  funct_out,
    output reg [5:0]  opcode_out,
    output reg [4:0]  rs_out,
    output reg [4:0]  rt_out,
    output reg [4:0]  rd_out,
    output reg        reg_write_out,
    output reg        alu_src_out,
    output reg        mem_read_out,
    output reg        mem_write_out,
    output reg [1:0]  mem_to_reg_out,
    output reg [1:0]  reg_dst_out,
    output reg        branch_out,
    output reg        jump_out,
    output reg        jal_out,
    output reg        jump_reg_out,
    output reg        halt_out,
    output reg [2:0]  alu_op_out,
    output reg        illegal_out,
    output reg        trap_out,
    output reg        ov_en_out,
    output reg        cp0_read_out,
    output reg        cp0_sel_out
);
always @(posedge clk) begin
    if (reset || flush) begin
        pc_out         <= 8'd0;
        pc_plus1_out   <= 8'd0;
        read_data1_out <= 8'd0;
        read_data2_out <= 8'd0;
        immediate_out  <= 8'd0;
        shamt_out      <= 5'd0;
        funct_out      <= 6'd0;
        opcode_out     <= 6'd0;
        rs_out         <= 5'd0;
        rt_out         <= 5'd0;
        rd_out         <= 5'd0;
        reg_write_out  <= 1'b0;
        alu_src_out    <= 1'b0;
        mem_read_out   <= 1'b0;
        mem_write_out  <= 1'b0;
        mem_to_reg_out <= 2'd0;
        reg_dst_out    <= 2'd0;
        branch_out     <= 1'b0;
        jump_out       <= 1'b0;
        jal_out        <= 1'b0;
        jump_reg_out   <= 1'b0;
        halt_out       <= 1'b0;
        alu_op_out     <= 3'd0;
        illegal_out    <= 1'b0;
        trap_out       <= 1'b0;
        ov_en_out      <= 1'b0;
        cp0_read_out   <= 1'b0;
        cp0_sel_out    <= 1'b0;
    end
    else if (!stall) begin
        pc_out         <= pc_in;
        pc_plus1_out   <= pc_plus1_in;
        read_data1_out <= read_data1_in;
        read_data2_out <= read_data2_in;
        immediate_out  <= immediate_in;
        shamt_out      <= shamt_in;
        funct_out      <= funct_in;
        opcode_out     <= opcode_in;
        rs_out         <= rs_in;
        rt_out         <= rt_in;
        rd_out         <= rd_in;
        reg_write_out  <= reg_write_in;
        alu_src_out    <= alu_src_in;
        mem_read_out   <= mem_read_in;
        mem_write_out  <= mem_write_in;
        mem_to_reg_out <= mem_to_reg_in;
        reg_dst_out    <= reg_dst_in;
        branch_out     <= branch_in;
        jump_out       <= jump_in;
        jal_out        <= jal_in;
        jump_reg_out   <= jump_reg_in;
        halt_out       <= halt_in;
        alu_op_out     <= alu_op_in;
        illegal_out    <= illegal_in;
        trap_out       <= trap_in;
        ov_en_out      <= ov_en_in;
        cp0_read_out   <= cp0_read_in;
        cp0_sel_out    <= cp0_sel_in;
    end
end
endmodule


// -----------------------------------------------------------------------------
//  EX/MEM
// -----------------------------------------------------------------------------
module ex_mem_reg(
    input             clk,
    input             reset,
    input             stall,
    input             flush,
    // data
    input      [7:0]  alu_result_in,
    input      [7:0]  write_data_in,     // forwarded rt value (store data)
    input      [7:0]  pc_plus1_in,       // (2) JAL link value
    input      [7:0]  pc_in,             // (T2) own PC -> EPC
    input      [4:0]  dest_reg_in,
    // control
    input             reg_write_in,
    input             mem_read_in,
    input             mem_write_in,
    input      [1:0]  mem_to_reg_in,     // (1) 2 bits
    input             halt_in,           // (3)
    input             exc_in,            // (T2) this instruction faulted
    input      [7:0]  cause_in,          // (T2) its cause code
    // outputs
    output reg [7:0]  alu_result_out,
    output reg [7:0]  write_data_out,
    output reg [7:0]  pc_plus1_out,
    output reg [7:0]  pc_out,
    output reg [4:0]  dest_reg_out,
    output reg        reg_write_out,
    output reg        mem_read_out,
    output reg        mem_write_out,
    output reg [1:0]  mem_to_reg_out,
    output reg        halt_out,
    output reg        exc_out,
    output reg [7:0]  cause_out
);
always @(posedge clk) begin
    if (reset || flush) begin
        alu_result_out <= 8'd0;
        write_data_out <= 8'd0;
        pc_plus1_out   <= 8'd0;
        pc_out         <= 8'd0;
        dest_reg_out   <= 5'd0;
        reg_write_out  <= 1'b0;
        mem_read_out   <= 1'b0;
        mem_write_out  <= 1'b0;
        mem_to_reg_out <= 2'd0;
        halt_out       <= 1'b0;
        exc_out        <= 1'b0;
        cause_out      <= 8'd0;
    end
    else if (!stall) begin
        alu_result_out <= alu_result_in;
        write_data_out <= write_data_in;
        pc_plus1_out   <= pc_plus1_in;
        pc_out         <= pc_in;
        dest_reg_out   <= dest_reg_in;
        reg_write_out  <= reg_write_in;
        mem_read_out   <= mem_read_in;
        mem_write_out  <= mem_write_in;
        mem_to_reg_out <= mem_to_reg_in;
        halt_out       <= halt_in;
        exc_out        <= exc_in;
        cause_out      <= cause_in;
    end
end
endmodule


// -----------------------------------------------------------------------------
//  MEM/WB
// -----------------------------------------------------------------------------
module mem_wb_reg(
    input             clk,
    input             reset,
    input             stall,
    input             flush,
    // data
    input      [7:0]  mem_data_in,
    input      [7:0]  alu_result_in,
    input      [7:0]  pc_plus1_in,       // (2)
    input      [4:0]  dest_reg_in,
    // control
    input             reg_write_in,
    input      [1:0]  mem_to_reg_in,     // (1) 2 bits
    input             halt_in,           // (3)
    // outputs
    output reg [7:0]  mem_data_out,
    output reg [7:0]  alu_result_out,
    output reg [7:0]  pc_plus1_out,
    output reg [4:0]  dest_reg_out,
    output reg        reg_write_out,
    output reg [1:0]  mem_to_reg_out,
    output reg        halt_out
);
always @(posedge clk) begin
    if (reset || flush) begin
        mem_data_out   <= 8'd0;
        alu_result_out <= 8'd0;
        pc_plus1_out   <= 8'd0;
        dest_reg_out   <= 5'd0;
        reg_write_out  <= 1'b0;
        mem_to_reg_out <= 2'd0;
        halt_out       <= 1'b0;
    end
    else if (!stall) begin
        mem_data_out   <= mem_data_in;
        alu_result_out <= alu_result_in;
        pc_plus1_out   <= pc_plus1_in;
        dest_reg_out   <= dest_reg_in;
        reg_write_out  <= reg_write_in;
        mem_to_reg_out <= mem_to_reg_in;
        halt_out       <= halt_in;
    end
end
endmodule
