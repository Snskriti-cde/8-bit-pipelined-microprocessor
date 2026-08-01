`timescale 1ns / 1ps

module forwarding_unit_tb;
    reg [4:0] id_ex_rs;
    reg [4:0] id_ex_rt;
    reg [4:0] ex_mem_rd;
    reg ex_mem_reg_write;
    reg [4:0] mem_wb_rd;
    reg mem_wb_reg_write;
    wire [1:0] forwardA;
    wire [1:0] forwardB;
    integer errors = 0;
    integer test_num = 0;
    
    forwarding_unit DUT(
    .id_ex_rs(id_ex_rs), 
    .id_ex_rt(id_ex_rt), 
    .ex_mem_reg_write(ex_mem_reg_write), 
    .ex_mem_rd(ex_mem_rd),
    .mem_wb_rd(mem_wb_rd), 
    .mem_wb_reg_write(mem_wb_reg_write), 
    .forwardA(forwardA), .forwardB(forwardB) 
    );
    
    // STIMULATION ====================================
    initial begin
        id_ex_rs = 5'b0;
        id_ex_rt = 5'b0; 
        ex_mem_rd = 5'b0; 
        mem_wb_rd = 5'b0;
        ex_mem_reg_write = 1'b0; 
        mem_wb_reg_write = 1'b0;
        
        #10;
        // no forwarding 
        id_ex_rs = 5'd1;
        id_ex_rt = 5'd2;
        ex_mem_rd = 5'd3;
        mem_wb_rd = 5'd4;
        #10;
        if(forwardA != 2'b00 || forwardB !=2'b00) 
        begin
            $display("case 1: forwardA=%b forwardB=%b (expect 00 00)", forwardA, forwardB);
            errors = errors + 1;
        end
        // EX hazard on op A 
        id_ex_rs = 5'd5;
        id_ex_rt = 5'd6;
        ex_mem_rd = id_ex_rs;
        ex_mem_reg_write = 1'b1;
        #10;
        if(forwardA !=2'b10 || forwardB != 2'b00)
        begin
            $display("case 2: forrwardA=%b forwardB=%b (expect 10 00)", forwardA, forwardB);
            errors = errors + 1;
        end  
        // MEM hazard on op B
        id_ex_rt = 5'd8;
        ex_mem_reg_write = 1'b0; 
        ex_mem_rd = 5'd0;
        mem_wb_reg_write = 1'b1;
        mem_wb_rd = 5'd8;
        #10;
        if(forwardA !=2'b00 || forwardB != 2'b01)
        begin
            $display("case 3: forrwardA=%b forwardB=%b (expect 00 01)", forwardA, forwardB);
            errors = errors + 1;
        end  
        // Double write hazard
        id_ex_rs = 5'd10;
        id_ex_rt = 5'd11;
        mem_wb_rd = 5'd10;
        mem_wb_reg_write = 1'd1;
        ex_mem_reg_write = 1'd1;
        ex_mem_rd = 5'd10;
        #10;
        if(forwardA !=2'b10 || forwardB != 2'b00)
        begin
            $display("case 4: forrwardA=%b forwardB=%b (expect 10 00)", forwardA, forwardB);
            errors = errors + 1;
        end 
        // case 5 R0 exclusion tested via the EX/MEM path 
        id_ex_rs = 5'd0;
        id_ex_rt = 5'd11;
        mem_wb_rd = 5'd10;
        mem_wb_reg_write = 1'd1;
        ex_mem_reg_write = 1'd1;
        ex_mem_rd = 5'd0;
        #10;
        if(forwardA != 2'b00 || forwardB != 2'b00)
        begin
            $display("case 5: forrwardA=%b forwardB=%b (expect 00 00)", forwardA, forwardB);
            errors = errors + 1;
        end 
        // case 6: RegWrite=0 gate tested in isolation.
        id_ex_rs = 5'd3;
        id_ex_rt = 5'd2;
        ex_mem_rd = 5'd3;          // matches rs
        ex_mem_reg_write = 1'b0;   // but NOT writing
        mem_wb_rd = 5'd9;          // unrelated, avoid MEM/WB interfering
        mem_wb_reg_write = 1'b0;
        #10;
        if(forwardA != 2'b00 || forwardB != 2'b00)
        begin
            $display("case 6: forwardA=%b forwardB=%b (expect 00 00, RegWrite=0 gate)", forwardA, forwardB);
            errors = errors + 1;
        end
        // case 7: R0 exclusion tested via the MEM/WB path 
        id_ex_rs = 5'd0;
        id_ex_rt = 5'd11;
        ex_mem_rd = 5'd9;          // unrelated, keep EX/MEM out of it
        ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0;          // R0 again, this time via MEM/WB
        mem_wb_reg_write = 1'b1;
        #10;
        if(forwardA != 2'b00)
        begin
            $display("case 7: forwardA=%b (expect 00, R0 excluded via MEM/WB)", forwardA);
            errors = errors + 1;
        end
        // case 8: priority rule on operand B (double write hazard
        id_ex_rs = 5'd1;
        id_ex_rt = 5'd12;
        ex_mem_rd = 5'd12;         // matches rt
        ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd12;         // also matches rt, should be overridden
        mem_wb_reg_write = 1'b1;
        #10;
        if(forwardA != 2'b00 || forwardB != 2'b10)
        begin
            $display("case 8: forwardA=%b forwardB=%b (expect 00 10, priority on rt)", forwardA, forwardB);
            errors = errors + 1;
        end
        // case 9: simultaneous, independent hazards on A and B from
        id_ex_rs = 5'd4;
        id_ex_rt = 5'd6;
        ex_mem_rd = 5'd4;          // feeds operand A
        ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd6;          // feeds operand B
        mem_wb_reg_write = 1'b1;
        #10;
        if(forwardA != 2'b10 || forwardB != 2'b01)
        begin
            $display("case 9: forwardA=%b forwardB=%b (expect 10 01, independent simultaneous hazards)", forwardA, forwardB);
            errors = errors + 1;
        end
        // case 10: rs == rt (same register needed for both operands)
        id_ex_rs = 5'd7;
        id_ex_rt = 5'd7;
        ex_mem_rd = 5'd7;
        ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd2;
        mem_wb_reg_write = 1'b1;
        #10;
        if(forwardA != 2'b10 || forwardB != 2'b10)
        begin
            $display("case 10: forwardA=%b forwardB=%b (expect 10 10, rs==rt both forwarded)", forwardA, forwardB);
            errors = errors + 1;
        end
        // checker 
        #10;
        if(errors == 0)
        begin
            $display("=== ALL TESTS PASSED SUCCESSFULLY ===");
        end
        else begin
            $display("=== SIMULATION FAILED WITH %d ERRORS ===", errors);
        end        
    end
endmodule
