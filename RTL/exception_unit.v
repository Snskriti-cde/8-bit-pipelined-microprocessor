`timescale 1ns / 1ps
// =============================================================================
//  exception_unit.v  --  ECU (coprocessor-0 equivalent)
//
//  WHERE THE EXCEPTION IS TAKEN, AND WHY
//  -------------------------------------
//  Faults are *detected* at different stages:
//      illegal opcode / TRAP -> ID  (pure decode)
//      arithmetic overflow   -> EX  (needs the ALU V flag)
//      divide-by-zero        -> EX  (needs the ALU B operand)
//
//  If each one redirected the PC where it was found, the machine would be
//  imprecise: an older instruction still in EX/MEM could be killed by a
//  younger instruction's fault. Instead every fault is turned into a pair of
//  flags (exc, cause) that RIDES THE PIPELINE with its own instruction, and
//  the exception is COMMITTED when that instruction reaches MEM.
//
//  At the commit cycle, the faulting instruction is the oldest thing left in
//  the machine:
//      MEM     <- faulting instruction  (its own mem_write + WB are killed)
//      EX      <- younger  -> flush EX/MEM
//      ID      <- younger  -> flush ID/EX
//      IF      <- younger  -> flush IF/ID
//  Everything older has already retired. That is a precise exception.
//
//  ARCHITECTURAL STATE
//      EPC   : PC of the faulting instruction (NOT PC+1 -- the fault address
//              is what the task asks to latch)
//      CAUSE : 0x00 none | 0x01 overflow | 0x02 illegal | 0x03 TRAP | 0x04 div0
//  Both are readable by the handler via MFEPC / MFCAUSE (R-type, funct 1F/1E).
// =============================================================================
module exception_unit #(
    parameter [7:0] VECTOR = 8'h20      // exception vector address in IMEM
)(
    input             clk,
    input             reset,

    // ---- fault report from the MEM stage ------------------------------------
    input             mem_exc,          // faulting instruction is now in MEM
    input      [7:0]  mem_cause,        // its cause code
    input      [7:0]  mem_pc,           // its own PC (carried down the pipe)

    // ---- architectural (CP0) state ------------------------------------------
    output reg [7:0]  epc,
    output reg [7:0]  cause,

    // ---- commit / redirect --------------------------------------------------
    output            exc_taken,        // 1 = flush + redirect THIS cycle
    output     [7:0]  exc_vector
);

    // The commit is combinational so that the flushes and the PC redirect all
    // happen on the same clock edge that would otherwise have let the younger
    // instructions advance.
    assign exc_taken  = mem_exc;
    assign exc_vector = VECTOR;

    always @(posedge clk) begin
        if (reset) begin
            epc   <= 8'h00;
            cause <= 8'h00;
        end
        else if (exc_taken) begin
            epc   <= mem_pc;             // exact address of the faulty instruction
            cause <= mem_cause;
        end
    end

endmodule
