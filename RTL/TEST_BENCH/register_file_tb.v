`timescale 1ns/1ps

module register_file_tb;
    reg        clk = 0, reset, reg_write;
    reg  [4:0] read_reg_1, read_reg_2, write_reg;
    reg  [7:0] write_data;
    wire [7:0] read_data_1, read_data_2;
    integer    errors = 0;

    always #5 clk = ~clk;

    register_file #(.DATA_WIDTH(8), .NUM_REGS(32)) DUT (
        .clk(clk), .reset(reset), .reg_write(reg_write),
        .read_reg_1(read_reg_1), .read_reg_2(read_reg_2),
        .write_reg(write_reg), .write_data(write_data),
        .read_data_1(read_data_1), .read_data_2(read_data_2)
    );

    task wr(input [4:0] r, input [7:0] d);
        begin
            @(negedge clk); reg_write=1; write_reg=r; write_data=d;
            @(negedge clk); reg_write=0;
        end
    endtask

    // CHECKER =================================================================

    // Widened name string to 22 characters to fit new test cases
    task chk1(input [8*22:1] name, input [7:0] got, input [7:0] exp);
        begin
            if (got!==exp) begin
                $display("  FAIL %-22s = %h (exp %h)", name, got, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-22s = %h", name, got);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        reset=1; reg_write=0; read_reg_1=0; read_reg_2=0; write_reg=0; write_data=0;
        @(negedge clk); @(negedge clk); reset=0;

        // write then async read-back
        wr(5'd3, 8'hAB);
        read_reg_1=5'd3; #1; chk1("write/read R3", read_data_1, 8'hAB);

        // a second register, read on port B
        wr(5'd10, 8'h5C);
        read_reg_2=5'd10; #1; chk1("write/read R10", read_data_2, 8'h5C);

        // R0 hardwired: attempt to write, must stay 0
        wr(5'd0, 8'hFF);
        read_reg_1=5'd0; #1; chk1("R0 write ignored", read_data_1, 8'h00);

        // asynchronous read: change address, no clock edge needed
        read_reg_1=5'd3; #1; chk1("async read R3", read_data_1, 8'hAB);
        read_reg_1=5'd10; #1; chk1("async read R10", read_data_1, 8'h5C);

        // write-enable gating: reg_write=0 must not write
        @(negedge clk); reg_write=0; write_reg=5'd3; write_data=8'h00;
        @(negedge clk); read_reg_1=5'd3; #1; chk1("WE=0 no write", read_data_1, 8'hAB);

        // -------------------------------------------------------------------
        // NEW FEATURE TESTS: Internal Forwarding (Write-Through Bypass)
        // -------------------------------------------------------------------
        @(negedge clk); 
        reg_write = 1; write_reg = 5'd7; write_data = 8'h99;
        read_reg_1 = 5'd7; read_reg_2 = 5'd7; 
        #1; // Combinational delay, NO clock edge yet!
        
        // Even without a clock edge, the read ports should immediately show 8'h99
        chk1("internal fwd R7 (P1)", read_data_1, 8'h99);
        chk1("internal fwd R7 (P2)", read_data_2, 8'h99);
        
        // Wait for clock edge to actually commit the write, then turn off WE
        @(negedge clk); reg_write = 0; 
        read_reg_1 = 5'd7; #1; chk1("R7 committed", read_data_1, 8'h99);
        // -------------------------------------------------------------------

        // synchronous reset clears everything
        @(negedge clk); reset=1;
        @(negedge clk); reset=0;
        read_reg_1=5'd3; read_reg_2=5'd10; #1;
        chk1("reset clears R3", read_data_1, 8'h00);
        chk1("reset clears R10", read_data_2, 8'h00);
        
        // Check R7 from the forwarding test was also cleared
        read_reg_1=5'd7; #1; chk1("reset clears R7", read_data_1, 8'h00);

        $display("\n[register_file_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
