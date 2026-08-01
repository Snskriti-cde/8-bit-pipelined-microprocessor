
`timescale 1ns/1ps

module program_counter_tb;
    reg        Clock = 1, Reset;
    reg  [1:0] Pc_Sel;
    reg  [7:0] Jr_Target, Jump_Target, Branch_Target;
    wire [7:0] Pc, Pc_Next;
    integer    errors = 0;
     
    always #5 Clock = ~Clock;

    // MAPPING ===============================================================

    Program_Counter DUT (
        .Clock(Clock), .Reset(Reset), .Pc_Sel(Pc_Sel),
        .Jr_Target(Jr_Target), .Jump_Target(Jump_Target),
        .Branch_Target(Branch_Target), .Pc(Pc), .Pc_Next(Pc_Next)
    );
   
    // CHECKER =================================================================

    task chk(input [8*16:1] name, input [7:0] got, input [7:0] exp);
        begin
            if (got!==exp) begin
                $display("  FAIL %-18s = %0d (exp %0d)", name, got, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-18s = %0d", name, got);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ===============================================================================

    initial begin
        Reset=1; Pc_Sel=2'b00; Jr_Target=0; Jump_Target=0; Branch_Target=0;
        @(negedge Clock);
        chk("reset", Pc, 8'd0);

        // sequential increment
        Reset=0; Pc_Sel=2'b00;
        @(negedge Clock); chk("seq +1", Pc, 8'd1);
        @(negedge Clock); chk("seq +2", Pc, 8'd2);
        chk("Pc_Next comb", Pc_Next, 8'd3);   // Pc=2 -> Pc_Next=3

        // branch source (01)
        Branch_Target=8'd50; Pc_Sel=2'b01;
        @(negedge Clock); chk("branch target", Pc, 8'd50);

        // jump source (10)
        Jump_Target=8'd123; Pc_Sel=2'b10;
        @(negedge Clock); chk("jump target", Pc, 8'd123);

        // jr source (11)
        Jr_Target=8'd200; Pc_Sel=2'b11;
        @(negedge Clock); chk("jr target", Pc, 8'd200);

        // back to sequential
        Pc_Sel=2'b00;
        @(negedge Clock); chk("seq after jr", Pc, 8'd201);

        // 8-bit wrap: force Pc to 0xFF via jump, then +1 -> 0x00
        Jump_Target=8'hFF; Pc_Sel=2'b10;
        @(negedge Clock); chk("set 255", Pc, 8'hFF);
        Pc_Sel=2'b00;
        @(negedge Clock); chk("wrap to 0", Pc, 8'h00);

        $display("\n[program_counter_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule