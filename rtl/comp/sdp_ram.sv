//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

// Simple Dual Port memory
// Write latency: 1 clock cycle
// Read latency: 1 clock cycle
// Write-read bypass (if write and read address are the same, read data will be the same as written data)
module sdp_ram
#(
    // Number of words in the memory
    parameter SIZE = 1024
    // Number of bits in one word
   ,parameter WIDTH = 32

    // The following parameters are not to be changed
    // They are supposed to be localparams, but that is not supported in Quartus Lite

    // Address width
   ,parameter ADDR_WIDTH = $clog2(SIZE)
) (
    // Clocking
    input  logic clk

    // Input
   ,input  logic [WIDTH-1:0]      w_data
   ,input  logic [ADDR_WIDTH-1:0] w_addr
   ,input  logic                  w_en

    // Output
   ,output logic [WIDTH-1:0]      r_data
   ,input  logic [ADDR_WIDTH-1:0] r_addr
);

logic [WIDTH-1:0] mem [0:SIZE-1];
logic [ADDR_WIDTH-1:0] w_addr_fixed;
logic [ADDR_WIDTH-1:0] r_addr_fixed;
logic [WIDTH-1:0]      w_data_reg;
logic [WIDTH-1:0]      r_data_reg;
logic                  addr_eq;

// Address fix
assign w_addr_fixed = (ADDR_WIDTH > 0) ? w_addr : 0;
assign r_addr_fixed = (ADDR_WIDTH > 0) ? r_addr : 0;

// Write
always_ff @(posedge clk) begin
    if (w_en) begin
        mem[w_addr_fixed] <= w_data;
    end
end

// Read
always_ff @(posedge clk) begin
    r_data_reg <= mem[r_addr_fixed];
end

// Write-read bypass
always_ff @(posedge clk) begin
    w_data_reg <= w_data;
    addr_eq    <= (w_addr_fixed == r_addr_fixed && w_en);
end

assign r_data = (addr_eq) ? w_data_reg : r_data_reg;

endmodule
