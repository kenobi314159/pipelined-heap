//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

// An array of SDP RAMs
module ram_array
#(
    // Number of memories in the array
    parameter MEMS = 1
    // Number of words in each memory
   ,parameter SIZE = 1024
    // Number of bits in one word of each memory
   ,parameter WIDTH = 32

    // The following parameters are not to be changed
    // They are supposed to be localparams, but that is not supported in Quartus Lite

    // Address width
   ,parameter ADDR_WIDTH = $clog2(SIZE)
) (
    // Clocking
    input  logic clk

    // Input
   ,input  logic [MEMS-1:0][WIDTH-1:0]      w_data
   ,input  logic           [ADDR_WIDTH-1:0] w_addr
   ,input  logic [MEMS-1:0]                 w_en

    // Output
   ,output logic [MEMS-1:0][WIDTH-1:0]      r_data
   ,input  logic           [ADDR_WIDTH-1:0] r_addr
);

genvar i;

generate
    for (i = 0; i < MEMS; i++) begin : ram_array_gen
        sdp_ram #(
            .SIZE    (SIZE)
           ,.WIDTH   (WIDTH)
        ) ram_inst (
            .clk     (clk      )
           ,.w_data  (w_data[i])
           ,.w_addr  (w_addr   )
           ,.w_en    (w_en  [i])
           ,.r_data  (r_data[i])
           ,.r_addr  (r_addr   )
        );
    end
endgenerate

endmodule
