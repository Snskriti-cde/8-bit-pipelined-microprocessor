
module branch_unit (
    input            branch,        // 1 = BEQ/BNE
    input            bne,           // 1 = BNE, 0 = BEQ
    input            jump,          // 1 = J/JAL
    input            jump_reg,      // 1 = JR
    input            flag_z,        // ALU zero flag (a==b after SUB)
    input      [7:0] pc_plus1,      // PC+1 (branch base)
    input      [7:0] imm8,          // signed branch offset / jump target
    input      [7:0] rs_val,        // rs register value (JR target)
    output     [7:0] branch_target,
    output     [7:0] jump_target,
    output     [7:0] jr_target,
    output           branch_taken,
    output     [1:0] pc_sel         // 00=PC+1 | 01=branch | 10=jump | 11=jr
);

    assign branch_taken  = branch & (flag_z ^ bne);
    assign branch_target = pc_plus1 + imm8;   
    assign jump_target   = imm8;              
    assign jr_target     = rs_val;

   // MUX ======================================
    assign pc_sel = jump_reg     ? 2'b11 :
                    jump         ? 2'b10 :
                    branch_taken ? 2'b01 :
                                   2'b00;

endmodule
