`timescale 1ns/1ps

module instruction_memory_tb;
    reg  [7:0]  Address;
    wire [31:0] Instr;
    integer     errors = 0;

    // MAPPING ===============================================================

    Instruction_Memory DUT (.Address(Address), .Instr(Instr));

    // CHECKER =================================================================

    // Widened name array to 20 chars to fit test case names nicely
    task chk(input [8*20:1] name, input [7:0] addr, input [31:0] exp);
        begin
            Address = addr; #1;
            if (Instr !== exp) begin
                $display("  FAIL %-20s [%0d]=%h (exp %h)", name, addr, Instr, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-20s [%0d]=%h", name, addr, Instr);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        // Wait for DUT's initial block (which clears memory and runs $readmemh) to finish
        #5; 

        DUT.Instr_Array[0]   = 32'h20010005; // ADDI
        DUT.Instr_Array[2]   = 32'h00221820; // ADD
        DUT.Instr_Array[10]  = 32'h8c0a0000; // LW
        DUT.Instr_Array[23]  = 32'hfc000000; // HLT
        DUT.Instr_Array[255] = 32'hFFFFFFFF; // Boundary test

        chk("prog[0] ADDI",  8'd0,   32'h20010005);
        chk("prog[2] ADD",   8'd2,   32'h00221820);
        chk("prog[23] HLT",  8'd23,  32'hfc000000);
        
        chk("prog[255] MAX", 8'd255, 32'hFFFFFFFF);

        DUT.Instr_Array[50] = 32'h00000000; 
        chk("empty[50]", 8'd50, 32'h00000000);

        Address = 8'd10; #1;
        if (Instr !== 32'h8c0a0000) begin
            $display("  FAIL async LW [10]=%h (exp 8c0a0000)", Instr); errors=errors+1;
        end else $display("  ok   async LW [10]=%h", Instr);

        $display("\n[instruction_memory_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
