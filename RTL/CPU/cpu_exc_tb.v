`timescale 1ns/1ps
module cpu_exc_tb #(
    parameter PROG      = "exc_illegal.hex",
    parameter EXP_CAUSE = 8'h02,
    parameter EXP_EPC   = 8'h02,
    parameter EXP_EE    = 1
);

    reg         clk   = 1'b1;
    reg         reset = 1'b1;
    wire        halt;
    wire [7:0]  pc;
    wire [7:0]  epc, cause;
    wire        exception;

    integer errors = 0;
    integer cycle  = 0;
    integer i;
    integer exp_cause, exp_epc, exp_ee;

    reg saw_halt = 1'b0;
    always @(posedge clk) if (halt) saw_halt <= 1'b1;

    always #5 clk = ~clk;

    cpu #(.PROG(PROG)) DUT (
        .clk          (clk),
        .reset        (reset),
        .halt         (halt),
        .pc_out       (pc),
        .epc_out      (epc),
        .cause_out    (cause),
        .exception_out(exception)
    );


    wire [7:0] r00_zero = DUT.RF.regs[0];
    wire [7:0] r01_at   = DUT.RF.regs[1];
    wire [7:0] r02_v0   = DUT.RF.regs[2];
    wire [7:0] r03_v1   = DUT.RF.regs[3];
    wire [7:0] r04_a0   = DUT.RF.regs[4];
    wire [7:0] r05_a1   = DUT.RF.regs[5];
    wire [7:0] r06_a2   = DUT.RF.regs[6];
    wire [7:0] r07_a3   = DUT.RF.regs[7];
    wire [7:0] r08_t0   = DUT.RF.regs[8];
    wire [7:0] r09_t1   = DUT.RF.regs[9];
    wire [7:0] r10_t2   = DUT.RF.regs[10];
    wire [7:0] r11_t3   = DUT.RF.regs[11];
    wire [7:0] r12_t4   = DUT.RF.regs[12];
    wire [7:0] r13_t5   = DUT.RF.regs[13];
    wire [7:0] r14_t6   = DUT.RF.regs[14];
    wire [7:0] r15_t7   = DUT.RF.regs[15];
    wire [7:0] r16_s0   = DUT.RF.regs[16];
    wire [7:0] r17_s1   = DUT.RF.regs[17];
    wire [7:0] r18_s2   = DUT.RF.regs[18];
    wire [7:0] r19_s3   = DUT.RF.regs[19];
    wire [7:0] r20_s4   = DUT.RF.regs[20];
    wire [7:0] r21_s5   = DUT.RF.regs[21];
    wire [7:0] r22_s6   = DUT.RF.regs[22];
    wire [7:0] r23_s7   = DUT.RF.regs[23];
    wire [7:0] r24_t8   = DUT.RF.regs[24];
    wire [7:0] r25_t9   = DUT.RF.regs[25];
    wire [7:0] r26_k0   = DUT.RF.regs[26];
    wire [7:0] r27_k1   = DUT.RF.regs[27];
    wire [7:0] r28_gp   = DUT.RF.regs[28];
    wire [7:0] r29_sp   = DUT.RF.regs[29];
    wire [7:0] r30_fp   = DUT.RF.regs[30];
    wire [7:0] r31_ra   = DUT.RF.regs[31];

    // ---- pipeline occupancy -------------------------------------------------
    wire [7:0]  IF_pc     = DUT.if_pc;
    wire [7:0]  ID_pc     = DUT.id_pc;
    wire [7:0]  EX_pc     = DUT.ex_pc;
    wire [7:0]  MEM_pc    = DUT.mem_pc;
    wire [7:0]  EX_aluY   = DUT.ex_alu_result;
    wire [4:0]  WB_dest   = DUT.wb_dest_reg;
    wire [7:0]  WB_data   = DUT.wb_data;
    wire        WB_we     = DUT.wb_reg_write;

    // ---- fault plumbing ----------------------------------------------------
    wire        EX_fault  = DUT.ex_exc;
    wire [7:0]  EX_cause  = DUT.ex_cause;
    wire        exc_commit= DUT.exc_taken;
    wire [7:0]  exc_vec   = DUT.exc_vector;
    wire        flush_ifid  = DUT.hz_flush_if_id;
    wire        flush_idex  = DUT.hz_flush_id_ex;
    wire        flush_exmem = DUT.hz_flush_ex_mem;
    wire        flush_memwb = DUT.hz_flush_mem_wb;
    wire        store_en    = DUT.mem_write_eff;   // 0 while a fault commits
    wire [7:0]  store_addr  = DUT.mem_alu_result;
    wire [7:0]  store_data  = DUT.mem_write_data;

    // ---- watched data-memory bytes -----------------------------------------
    wire [7:0] MEM_0xBB = DUT.DMEM.memory[8'hBB];   // must stay 0 on a fault
    wire [7:0] MEM_0xFF = DUT.DMEM.memory[8'hFF];   // handler writes 0xEE here
    wire [7:0] MEM_0xFE = DUT.DMEM.memory[8'hFE];   // wrong-cause path

    // ---- short names used by the checks below -------------------------------
    wire [7:0] t0 = r08_t0;
    wire [7:0] t1 = r09_t1;
    wire [7:0] t2 = r10_t2;    // z = x + y : must stay 0 on a fault
    wire [7:0] t3 = r11_t3;    // marker    : must stay 0 on a fault
    wire [7:0] s1 = r17_s1;    // handler's copy of CAUSE
    wire [7:0] s2 = r18_s2;    // handler's copy of EPC

    // ---- $monitor : watch the machine and the CP0 state live ----------------
    initial begin
        $monitor("t=%0t ns | PC=%0d | CAUSE=0x%02h EPC=%0d exc=%b | $t0=%0d $t1=%0d $t2(z)=%0d $t3=%0d | hCAUSE=0x%02h hEPC=%0d",
                 $time, pc, cause, epc, exception, t0, t1, t2, t3, s1, s2);
    end

    // ---- per-cycle trace ----------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            cycle = cycle + 1;
            $display("cyc=%0d | IF:PC=%0d | EX:PC=%0d aluY=%0d | WB:R%0d<=%0d we=%b | stall=%b squash=%b exc=%b",
                     cycle, pc, DUT.ex_pc, DUT.ex_alu_result,
                     DUT.wb_dest_reg, DUT.wb_data, DUT.wb_reg_write,
                     DUT.hz_stall, DUT.ex_redirect, DUT.exc_taken);

            if (DUT.ex_exc)
                $display("        FAULT detected in EX : cause=0x%02h at PC=%0d",
                         DUT.ex_cause, DUT.ex_pc);
            if (DUT.exc_taken)
                $display("        EXCEPTION COMMITTED  : EPC<=%0d CAUSE<=0x%02h  PC<=vector 0x%02h  [flush IF/ID, ID/EX, EX/MEM, MEM/WB]",
                         DUT.mem_pc, DUT.mem_cause, DUT.exc_vector);
            if (DUT.mem_mem_write && !DUT.exc_taken)
                $display("        STORE MEM[%0d] <= %0d", DUT.mem_alu_result, DUT.mem_write_data);
            if (DUT.mem_mem_write && DUT.exc_taken)
                $display("        STORE to MEM[%0d] CANCELLED by exception", DUT.mem_alu_result);
        end
    end

    // ---- checkers -----------------------------------------------------------
    task check(input [8*16:1] nm, input [7:0] got, input [7:0] expv);
        begin
            if (got !== expv) begin
                $display("  FAIL: %0s = 0x%02h (%0d)   expected 0x%02h (%0d)", nm, got, got, expv, expv);
                errors = errors + 1;
            end else
                $display("  ok  : %0s = 0x%02h (%0d)", nm, got, got);
        end
    endtask

    // ---- stimulus -----------------------------------------------------------
    initial begin
        $dumpfile("cpu_exc_tb.vcd");
        $dumpvars(0, cpu_exc_tb);

        exp_cause = EXP_CAUSE;
        exp_epc   = EXP_EPC;
        exp_ee    = EXP_EE;
        // NOTE: the image is loaded ONLY by Instruction_Memory, from the PROG
        // parameter. Loading it here as well would race with IMEM's own
        // initial block (which zero-fills first) -- under XSim the zero-fill
        // wins and the whole program reads back as 0x00000000 NOPs.
        $display("\n=== program: %0s   expect CAUSE=0x%02h EPC=%0d ===\n", PROG, EXP_CAUSE, EXP_EPC);

        // guard: an empty instruction memory is the classic "hex file not
        // found" symptom -- it simulates as an endless NOP slide and looks
        // exactly like a dead CPU.
        if (DUT.IMEM.Instr_Array[0] === 32'h0000_0000 &&
            DUT.IMEM.Instr_Array[1] === 32'h0000_0000) begin
            $display("  *** INSTRUCTION MEMORY IS EMPTY -- %0s was not loaded.", PROG);
            $display("  *** The file must sit in the SIMULATOR's working directory");
            $display("  *** (Vivado: <proj>.sim/sim_1/behav/xsim/), not the source folder.");
            errors = errors + 1;
        end

        @(negedge clk); @(negedge clk);
        reset = 0;

        wait (saw_halt === 1'b1);
        @(negedge clk);

        $display("\n========== HLT retired after %0d cycles ==========", cycle);

        $display("---- CP0 (exception) state ----");
        check("CAUSE",        cause,  exp_cause[7:0]);
        check("EPC",          epc,    exp_epc[7:0]);
        $display("---- handler's own view (read back with MFCAUSE / MFEPC) ----");
        if (exp_ee != 0) begin
            check("$s1 = CAUSE", s1, exp_cause[7:0]);
            check("$s2 = EPC",   s2, exp_epc[7:0]);
        end

        $display("---- containment ----");
        check("MEM[0xBB]", DUT.DMEM.memory[8'hBB], exp_ee ? 8'h00 : 8'd30);
        check("MEM[0xFF]", DUT.DMEM.memory[8'hFF], exp_ee ? 8'hEE : 8'h00);
        check("MEM[0xFE]", DUT.DMEM.memory[8'hFE], 8'h00);   // wrong-cause path
        if (exp_ee != 0) begin
            check("$t2 (z)",  t2, 8'h00);                    // squashed ADD
            check("$t3",      t3, 8'h00);                    // squashed marker
        end

        $display("---- non-zero registers ----");
        for (i = 0; i < 32; i = i + 1)
            if (DUT.RF.regs[i] !== 8'd0)
                $display("   R%0d = %0d (0x%02h)", i, DUT.RF.regs[i], DUT.RF.regs[i]);

        $display("\n========== %0s  (%0d error%0s) ==========\n",
                 (errors == 0) ? "PASSED" : "FAILED",
                 errors, (errors == 1) ? "" : "s");
        $finish;
    end

    initial begin
        #20000;
        $display("TIMEOUT: halt never asserted");
        $finish;
    end

endmodule
