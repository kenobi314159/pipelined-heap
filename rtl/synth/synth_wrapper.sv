//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

////////////////////////////////////////////////////////////////
// Wrapper with registers for all input and output ports to
// enable timing analysis on them.
////////////////////////////////////////////////////////////////
module synth_wrapper
#(
    // Variant of the pipelined heap implementation
    // 0 - linear
    // 1 - tree
    parameter IMPLEMENTATION = 0
   ,parameter ITEMS = 31
   ,parameter TS_WIDTH = 32
   ,parameter META_WIDTH = 16
) (
    input  logic clk
   ,input  logic rst
   ,input  logic [TS_WIDTH-1:0]   in_timestamp
   ,input  logic [META_WIDTH-1:0] in_meta
   ,input  heap_op_t              in_op
   ,output logic                  in_ready
   ,output logic [TS_WIDTH-1:0]   out_front_timestamp
   ,output logic [META_WIDTH-1:0] out_front_meta
   ,output logic                  out_front_vld
);

logic [TS_WIDTH-1:0]   in_timestamp_reg;
logic [META_WIDTH-1:0] in_meta_reg;
heap_op_t              in_op_reg;
logic                  in_ready_reg;
logic [TS_WIDTH-1:0]   out_front_timestamp_reg;
logic [META_WIDTH-1:0] out_front_meta_reg;
logic                  out_front_vld_reg;

initial begin
    if (IMPLEMENTATION < 0 || IMPLEMENTATION > 1)
        $fatal("Invalid IMPLEMENTATION parameter: %d. Expected value between 0 and 1.", IMPLEMENTATION);
end

always_ff @(posedge clk) begin
    in_timestamp_reg    <= in_timestamp;
    in_meta_reg         <= in_meta;
    in_op_reg           <= in_op;
    in_ready            <= in_ready_reg;
    out_front_timestamp <= out_front_timestamp_reg;
    out_front_meta      <= out_front_meta_reg;
    out_front_vld       <= out_front_vld_reg;
end

// Select the appropriate implementation based on the IMPLEMENTATION parameter
generate
if (IMPLEMENTATION == 0) begin : gen_pipelined_heap_linear

    pipelined_heap_linear
    #(
        .ITEMS      (ITEMS     )
       ,.TS_WIDTH   (TS_WIDTH  )
       ,.META_WIDTH (META_WIDTH)
    ) inst (
        .clk                 (clk)
       ,.rst                 (rst)
       ,.in_timestamp        (in_timestamp_reg       )
       ,.in_meta             (in_meta_reg            )
       ,.in_op               (in_op_reg              )
       ,.out_front_timestamp (out_front_timestamp_reg)
       ,.out_front_meta      (out_front_meta_reg     )
       ,.out_front_vld       (out_front_vld_reg      )
    );

    assign in_ready_reg = 1;

end else if (IMPLEMENTATION == 1) begin : gen_pipelined_heap_tree

    pipelined_heap_tree
    #(
        .ITEMS      (ITEMS     )
       ,.TS_WIDTH   (TS_WIDTH  )
       ,.META_WIDTH (META_WIDTH)
    ) inst (
        .clk                 (clk)
       ,.rst                 (rst)
       ,.in_timestamp        (in_timestamp_reg       )
       ,.in_meta             (in_meta_reg            )
       ,.in_op               (in_op_reg              )
       ,.in_ready            (in_ready_reg           )
       ,.out_front_timestamp (out_front_timestamp_reg)
       ,.out_front_meta      (out_front_meta_reg     )
       ,.out_front_vld       (out_front_vld_reg      )
    );

end
endgenerate

endmodule
