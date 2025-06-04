//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

// Single stage of the heap
module heap_stage_linear
#(
    // Timestamp width
    parameter TS_WIDTH = 0
    // Metadata width
   ,parameter META_WIDTH = 0
) (
    // Clocking
    input  clk
   ,input  rst

    // Input operation from stage above
   ,input  logic [TS_WIDTH-1:0]                           up_op_timestamp
   ,input  logic [META_WIDTH-1:0]                         up_op_meta
   ,input  heap_op_t                                      up_op_code

    // Output operation to stage below
   ,output logic [TS_WIDTH-1:0]                           down_op_timestamp
   ,output logic [META_WIDTH-1:0]                         down_op_meta
   ,output heap_op_t                                      down_op_code

    // Info about current value propagated to stage above
   ,output logic [TS_WIDTH-1:0]                           up_timestamp
   ,output logic [META_WIDTH-1:0]                         up_meta
   ,output logic                                          up_vld

    // Info about current value propagated from stage below
   ,input  logic [TS_WIDTH-1:0]                           down_timestamp
   ,input  logic [META_WIDTH-1:0]                         down_meta
   ,input  logic                                          down_vld
);

localparam REGS = 2;

logic [REGS-1:0][TS_WIDTH-1:0]     reg_timestamp;
logic [REGS-1:0][META_WIDTH-1:0]   reg_meta;
logic [REGS-1:0]                   reg_vld;

logic [REGS-1:0][TS_WIDTH-1:0]     next_timestamp;
logic [REGS-1:0][META_WIDTH-1:0]   next_meta;
logic [REGS-1:0]                   next_vld;

logic [REGS-1:0][TS_WIDTH-1:0]     ts_in_reg_diff;
logic [REGS-1:0]                   ts_in_le_reg;

logic [TS_WIDTH-1:0]     ts_in_down_diff;
logic                    ts_in_le_down;

logic [TS_WIDTH-1:0]     next_down_op_timestamp;
logic [META_WIDTH-1:0]   next_down_op_meta;
heap_op_t                next_down_op_code;

////////////////////////////////
// Value register

always_ff @(posedge clk) begin
    reg_timestamp <= next_timestamp;
    reg_meta      <= next_meta;
    reg_vld       <= next_vld;

    if (rst) begin
        reg_vld <= '{default:1'b0};
    end
end

////////////////////////////////

////////////////////////////////
// Up propagation

always_comb begin
    up_timestamp = next_timestamp[0];
    up_meta      = next_meta     [0];
    up_vld       = next_vld      [0];
end

////////////////////////////////

////////////////////////////////
// Timestamp comparison

always_comb begin
    for (int i=0; i<REGS; i++) begin
        ts_in_reg_diff[i] = up_op_timestamp - reg_timestamp[i];
        ts_in_le_reg  [i] = ts_in_reg_diff[i][TS_WIDTH-1] || !reg_vld[i];
    end

    ts_in_down_diff = up_op_timestamp - down_timestamp;
    ts_in_le_down   = ts_in_down_diff[TS_WIDTH-1] || !down_vld;
end

////////////////////////////////

////////////////////////////////
// Values update

always_comb begin
    next_timestamp = reg_timestamp;
    next_meta      = reg_meta;
    next_vld       = reg_vld;

    next_down_op_timestamp = reg_timestamp;
    next_down_op_meta      = reg_meta;
    next_down_op_code      = NONE;

    if (up_op_code == INSERT) begin
        if (ts_in_le_reg[0]) begin
            next_timestamp[0] = up_op_timestamp;
            next_meta     [0] = up_op_meta;
            next_vld      [0] = 1'b1;

            next_timestamp[1] = reg_timestamp[0];
            next_meta     [1] = reg_meta[0];
            next_vld      [1] = reg_vld[0];

            next_down_op_timestamp = reg_timestamp[1];
            next_down_op_meta      = reg_meta[1];
            next_down_op_code      = (reg_vld[1]) ? INSERT : NONE;
        end else if (ts_in_le_reg[1]) begin
            next_timestamp[1] = up_op_timestamp;
            next_meta     [1] = up_op_meta;
            next_vld      [1] = 1'b1;

            next_down_op_timestamp = reg_timestamp[1];
            next_down_op_meta      = reg_meta[1];
            next_down_op_code      = (reg_vld[1]) ? INSERT : NONE;
        end else begin
            next_down_op_timestamp = up_op_timestamp;
            next_down_op_meta      = up_op_meta;
            next_down_op_code      = INSERT;
        end
    end else if (up_op_code == REPLACE) begin
        if (ts_in_le_reg[1]) begin
            next_timestamp[0] = up_op_timestamp;
            next_meta     [0] = up_op_meta;
            next_vld      [0] = 1'b1;
        end else if (ts_in_le_down) begin
            next_timestamp[0] = reg_timestamp[1];
            next_meta     [0] = reg_meta     [1];
            next_vld      [0] = reg_vld      [1];

            next_timestamp[1] = up_op_timestamp;
            next_meta     [1] = up_op_meta;
            next_vld      [1] = 1'b1;
        end else begin
            next_timestamp[0] = reg_timestamp[1];
            next_meta     [0] = reg_meta     [1];
            next_vld      [0] = reg_vld      [1];

            next_timestamp[1] = down_timestamp;
            next_meta     [1] = down_meta;
            next_vld      [1] = down_vld;

            next_down_op_timestamp = up_op_timestamp;
            next_down_op_meta      = up_op_meta;
            next_down_op_code      = REPLACE;
        end
    end else if (up_op_code == DELETE) begin
        next_timestamp[0] = reg_timestamp[1];
        next_meta     [0] = reg_meta     [1];
        next_vld      [0] = reg_vld      [1];

        next_timestamp[1] = down_timestamp;
        next_meta     [1] = down_meta;
        next_vld      [1] = down_vld;

        next_down_op_code = DELETE;
    end
end

////////////////////////////////

////////////////////////////////
// Output register

always_ff @(posedge clk) begin
    down_op_timestamp <= next_down_op_timestamp;
    down_op_meta      <= next_down_op_meta;
    down_op_code      <= next_down_op_code;

    if (rst) begin
        down_op_code <= NONE;
    end
end

////////////////////////////////

endmodule
