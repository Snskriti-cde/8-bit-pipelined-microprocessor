`timescale 1ns / 1ps

module Instruction_Memory #(
    parameter MEM_FILE = "program.hex"
)(
    input      [7:0]  Address,   // word-addressed, from the program counter
    output     [31:0] Instr
);

    reg [31:0] Instr_Array [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            Instr_Array[i] = 32'h0000_0000;
        
            $readmemh(MEM_FILE, Instr_Array);
    end

    assign Instr = Instr_Array[Address];

endmodule
