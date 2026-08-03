module register_file #(
    parameter DATA_WIDTH = 8,
    parameter NUM_REGS   = 32
)(
    input                         clk,
    input                         reset,        
    input                         reg_write,  
    input      [4:0]              read_reg_1,   // rs field
    input      [4:0]              read_reg_2,   // rt field
    input      [4:0]              write_reg,   
    input      [DATA_WIDTH-1:0]   write_data,   
    output     [DATA_WIDTH-1:0]   read_data_1,  // port A operand
    output     [DATA_WIDTH-1:0]   read_data_2   // port B operand
);
//-------------------------------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    integer i;

    
    wire wr_active = reg_write && (write_reg != 5'd0);

    assign read_data_1 = (read_reg_1 == 5'd0)                      ? {DATA_WIDTH{1'b0}} :
                         (wr_active && (write_reg == read_reg_1))  ? write_data          :
                                                                     regs[read_reg_1];

    assign read_data_2 = (read_reg_2 == 5'd0)                      ? {DATA_WIDTH{1'b0}} :
                         (wr_active && (write_reg == read_reg_2))  ? write_data          :
                                                                     regs[read_reg_2];

    // Synchronous write ========================================================
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {DATA_WIDTH{1'b0}};
        end
        else if (wr_active) begin
            regs[write_reg] <= write_data;
        end
		// reset block
    end

endmodule
