`timescale 1ns/1ps
`include "alu_defs.vh"

module alu_tb;
    reg  [7:0] a, b;
    reg  [4:0] shamt;
    reg  [3:0] op;
    wire [7:0] result;
    wire       less_than, carry, flag_z, flag_n, flag_c, flag_v;
    integer    errors = 0;


    // MAPPING ===============================================================
    alu DUT (
        .a(a), .b(b), .shamt(shamt), .alu_control(op),
        .result(result), .less_than(less_than), .carry(carry),
        .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v)
    );
    
    // CHECKER =================================================================

    // check result + 4 flags
    task chk(input [8*12:1] name, input [7:0] er,
             input ec, input ev, input ez, input en); // er = result, ec = carry and so on
        begin
            #1;                              // wait for 1 ns 
            if (result!==er || flag_c!==ec || flag_v!==ev ||
                flag_z!==ez || flag_n!==en)

                begin
                $display("  FAIL %-10s r=%h(exp %h) c=%b v=%b z=%b n=%b (exp c=%b v=%b z=%b n=%b)",
                         name, result, er, flag_c, flag_v, flag_z, flag_n, ec, ev, ez, en);
                errors = errors + 1;
            end else
                $display("  ok   %-10s r=%h c=%b v=%b z=%b n=%b", name, result, flag_c, flag_v, flag_z, flag_n);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        shamt = 0;
        a=8'h05; b=8'h03; op=`ALU_ADD;  chk("ADD",  8'h08, 0,0,0,0);
        a=8'hFF; b=8'h01; op=`ALU_ADD;  chk("ADD_carry", 8'h00, 1,0,1,0);
        a=8'h7F; b=8'h01; op=`ALU_ADD;  chk("ADD_ovf",   8'h80, 0,1,0,1);
        a=8'h05; b=8'h03; op=`ALU_SUB;  chk("SUB",  8'h02, 1,0,0,0);   // a>=b -> C=1
        a=8'h03; b=8'h05; op=`ALU_SUB;  chk("SUB_borrow", 8'hFE, 0,0,0,1); // a<b -> C=0
        a=8'h05; b=8'h05; op=`ALU_SUB;  chk("SUB_eq",     8'h00, 1,0,1,0);
        a=8'hFE; b=8'h01; op=`ALU_SLT;  chk("SLT_neg",    8'h01, 0,0,0,0); // -2<1
        a=8'h05; b=8'h03; op=`ALU_SLT;  chk("SLT_pos",    8'h00, 0,0,1,0); // 5<3 false
        a=8'hF0; b=8'h0F; op=`ALU_AND;  chk("AND",  8'h00, 0,0,1,0);
        a=8'hF0; b=8'h0F; op=`ALU_OR;   chk("OR",   8'hFF, 0,0,0,1);
        a=8'hAA; b=8'hFF; op=`ALU_XOR;  chk("XOR",  8'h55, 0,0,0,0);
        a=8'hAA; b=8'h00; op=`ALU_NOT;  chk("NOT",  8'h55, 0,0,0,0);
        a=8'hF0; b=8'h0F; op=`ALU_NOR;  chk("NOR",  8'h00, 0,0,1,0);
        a=8'h3C; b=8'h00; op=`ALU_PASA; chk("PASA", 8'h3C, 0,0,0,0);
        a=8'h00; b=8'h01; shamt=5'd3; op=`ALU_SLL; chk("SLL", 8'h08, 0,0,0,0);
        a=8'h00; b=8'h80; shamt=5'd1; op=`ALU_SRL; chk("SRL", 8'h40, 0,0,0,0);
        a=8'h00; b=8'h80; shamt=5'd1; op=`ALU_SRA; chk("SRA", 8'hC0, 0,0,0,1);
        a=8'h00; b=8'h81; shamt=5'd1; op=`ALU_ROL; chk("ROL", 8'h03, 0,0,0,0);
        a=8'h00; b=8'h81; shamt=5'd1; op=`ALU_ROR; chk("ROR", 8'hC0, 0,0,0,1);
        shamt=0;
        a=8'h0A; b=8'h00; op=`ALU_INC; chk("INC",     8'h0B, 0,0,0,0);
        a=8'h7F; b=8'h00; op=`ALU_INC; chk("INC_ovf", 8'h80, 0,1,0,1);
        a=8'h0A; b=8'h00; op=`ALU_DEC; chk("DEC",     8'h09, 0,0,0,0); 
        a=8'h80; b=8'h00; op=`ALU_DEC; chk("DEC_ovf", 8'h7F, 0,1,0,0);

        // ============================================================================
        // DISPLAY ERRORS
        // =========================================================================== 
        
        $display("\n[alu_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
