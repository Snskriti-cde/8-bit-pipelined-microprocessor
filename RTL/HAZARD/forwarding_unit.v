`timescale 1ns / 1ps
module forwarding_unit(

    input wire [4:0] id_ex_rs,
    input wire [4:0] id_ex_rt,
    
    input wire [4:0] ex_mem_rd,
    input wire ex_mem_reg_write,
   
    input wire [4:0] mem_wb_rd,
    input wire mem_wb_reg_write,
    
    // outputs to alu multiplexers 
    output reg [1:0] forwardA,
    output reg [1:0] forwardB
    );
    always @(*) begin
        // defaults
        forwardA = 2'b00;
        forwardB = 2'b00;
        
        // condition 1: ex hazard for op A
        if ((ex_mem_reg_write)&& (ex_mem_rd !=5'd0) && (id_ex_rs == ex_mem_rd))
        begin
            forwardA = 2'b10; // forward from EX/MEM
        end
        
        // condition 2: mem hazard for op A
        if ((mem_wb_reg_write) && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs) && !((ex_mem_reg_write)&& (ex_mem_rd !=5'd0) && (id_ex_rs == ex_mem_rd)))// priority rule)) 
        begin
            forwardA = 2'b01;
        end 
        
        // condition 1:ex hazard for op B
        if ((ex_mem_reg_write)&& (ex_mem_rd !=5'd0) && (id_ex_rt == ex_mem_rd))
        begin
            forwardB = 2'b10; // forward from EX/MEM
        end 
        
        // condition 2: mem hazard for op B 
        if ((mem_wb_reg_write) && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rt) && !((ex_mem_reg_write)&& (ex_mem_rd !=5'd0) && (id_ex_rt == ex_mem_rd)))// priority rule)) 
        begin
            forwardB = 2'b01;
        end    
    end    
    
endmodule
