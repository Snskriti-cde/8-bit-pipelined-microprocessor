`timescale 1ns/1ps

module cu_tb;
    reg  [5:0] opcode, funct;
    wire [1:0] reg_dst, mem_to_reg;
    wire       alu_src, branch, jump, jal, jump_reg, reg_write, mem_read, mem_write, halt;
    wire [2:0] alu_op;
    integer    errors = 0;

    // MAPPING ===============================================================

    control_unit DUT (
        .opcode(opcode), .funct(funct),
        .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jal(jal), .jump_reg(jump_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .alu_op(alu_op), .halt(halt)
    );

    wire [15:0] cw = {reg_dst, alu_src, mem_to_reg, branch, jump, jal,
                      jump_reg, reg_write, mem_read, mem_write, alu_op, halt};

    // CHECKER =================================================================

    task chk(input [8*8:1] name, input [5:0] op, input [5:0] f, input [15:0] exp);
        begin
            opcode = op; funct = f; #1;
            if (cw !== exp) begin
                $display("  FAIL %-6s cw=%b (exp %b)", name, cw, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-6s cw=%b", name, cw);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ==============================================================================

    initial begin
        chk("R",    6'h00, 6'h20, {2'b01,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b111,1'b0});
        chk("JR",   6'h00, 6'h08, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,3'b000,1'b0});
        chk("ADDI", 6'h08, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0});
        chk("SLTI", 6'h0A, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b101,1'b0});
        chk("ANDI", 6'h0C, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b010,1'b0});
        chk("ORI",  6'h0D, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b011,1'b0});
        chk("XORI", 6'h0E, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b100,1'b0});
        chk("LW",   6'h23, 6'h00, {2'b00,1'b1,2'b01,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b0,3'b000,1'b0});
        chk("SW",   6'h2B, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,3'b000,1'b0});
        chk("BEQ",  6'h04, 6'h00, {2'b00,1'b0,2'b00,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b001,1'b0});
        chk("BNE",  6'h05, 6'h00, {2'b00,1'b0,2'b00,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b001,1'b0});
        chk("J",    6'h02, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b0});
        chk("JAL",  6'h03, 6'h00, {2'b10,1'b0,2'b10,1'b0,1'b1,1'b1,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0});
        chk("HLT",  6'h3F, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b1});

        $display("\n[cu_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
