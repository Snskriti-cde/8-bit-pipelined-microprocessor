`timescale 1ns/1ps

module instruction_memory_tb;
    reg  [7:0]  Address;
    wire [31:0] Instr;
    integer     errors = 0;

    // MAPPING ===============================================================

    Instruction_Memory DUT (.Address(Address), .Instr(Instr));

    // CHECKER =================================================================

    task chk(input [8*16:1] name, input [7:0] addr, input [31:0] exp);
        begin
            Address = addr; #1;
            if (Instr !== exp) begin
                $display("  FAIL %-18s [%0d]=%h (exp %h)", name, addr, Instr, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-18s [%0d]=%h", name, addr, Instr);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        // default hard-coded contents from the module's initial block
        chk("default[0]", 8'd0, 32'h9c367a34);
        chk("default[1]", 8'd1, 32'h000458bc);

        // overlay a known program and re-check addressing is purely combinational
        $readmemh("program.hex", DUT.Instr_Array);
        #1;
        chk("prog[0] ADDI", 8'd0, 32'h20010005);
        chk("prog[2] ADD",  8'd2, 32'h00221820);
        chk("prog[23] HLT", 8'd23, 32'hfc000000);

        // async: address change with no clock produces new word immediately
        Address = 8'd10; #1;
        if (Instr !== 32'h8c0a0000) begin
            $display("  FAIL async LW [10]=%h (exp 8c0a0000)", Instr); errors=errors+1;
        end else $display("  ok   async LW [10]=%h", Instr);

        $display("\n[instruction_memory_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
