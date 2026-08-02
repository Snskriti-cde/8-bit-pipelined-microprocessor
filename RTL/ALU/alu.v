`include "alu_defs.vh"

module alu (
    input      [7:0] a,         
    input      [7:0] b,       
    input      [4:0] shamt,      
    input      [4:0] alu_control, 
    output reg [7:0] result,
    output           less_than,
    output           carry,

    output wire       flag_z,
    output reg        flag_n,
    output reg        flag_c,
    output reg         flag_v
);

   // 9 BIT = CARRY + RESULT
    wire       do_sub = (alu_control == `ALU_SUB) || (alu_control == `ALU_SLT);
    wire [7:0] b_eff  = do_sub ? ~b : b;
    wire [8:0] sum9   = {1'b0, a} + {1'b0, b_eff} + {8'b0, do_sub};
    wire [7:0] sum    = sum9[7:0];

    // SLT---------------------------------------------------------
    wire [7:0] diff = sum;
    wire       lt   = (a[7] ^ b[7]) ? a[7] : diff[7];
    assign     less_than = lt;

    // shifts / rotates on b ----------------------------------------------
   wire [2:0] sh   = shamt[2:0];
   wire [7:0] rotate_left_  = (sh == 3'd0) ? b : (b << sh) | (b >> (4'd8 - sh));
   wire [7:0] rotate_right_ = (sh == 3'd0) ? b : (b >> sh) | (b << (4'd8 - sh));

    //  increment / decrement -----------------------------------------------
    wire [8:0] inc_dec9 = (alu_control == `ALU_INC) ? ({1'b0,a} + 9'd1) :
                          (alu_control == `ALU_DEC) ? ({1'b0,a} - 9'd1) : 9'd0;


    always @(*) begin
        result = 8'd0;
        flag_c = 1'b0;
        flag_v = 1'b0;

        case (alu_control)
            // arithmetic
            `ALU_ADD: begin
                result = sum;
                flag_c = sum9[8];
                flag_v = (a[7] == b_eff[7]) && (sum[7] != a[7]);
            end
            `ALU_SUB: begin
                result = sum;
                flag_c = sum9[8];                         
                flag_v = (a[7] == b_eff[7]) && (sum[7] != a[7]);
            end

            // bitwise
            `ALU_AND:  result = a & b;
            `ALU_OR:   result = a | b;
            `ALU_XOR:  result = a ^ b;
            `ALU_NOT:  result = ~a;
            `ALU_PASA: result = a;                         
            `ALU_NOR:  result = ~(a | b);

            // set less than
            `ALU_SLT:  result = {7'b0, lt};

            // logical shifts
            `ALU_SLL:  result = b << sh;
            `ALU_SRL:  result = b >> sh;

            // arithmetic shift
            `ALU_SRA:  result = $signed(b) >>> sh;         // preserves sign of b

            // rotates
            `ALU_ROL:  result = rotate_left_;
            `ALU_ROR:  result = rotate_right_;

            // increment / decrement
            `ALU_INC: begin
                result = inc_dec9[7:0];
                flag_c = inc_dec9[8];
                flag_v = (a == 8'h7F);
            end
            `ALU_DEC: begin
                result = inc_dec9[7:0];
                flag_c = inc_dec9[8];
                flag_v = (a == 8'h80);
            end
	   `ALU_MUL: begin
		result = a*b;
            end
	   `ALU_DIV: begin
		result = a / b;
	    end
            default: result = 8'b0;                        // safe default -> no latch
        endcase

        flag_n = result[7];
    end

    assign flag_z = (result == 8'd0);
    assign carry  = flag_c;

endmodule
