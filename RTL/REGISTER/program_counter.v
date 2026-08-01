`timescale 1ns / 1ps
module Program_Counter(
    input Clock,Reset,
    input[1:0] Pc_Sel,
    input[7:0] Jr_Target,Jump_Target,Branch_Target, //jump for j/jal ,jr for jr
    output reg[7:0] Pc,
    output[7:0] Pc_Next  //other units need it JAL,branch unit
    );
    
  assign Pc_Next = Pc + 1; 
  
 reg [7:0] Pc_nxt_instr;  // next instruction
 always @(*)
   begin
    case(Pc_Sel) // like multiplexer 4to1 
     2'b00:  Pc_nxt_instr = Pc_Next;      
     2'b01:   Pc_nxt_instr = Branch_Target;  
     2'b10:   Pc_nxt_instr= Jump_Target;    
     2'b11:   Pc_nxt_instr = Jr_Target;      
     default: Pc_nxt_instr = Pc_Next; // avoid latch
    endcase
   end
    
 always @(posedge Clock)
  begin
   if (Reset) Pc<= 8'b0;
   else  Pc <= Pc_nxt_instr; 
  end
endmodule
