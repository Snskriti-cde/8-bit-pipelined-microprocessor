module data_memory #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter MEM_DEPTH  = 256
)(
    input  wire                     clk,
    input  wire                     rst,

    // Control signals
    input  wire                     memRead,
    input  wire                     memWrite,

    // Address and data ports
    input  wire [ADDR_WIDTH-1:0]    address,
    input  wire [DATA_WIDTH-1:0]    writeData,
    output reg  [DATA_WIDTH-1:0]    readData
);

    // ----------------------------------------------------
    // Memory Array
    // ----------------------------------------------------
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];

    integer i;

    // ----------------------------------------------------
    // Optional Memory Initialization
    // Uncomment if using external memory file
    // ----------------------------------------------------
    initial begin
        // $readmemh("data_mem.hex", memory);

        // Initialize memory to zero
        for(i = 0; i < MEM_DEPTH; i = i + 1)
            memory[i] = {DATA_WIDTH{1'b0}};
    end

    // ----------------------------------------------------
    // Synchronous Write
    // ----------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for(i = 0; i < MEM_DEPTH; i = i + 1)
                memory[i] <= {DATA_WIDTH{1'b0}};
        end
        else if (memWrite) begin
            memory[address] <= writeData;
        end
    end

    // ----------------------------------------------------
    // Asynchronous Read
    // ----------------------------------------------------
    always @(*) begin
        if (memRead)
            readData = memory[address];
        else
            readData = {DATA_WIDTH{1'b0}};
    end

endmodule