//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

module pipelined_heap_linear
#(
    // Number of elements in the heap
    // (Optimal number is 2*n)
    parameter ITEMS = 32
    // Timestamp width
   ,parameter TS_WIDTH = 32
    // Metadata width
   ,parameter META_WIDTH = 16
) (
    // Clocking
    input  logic clk
   ,input  logic rst

    // Input from user
    // When the heap is not empty (out_front_vld == 1) INSERT and REPLACE operation
    // may only use timestamp within (inclusive) range
    // <out_front_timestamp, out_front_timestamp + 2**(TS_WIDTH-1) - 1>
   ,input  logic [TS_WIDTH-1:0]   in_timestamp
   ,input  logic [META_WIDTH-1:0] in_meta
   ,input  heap_op_t              in_op

    // Output to user
   ,output logic [TS_WIDTH-1:0]   out_front_timestamp
   ,output logic [META_WIDTH-1:0] out_front_meta
   ,output logic                  out_front_vld
);

localparam STAGES = (ITEMS+1)/2;

genvar I;

logic [STAGES-1:0][TS_WIDTH-1:0]     up_op_timestamp;
logic [STAGES-1:0][META_WIDTH-1:0]   up_op_meta;
heap_op_t                            up_op_code[STAGES-1:0];
logic [STAGES-1:0][TS_WIDTH-1:0]     down_op_timestamp;
logic [STAGES-1:0][META_WIDTH-1:0]   down_op_meta;
heap_op_t                            down_op_code[STAGES-1:0];
logic [STAGES-1:0][TS_WIDTH-1:0]     up_timestamp;
logic [STAGES-1:0][META_WIDTH-1:0]   up_meta;
logic [STAGES-1:0]                   up_vld;
logic [STAGES-1:0][TS_WIDTH-1:0]     down_timestamp;
logic [STAGES-1:0][META_WIDTH-1:0]   down_meta;
logic [STAGES-1:0]                   down_vld;

// Output propagation
always_comb begin
    out_front_timestamp = up_timestamp[0];
    out_front_meta      = up_meta[0];
    out_front_vld       = up_vld[0];
end

// Input register
always_ff @(posedge clk) begin
    up_op_timestamp[0] <= in_timestamp;
    up_op_meta     [0] <= in_meta;
    up_op_code     [0] <= in_op;

    if (rst) begin
        up_op_code[0] <= NONE;
    end
end

// Stages
generate
    for (I=0; I<STAGES; I++) begin : stage_gen

        heap_stage_linear #(
            .TS_WIDTH          (TS_WIDTH  )
           ,.META_WIDTH        (META_WIDTH)
        ) stage_inst (
            .clk               (clk)
           ,.rst               (rst)
           ,.up_op_timestamp   (up_op_timestamp  [I])
           ,.up_op_meta        (up_op_meta       [I])
           ,.up_op_code        (up_op_code       [I])
           ,.down_op_timestamp (down_op_timestamp[I])
           ,.down_op_meta      (down_op_meta     [I])
           ,.down_op_code      (down_op_code     [I])
           ,.up_timestamp      (up_timestamp     [I])
           ,.up_meta           (up_meta          [I])
           ,.up_vld            (up_vld           [I])
           ,.down_timestamp    (down_timestamp   [I])
           ,.down_meta         (down_meta        [I])
           ,.down_vld          (down_vld         [I])
        );

        if (I > 0) begin
            always_comb begin
                up_op_timestamp[I] = down_op_timestamp[I-1];
                up_op_meta     [I] = down_op_meta     [I-1];
                up_op_code     [I] = down_op_code     [I-1];
            end
        end

        if (I < STAGES-1) begin
            always_comb begin
                down_timestamp[I] = up_timestamp[I+1];
                down_meta     [I] = up_meta     [I+1];
                down_vld      [I] = up_vld      [I+1];
            end
        end

    end
endgenerate

// Last stage trimming
always_comb begin
    down_timestamp[STAGES-1] = '0;
    down_meta     [STAGES-1] = '0;
    down_vld      [STAGES-1] = '0;
end

endmodule
