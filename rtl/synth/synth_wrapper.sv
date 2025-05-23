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
    parameter ITEMS = 31
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

always_ff @(posedge clk) begin
    in_timestamp_reg    <= in_timestamp;
    in_meta_reg         <= in_meta;
    in_op_reg           <= in_op;
    in_ready            <= in_ready_reg;
    out_front_timestamp <= out_front_timestamp_reg;
    out_front_meta      <= out_front_meta_reg;
    out_front_vld       <= out_front_vld_reg;
end

pipelined_heap
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

endmodule
