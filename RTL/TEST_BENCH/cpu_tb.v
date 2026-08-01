`timescale 1ns/1ps

module cpu_tb;

    reg clk = 1;
    reg reset = 1;
    wire halt;
    wire [7:0]  pc;
    wire [31:0] instr;

    integer errors = 0;
    integer cycle  = 0;

    // 100 MHz clock
    always #5 clk = ~clk;

    // MAPPING ===============================================================

    cpu DUT (
        .clk      (clk),
        .reset    (reset),
        .halt     (halt),
        .pc_out   (pc),
        .instr_out(instr)
    );

    //  load program into instruction memory (hierarchical) -------------
    initial begin
        $readmemh("program.hex", DUT.IMEM.Instr_Array);
    end

    //  per-cycle trace --------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            cycle = cycle + 1;
            $display("[%0t] cyc=%0d  PC=%0d  instr=%h  halt=%b",
                     $time, cycle, pc, instr, halt);
        end
    end

    // CHECKER =================================================================

    task check_reg(input [4:0] r, input [7:0] expv);
        begin
            if (DUT.RF.regs[r] !== expv) begin
                $display("  FAIL: R%0d = %0d  (expected %0d)", r, DUT.RF.regs[r], expv);
                errors = errors + 1;
            end else
                $display("  ok  : R%0d = %0d", r, DUT.RF.regs[r]);
        end
    endtask

    task check_mem(input [7:0] a, input [7:0] expv);
        begin
            if (DUT.DMEM.memory[a] !== expv) begin
                $display("  FAIL: MEM[%0d] = %0d  (expected %0d)", a, DUT.DMEM.memory[a], expv);
                errors = errors + 1;
            end else
                $display("  ok  : MEM[%0d] = %0d", a, DUT.DMEM.memory[a]);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        // hold reset 2 cycles
        @(negedge clk); @(negedge clk);
        reset = 0;

        // run until halt, with a safety timeout
        wait (halt === 1'b1);
        @(negedge clk);   // let the halting cycle settle

        $display("\n========== HALT reached at PC=%0d, cycle=%0d ==========", pc, cycle);
        $display("---- register checks ----");
        check_reg(1, 5);   check_reg(2, 3);   check_reg(3, 8);   check_reg(4, 2);
        check_reg(5, 1);   check_reg(6, 7);   check_reg(7, 6);   check_reg(8, 1);
        check_reg(9, 0);   check_reg(10, 8);  check_reg(11, 0);  check_reg(12, 7);
        check_reg(13, 0);  check_reg(15, 42); check_reg(16, 9);  check_reg(31, 19);

        $display("---- data memory checks ----");
        check_mem(0, 8);

        $display("\n========== %s  (%0d error%s) ==========\n",
                 (errors==0) ? "ALL TESTS PASSED" : "TESTS FAILED",
                 errors, (errors==1) ? "" : "s");
        $finish;
    end

    // global timeout guard
    initial begin
        #2000;
        $display("TIMEOUT: halt never asserted");
        $finish;
    end

endmodule
