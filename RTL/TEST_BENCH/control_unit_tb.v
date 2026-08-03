`timescale 1ns/1ps

module cu_tb;
    reg  [5:0] opcode, funct;
    wire [1:0] reg_dst, mem_to_reg;
    wire       alu_src, branch, jump, jal, jump_reg, reg_write, mem_read, mem_write, halt;
    wire [2:0] alu_op;
    
    // New exception/system wires
    wire       illegal, trap, ov_en, cp0_read, cp0_sel;
    
    integer    errors = 0;

    // MAPPING ===============================================================

    control_unit DUT (
        .opcode(opcode), .funct(funct),
        .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jal(jal), .jump_reg(jump_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .alu_op(alu_op), .halt(halt),
        
        // New exception mapping
        .illegal(illegal), .trap(trap), .ov_en(ov_en), 
        .cp0_read(cp0_read), .cp0_sel(cp0_sel)
    );

    // Concatenated Control Word (now 21 bits long instead of 16)
    wire [20:0] cw = {reg_dst, alu_src, mem_to_reg, branch, jump, jal,
                      jump_reg, reg_write, mem_read, mem_write, alu_op, halt,
                      illegal, trap, ov_en, cp0_read, cp0_sel};

    // CHECKER =================================================================

    task chk(input [8*12:1] name, input [5:0] op, input [5:0] f, input [20:0] exp);
        begin
            opcode = op; funct = f; #1;
            if (cw !== exp) begin
                $display("  FAIL %-12s cw=%b (exp %b)", name, cw, exp);
                errors = errors + 1;
            end else
                $display("  ok   %-12s cw=%b", name, cw);
        end
    endtask

    //================================================================================
    // STIMULATON
    // ==============================================================================

    initial begin
        // Format: {reg_dst(2), alu_src(1), mem_to_reg(2), branch(1), jump(1), jal(1), jump_reg(1), reg_write(1), mem_read(1), mem_write(1), alu_op(3), halt(1), illegal(1), trap(1), ov_en(1), cp0_read(1), cp0_sel(1)}
        
        // STANDARD INSTRUCTIONS
        // NOTE: ADD (0x20) triggers ov_en=1
        chk("R_ADD",   6'h00, 6'h20, {2'b01,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b111,1'b0,  1'b0,1'b0,1'b1,1'b0,1'b0});
        chk("R_MUL",   6'h00, 6'h18, {2'b01,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b111,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("JR",      6'h00, 6'h08, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        
        // NOTE: ADDI triggers ov_en=1
        chk("ADDI",    6'h08, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b1,1'b0,1'b0});
        
        chk("SLTI",    6'h0A, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b101,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("ANDI",    6'h0C, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b010,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("ORI",     6'h0D, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b011,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("XORI",    6'h0E, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b100,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("LW",      6'h23, 6'h00, {2'b00,1'b1,2'b01,1'b0,1'b0,1'b0,1'b0,1'b1,1'b1,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("SW",      6'h2B, 6'h00, {2'b00,1'b1,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("BEQ",     6'h04, 6'h00, {2'b00,1'b0,2'b00,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b001,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("BNE",     6'h05, 6'h00, {2'b00,1'b0,2'b00,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b001,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("J",       6'h02, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b1,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("JAL",     6'h03, 6'h00, {2'b10,1'b0,2'b10,1'b0,1'b1,1'b1,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b0,1'b0});
        chk("HLT",     6'h3F, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b1,  1'b0,1'b0,1'b0,1'b0,1'b0});

        // NEW EXCEPTION AND SYSTEM INSTRUCTIONS
        chk("TRAP",    6'h1A, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b1,1'b0,1'b0,1'b0});
        chk("MFCAUSE", 6'h00, 6'h1E, {2'b01,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b1,1'b0});
        chk("MFEPC",   6'h00, 6'h1F, {2'b01,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,3'b000,1'b0,  1'b0,1'b0,1'b0,1'b1,1'b1});
        
        // ILLEGAL INSTRUCTIONS
        chk("ILL_OP",  6'h3E, 6'h00, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,  1'b1,1'b0,1'b0,1'b0,1'b0});
        chk("ILL_FUN", 6'h00, 6'h3F, {2'b00,1'b0,2'b00,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,  1'b1,1'b0,1'b0,1'b0,1'b0});

        $display("\n[cu_tb] %s (%0d error%s)\n",
                 (errors==0)?"PASS":"FAIL", errors, (errors==1)?"":"s");
        $finish;
    end
endmodule
