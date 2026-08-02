module register_file #(
    parameter data_width = 8,
    parameter num_regs   = 32
    )
    (
    input              clk,
    input              reset,        
    input              reg_write,   
    input      [4:0]   read_reg_1,   // rs field, instr[25:21]
    input      [4:0]   read_reg_2,   // rt field, instr[20:16]
    input      [4:0]   write_reg,    // destination addr (rd or rt, after RegDst mux)
    input      [data_width - 1:0]   write_data,  
    output     [data_width - 1:0]   read_data_1,  // port A operand
    output     [data_width - 1:0]   read_data_2   // port B operand
);

      // -------------------------------------------------------------------------
    reg [data_width - 1:0] regs [0:num_regs - 1];
    integer   i;

    // Asynchronous read
    assign read_data_1 = (read_reg_1 == 5'd0) ? {data_width{1'b0}} : regs[read_reg_1];
    assign read_data_2 = (read_reg_2 == 5'd0) ? {data_width{1'b0}} : regs[read_reg_2];

    // Synchronous write
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < num_regs; i = i + 1)
                regs[i] <= {data_width{1'b0}};
	    regs[29] <= 8'hFF; // sp, 255 (stack will grow downwards)
        end
        else if (reg_write && (write_reg != 5'd0)) begin
            regs[write_reg] <= write_data;
        end
	// reset block
    end

endmodule
