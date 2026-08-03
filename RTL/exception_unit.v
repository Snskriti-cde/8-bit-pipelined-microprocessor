`timescale 1ns / 1ps

module exception_unit #(
    parameter [7:0] VECTOR = 8'h20     
)(
    input             clk,
    input             reset,

    // ---- fault report from the MEM stage ------------------------------------
    input             mem_exc,         
    input      [7:0]  mem_cause,       
    input      [7:0]  mem_pc,        

    // ---- architectural (CP0) state ------------------------------------------
    output reg [7:0]  epc,
    output reg [7:0]  cause,

    // ---- commit / redirect --------------------------------------------------
    output            exc_taken,       
    output     [7:0]  exc_vector
);

    assign exc_taken  = mem_exc;
    assign exc_vector = VECTOR;

    always @(posedge clk) begin
        if (reset) begin
            epc   <= 8'h00;
            cause <= 8'h00;
        end
        else if (exc_taken) begin
            epc   <= mem_pc;            
            cause <= mem_cause;
        end
    end

endmodule
