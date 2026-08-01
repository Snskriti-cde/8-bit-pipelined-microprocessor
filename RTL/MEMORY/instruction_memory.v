`timescale 1ns / 1ps
module Instruction_Memory(
input[7:0] Address, //address from program counter
output[31:0] Instr //instruction word (32-bit)
    );
   
 reg[31:0] Instr_Array[0:255]; 
 initial
   begin
   Instr_Array[0]=32'h9c367a34;
     Instr_Array[1] = 32'h000458bc;
   end
   assign Instr = Instr_Array[Address];
endmodule
