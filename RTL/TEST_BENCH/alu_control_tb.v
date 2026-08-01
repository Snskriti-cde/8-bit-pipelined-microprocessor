`timescale 1ns/1ps 
`include "alu_defs.vh"

module alu_control_tb;
    reg  [2:0] alu_op;
    reg  [5:0] funct;
    wire [3:0] alu_control;
    integer    errors = 0;

    alu_control DUT (.alu_op(alu_op), .funct(funct), .alu_control(alu_control));

    localparam AOP_ADD=3'b000, AOP_SUB=3'b001, AOP_AND=3'b010, AOP_OR=3'b011,
               AOP_XOR=3'b100, AOP_SLT=3'b101, AOP_RTYPE=3'b111;

    // CHECKER ================================================================

    task chk(input [8*8:1] name, input [2:0] aop, input [5:0] f, input [3:0] exp);
        begin
            alu_op = aop; funct = f; #1;
            if (alu_control !== exp) begin
                $display("  FAIL %-8s -> %h (exp %h)", name, alu_control, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-8s -> %h", name, alu_control);
        end
    endtask
 
   //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        // direct classes (funct ignored)
        chk("ADD",  AOP_ADD, 6'h00, `ALU_ADD);
        chk("SUB",  AOP_SUB, 6'h00, `ALU_SUB);
        chk("AND",  AOP_AND, 6'h00, `ALU_AND);
        chk("OR",   AOP_OR,  6'h00, `ALU_OR);
        chk("XOR",  AOP_XOR, 6'h00, `ALU_XOR);
        chk("SLTi", AOP_SLT, 6'h00, `ALU_SLT);
        // R-type funct decode
        chk("rADD",  AOP_RTYPE, 6'h20, `ALU_ADD);
        chk("rSUB",  AOP_RTYPE, 6'h22, `ALU_SUB);
        chk("rAND",  AOP_RTYPE, 6'h24, `ALU_AND);
        chk("rOR",   AOP_RTYPE, 6'h25, `ALU_OR);
        chk("rXOR",  AOP_RTYPE, 6'h26, `ALU_XOR);
        chk("rNOR",  AOP_RTYPE, 6'h27, `ALU_NOR);
        chk("rSLT",  AOP_RTYPE, 6'h2A, `ALU_SLT);
        chk("rSLL",  AOP_RTYPE, 6'h00, `ALU_SLL);
        chk("rSRL",  AOP_RTYPE, 6'h02, `ALU_SRL);
        chk("rSRA",  AOP_RTYPE, 6'h03, `ALU_SRA);
        chk("rROL",  AOP_RTYPE, 6'h10, `ALU_ROL);
        chk("rROR",  AOP_RTYPE, 6'h11, `ALU_ROR);
        chk("rNOT",  AOP_RTYPE, 6'h21, `ALU_NOT);
        chk("rPASA", AOP_RTYPE, 6'h23, `ALU_PASA);
        chk("rINC",  AOP_RTYPE, 6'h12, `ALU_INC);
        chk("rDEC",  AOP_RTYPE, 6'h13, `ALU_DEC);
        chk("rJR",   AOP_RTYPE, 6'h08, `ALU_ADD); // JR: ALU unused -> default ADD

        $display("\n[alu_control_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
