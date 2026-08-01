`timescale 1ns/1ps

module branch_unit_tb;
    reg        branch, bne, jump, jump_reg, flag_z;
    reg  [7:0] pc_plus1, imm8, rs_val;
    wire [7:0] branch_target, jump_target, jr_target;
    wire       branch_taken;
    wire [1:0] pc_sel;
    integer    errors = 0;

    // MAPPING ===============================================================

    branch_unit DUT (
        .branch(branch), .bne(bne), .jump(jump), .jump_reg(jump_reg),
        .flag_z(flag_z), .pc_plus1(pc_plus1), .imm8(imm8), .rs_val(rs_val),
        .branch_target(branch_target), .jump_target(jump_target),
        .jr_target(jr_target), .branch_taken(branch_taken), .pc_sel(pc_sel)
    );

    // CHECKER =================================================================

    task clr; begin branch=0; bne=0; jump=0; jump_reg=0; flag_z=0;
                    pc_plus1=8'd10; imm8=8'd2; rs_val=8'd55; end endtask

    task chk(input [8*14:1] name, input et, input [1:0] esel);
        begin
            #1;
            if (branch_taken!==et || pc_sel!==esel) begin
                $display("  FAIL %-12s taken=%b(exp %b) pc_sel=%b(exp %b)",
                         name, branch_taken, et, pc_sel, esel);
                errors = errors + 1;
            end else
                $display("  ok   %-12s taken=%b pc_sel=%b", name, branch_taken, pc_sel);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        clr; branch=1; bne=0; flag_z=1; chk("BEQ_taken",     1, 2'b01);
        clr; branch=1; bne=0; flag_z=0; chk("BEQ_not_taken", 0, 2'b00);
        clr; branch=1; bne=1; flag_z=0; chk("BNE_taken",     1, 2'b01);
        clr; branch=1; bne=1; flag_z=1; chk("BNE_not_taken", 0, 2'b00);
        clr; jump=1;                    chk("JUMP",          0, 2'b10);
        clr; jump_reg=1;                chk("JR",            0, 2'b11);
        clr; jump=1; jump_reg=1;        chk("JR_over_JUMP",  0, 2'b11); // JR priority

        // datapath value checks
        #1;
        clr; pc_plus1=8'd10; imm8=8'd2;  #1;
        if (branch_target!==8'd12) begin $display("  FAIL branch_target=%0d (exp 12)", branch_target); errors=errors+1; end
        else $display("  ok   branch_target=10+2=%0d", branch_target);

        imm8=8'hFE; #1;  // -2 signed
        if (branch_target!==8'd8) begin $display("  FAIL branch_target neg=%0d (exp 8)", branch_target); errors=errors+1; end
        else $display("  ok   branch_target=10+(-2)=%0d", branch_target);

        imm8=8'd33; #1;
        if (jump_target!==8'd33) begin $display("  FAIL jump_target=%0d (exp 33)", jump_target); errors=errors+1; end
        else $display("  ok   jump_target=%0d", jump_target);

        rs_val=8'd77; #1;
        if (jr_target!==8'd77) begin $display("  FAIL jr_target=%0d (exp 77)", jr_target); errors=errors+1; end
        else $display("  ok   jr_target=%0d", jr_target);

        $display("\n[branch_unit_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
