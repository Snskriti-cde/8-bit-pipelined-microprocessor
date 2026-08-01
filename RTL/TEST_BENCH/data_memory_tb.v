`timescale 1ns/1ps

module data_memory_tb;
    reg        clk = 0, rst, memRead, memWrite;
    reg  [7:0] address, writeData;
    wire [7:0] readData;
    integer    errors = 0;

    always #5 clk = ~clk;

    data_memory #(.DATA_WIDTH(8), .ADDR_WIDTH(8), .MEM_DEPTH(256)) DUT (
        .clk(clk), .rst(rst), .memRead(memRead), .memWrite(memWrite),
        .address(address), .writeData(writeData), .readData(readData)
    );

    task wr(input [7:0] addr, input [7:0] d);
        begin
            @(negedge clk); memWrite=1; memRead=0; address=addr; writeData=d;
            @(negedge clk); memWrite=0;
        end
    endtask

    // CHECKER =================================================================

    task chk(input [8*18:1] name, input [7:0] got, input [7:0] exp);
        begin
            if (got!==exp) begin
                $display("  FAIL %-20s = %h (exp %h)", name, got, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-20s = %h", name, got);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        rst=1; memRead=0; memWrite=0; address=0; writeData=0;
        @(negedge clk); @(negedge clk); rst=0;

        // write/read-back
        wr(8'd5, 8'hAB);
        memRead=1; address=8'd5; #1; chk("write/read addr5", readData, 8'hAB);

        wr(8'd200, 8'hCD);
        memRead=1; address=8'd200; #1; chk("write/read addr200", readData, 8'hCD);

        // memRead=0 -> readData must be 0 (not stored value)
        memRead=0; address=8'd5; #1; chk("memRead=0 -> 0", readData, 8'h00);

        // write must not happen when memWrite=0
        @(negedge clk); memWrite=0; address=8'd5; writeData=8'h99;
        @(negedge clk); memRead=1; address=8'd5; #1; chk("memWrite=0 no change", readData, 8'hAB);

        // synchronous reset clears
        @(negedge clk); rst=1;
        @(negedge clk); rst=0;
        memRead=1; address=8'd5; #1; chk("reset clears addr5", readData, 8'h00);

        $display("\n[data_memory_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
