`timescale 1ns / 1ps

module Program_Counter(
    input            Clock,
    input            Reset,
    input            Pc_Write,                      
    input      [1:0] Pc_Sel,                     
    input      [7:0] Jr_Target,                   
    input      [7:0] Jump_Target,                  
    input      [7:0] Branch_Target,                 
    input            Exc_Taken,                      // 1 = fault committed
    input      [7:0] Exc_Vector,                     // handler entry point
    output reg [7:0] Pc,
    output     [7:0] Pc_Next                       
);

    assign Pc_Next = Pc + 8'd1;

    reg [7:0] Pc_nxt_instr;
    always @(*) begin
        if (Exc_Taken)                               // highest priority
            Pc_nxt_instr = Exc_Vector;
        else begin
            case (Pc_Sel)
                2'b00:   Pc_nxt_instr = Pc_Next;     // sequential
                2'b01:   Pc_nxt_instr = Branch_Target;
                2'b10:   Pc_nxt_instr = Jump_Target; // J / JAL
                2'b11:   Pc_nxt_instr = Jr_Target;   // JR
                default: Pc_nxt_instr = Pc_Next;     // avoid latch
            endcase
        end
    end

    always @(posedge Clock) begin
        if (Reset)          Pc <= 8'b0;
        else if (Pc_Write)  Pc <= Pc_nxt_instr;
        // else: hold current PC (stall / halted)
    end

endmodule
