`include "alu_defs.vh"

module alu_control (
    input      [2:0] alu_op,   
    input      [5:0] funct,     
    output reg [4:0] alu_control  
);

    // alu_op classes (must match control_unit.v)
    localparam AOP_ADD=3'b000, AOP_SUB=3'b001, AOP_AND=3'b010, AOP_OR=3'b011,
               AOP_XOR=3'b100, AOP_SLT=3'b101, AOP_RTYPE=3'b111;

    // R-type funct codes
    localparam F_ADD=6'h20, F_SUB=6'h22, F_AND=6'h24, F_OR=6'h25, F_XOR=6'h26,
               F_NOR=6'h27, F_SLT=6'h2A, F_SLL=6'h00, F_SRL=6'h02, F_SRA=6'h03,
               F_ROL=6'h10, F_ROR=6'h11, F_JR=6'h08, F_NOT=6'h21, F_PASA=6'h23,
               F_INC=6'h12, F_DEC=6'h13m F_MUL=6'h18, F_DIV=6'h1A;

    always @(*) begin
   // default 
        
        case (alu_op)
            AOP_ADD: alu_control = `ALU_ADD;
            AOP_SUB: alu_control = `ALU_SUB;
            AOP_AND: alu_control = `ALU_AND;
            AOP_OR : alu_control = `ALU_OR;
            AOP_XOR: alu_control = `ALU_XOR;
            AOP_SLT: alu_control = `ALU_SLT;
            AOP_RTYPE: begin
                case (funct)
                    F_ADD: alu_control = `ALU_ADD;
                    F_SUB: alu_control = `ALU_SUB;
                    F_AND: alu_control = `ALU_AND;
                    F_OR : alu_control = `ALU_OR;
                    F_XOR: alu_control = `ALU_XOR;
                    F_NOR: alu_control = `ALU_NOR;
                    F_SLT: alu_control = `ALU_SLT;
                    F_SLL: alu_control = `ALU_SLL;
                    F_SRL: alu_control = `ALU_SRL;
                    F_SRA: alu_control = `ALU_SRA;
                    F_ROL: alu_control = `ALU_ROL;
                    F_ROR: alu_control = `ALU_ROR;
                    F_NOT:  alu_control = `ALU_NOT;     
                    F_PASA: alu_control = `ALU_PASA;    
                    F_INC:  alu_control = `ALU_INC;     
                    F_DEC:  alu_control = `ALU_DEC;
	            F_MUL:  alu_control = `ALU_MUL;
		    F_DIV:  alu_control = `ALU_DIV;
                    default: alu_control = `ALU_ADD; // JR/unknown: ALU result unused
                endcase
            end
            default: alu_control = `ALU_ADD;         // safe default -> no latch
        endcase
    end

endmodule
