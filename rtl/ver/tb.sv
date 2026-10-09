//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

module tb;

// DUT parameters
localparam IMPLEMENTATION = "linear"; // "tree", "linear"
localparam ITEMS = 111;
localparam TS_WIDTH = 12;
localparam META_WIDTH = 4;

// Test parameters
localparam MIN_DIRECTION_INTERVAL_LENGTH = ITEMS*4;
localparam MAX_DIRECTION_INTERVAL_LENGTH = ITEMS*10;
localparam TEST_OPERATIONS = MAX_DIRECTION_INTERVAL_LENGTH*10;

logic clk;
logic rst;

logic [TS_WIDTH-1:0]   in_timestamp;
logic [META_WIDTH-1:0] in_meta;
heap_op_t              in_op;
logic                  in_ready;

logic [TS_WIDTH-1:0]   out_front_timestamp;
logic [META_WIDTH-1:0] out_front_meta;
logic                  out_front_vld;

logic [2-1:0][TS_WIDTH-1:0]   in_next_timestamp;
logic [2-1:0][META_WIDTH-1:0] in_next_meta;
logic [2-1:0]                 in_next_vld;

logic [TS_WIDTH-1:0]   out_next_timestamp;
logic [META_WIDTH-1:0] out_next_meta;
logic [1-1:0]          out_next_idx;
heap_op_t              out_next_op;

logic [ITEMS-1:0][1+META_WIDTH+TS_WIDTH-1:0] model_heap;
logic                  model_heap_front_vld;
logic [TS_WIDTH-1:0]   model_heap_front_ts;
logic [META_WIDTH-1:0] model_heap_front_meta;

logic insert_eq;

// 1 - more inserts than deletes
// 0 - more deletes than inserts
logic op_direction_reg;

function void model_heap_insert(
    input logic [TS_WIDTH-1:0] timestamp,
    input logic [META_WIDTH-1:0] meta
    );
    logic [1+TS_WIDTH+META_WIDTH-1:0] entry;
    logic                current_vld;
    logic [TS_WIDTH-1:0] current_timestamp;
    logic [TS_WIDTH-1:0] timestamp_diff;
    if (META_WIDTH > 0) begin
        entry = {1'b1, meta, timestamp};
    end else begin
        entry = {1'b1, timestamp};
    end
    for (int i=0; i<ITEMS; i++) begin
        current_vld = model_heap[i][TS_WIDTH+META_WIDTH];
        current_timestamp = model_heap[i][TS_WIDTH-1:0];
        timestamp_diff = timestamp - current_timestamp;
        if (timestamp_diff[TS_WIDTH-1] == 1 || current_vld == 0) begin
            for (int e=ITEMS-1; e>=i+1; e--) begin
                model_heap[e] = model_heap[e-1];
            end
            model_heap[i] = entry;
            break;
        end
    end
endfunction

function void model_heap_delete();
    for (int i=0; i<ITEMS-1; i++) begin
        model_heap[i] = model_heap[i+1];
    end
    model_heap[ITEMS-1] = {1+TS_WIDTH+META_WIDTH{1'b0}};
endfunction

function void model_heap_replace(
    input logic [TS_WIDTH-1:0] timestamp,
    input logic [META_WIDTH-1:0] meta
    );
    model_heap_delete();
    model_heap_insert(timestamp, meta);
endfunction

// When there is multiple items with the same timestamp, the model might order them differently than the DUT.
// This is expected behavior, but we need this function to detect and correct the situation to avoid false failures.
function int model_heap_find_equal_and_swap(
    input logic [META_WIDTH-1:0] meta
    );
    logic [TS_WIDTH-1:0]   timestamp;
    logic                  current_vld;
    logic [TS_WIDTH-1:0]   current_timestamp;
    logic [META_WIDTH-1:0] current_meta;
    logic [1+TS_WIDTH+META_WIDTH-1:0] tmp;
    current_meta = 0;
    timestamp = model_heap[0][TS_WIDTH-1:0];
    for (int i=1; i<ITEMS; i++) begin
        current_vld       = model_heap[i][TS_WIDTH+META_WIDTH];
        if (META_WIDTH > 0) begin
            current_meta = model_heap[i][TS_WIDTH+META_WIDTH-1:TS_WIDTH];
        end else begin
            current_meta = meta;
        end
        current_timestamp = model_heap[i][TS_WIDTH-1:0];
        if (!current_vld || current_timestamp != timestamp) begin
            return 0;
        end
        if (current_timestamp == timestamp && current_meta == meta) begin
            tmp = model_heap[i];
            model_heap[i] = model_heap[0];
            model_heap[0] = tmp;
            return 1;
        end
    end
    return 0;
endfunction

assign model_heap_front_vld  = model_heap[0][TS_WIDTH+META_WIDTH];
if (META_WIDTH > 0) begin
    assign model_heap_front_meta = model_heap[0][TS_WIDTH+META_WIDTH-1:TS_WIDTH];
end
assign model_heap_front_ts   = model_heap[0][TS_WIDTH-1:0];

function void set_input(
    input logic [TS_WIDTH-1:0]   timestamp,
    input logic [META_WIDTH-1:0] meta,
    input heap_op_t              op
    );
    in_timestamp = timestamp;
    in_meta      = meta;
    in_op        = op;
endfunction

// DUT instantiation
generate
if (IMPLEMENTATION == "linear") begin : gen_pipelined_heap_linear

    pipelined_heap_linear
    #(
        .ITEMS      (ITEMS     )
       ,.TS_WIDTH   (TS_WIDTH  )
       ,.META_WIDTH (META_WIDTH)
    ) dut_i (
        .clk                 (clk                )
       ,.rst                 (rst                )
       ,.in_timestamp        (in_timestamp       )
       ,.in_meta             (in_meta            )
       ,.in_op               (in_op              )
       ,.out_front_timestamp (out_front_timestamp)
       ,.out_front_meta      (out_front_meta     )
       ,.out_front_vld       (out_front_vld      )
    );

    assign in_ready = 1;

end else if (IMPLEMENTATION == "tree") begin : gen_pipelined_heap_tree

    pipelined_heap_tree
    #(
        .ITEMS      (ITEMS     )
       ,.TS_WIDTH   (TS_WIDTH  )
       ,.META_WIDTH (META_WIDTH)
    ) dut_i (
        .clk                 (clk                )
       ,.rst                 (rst                )
       ,.in_timestamp        (in_timestamp       )
       ,.in_meta             (in_meta            )
       ,.in_op               (in_op              )
       ,.in_ready            (in_ready           )
       ,.out_front_timestamp (out_front_timestamp)
       ,.out_front_meta      (out_front_meta     )
       ,.out_front_vld       (out_front_vld      )
    );

end
endgenerate

// Clock generation
initial begin
    clk = 1;
    for (int i=0; i<TEST_OPERATIONS*4; i++) begin
        #50;
        clk = ~clk;
    end
end

// Initial reset generation
initial begin
    rst = 1;
    #500;
    rst = 0;
end

// Test behavior switching
initial begin
    var int interval_length;
    op_direction_reg = 1;
    while (1) begin
        interval_length = $urandom_range(MIN_DIRECTION_INTERVAL_LENGTH, MAX_DIRECTION_INTERVAL_LENGTH);
        for (int i=0; i<interval_length; i++)
            @(posedge clk);
        op_direction_reg = ~op_direction_reg;
    end
end

// Main test process
initial begin
    var int r;
    var logic [TS_WIDTH-1:0] ts;
    var heap_op_t op;
    logic var_model_heap_front_vld;
    logic var_model_heap_bottom_vld;

    // Init

    in_timestamp = 0;
    in_meta      = 0;
    in_op        = NONE;

    in_next_timestamp[0] = 0;
    in_next_timestamp[1] = 0;
    in_next_meta[0]      = 0;
    in_next_meta[1]      = 0;
    in_next_vld[0]       = 0;
    in_next_vld[1]       = 0;

    ////////

    set_input(0, 0, NONE);
    for (int i=0; i<10; i++)
        @(posedge clk);

    // Random tests

    for (int i=0; i<TEST_OPERATIONS; i++) begin
        while (in_ready == 0)
            @(posedge clk);

        ts = model_heap[0][TS_WIDTH-1:0] + $urandom_range(0, $pow(2, TS_WIDTH-1)-1);
        var_model_heap_front_vld  = model_heap[0][TS_WIDTH+META_WIDTH];
        var_model_heap_bottom_vld = model_heap[ITEMS-1][TS_WIDTH+META_WIDTH];
        if (var_model_heap_front_vld && var_model_heap_bottom_vld) begin
            r = $urandom_range(0, 2);
            if (r == 0) begin
                op = DELETE;
            end else if (r == 1) begin
                op = REPLACE;
            end else begin
                op = NONE;
            end
        end else if (var_model_heap_front_vld) begin
            if (op_direction_reg == 0) begin
                // Lowered chance of INSERT
                r = $urandom_range(0, 6);
                if (r >= 0 && r <= 1) begin
                    op = DELETE;
                end else if (r == 2) begin
                    op = INSERT;
                end else if (r >= 3 && r <= 4) begin
                    op = REPLACE;
                end else begin
                    op = NONE;
                end
            end else begin
                // Lowered chance of DELETE
                r = $urandom_range(0, 6);
                if (r == 0) begin
                    op = DELETE;
                end else if (r >= 1 && r <= 2) begin
                    op = INSERT;
                end else if (r >= 3 && r <= 4) begin
                    op = REPLACE;
                end else begin
                    op = NONE;
                end
            end
        end else begin
            ts = $urandom_range(0, 255);
            r = $urandom_range(0, 1);
            if (r == 0) begin
                op = INSERT;
            end else begin
                op = NONE;
            end
        end
        set_input(ts, $urandom_range(0, 255), op);
        @(posedge clk);
    end

    ////////

    set_input(0, 0, NONE);
    for (int i=0; i<10; i++)
        @(posedge clk);

end

// Check DUT output
always_ff @(posedge clk) begin
    if (!rst && in_ready) begin
        assert(out_front_vld == model_heap_front_vld) else $fatal("Valid mismatch: expected %0d, got %0d", model_heap_front_vld, out_front_vld);
        if (out_front_vld) begin
            assert(out_front_timestamp == model_heap_front_ts) else $fatal("Timestamp mismatch: expected %0d, got %0d", model_heap_front_ts, out_front_timestamp);
            if (out_front_meta != model_heap_front_meta) begin
                assert(model_heap_find_equal_and_swap(out_front_meta)) else $fatal("Meta mismatch: expected %0d, got %0d", model_heap_front_meta, out_front_meta);
            end
        end
    end
end

assign insert_eq = (in_op == INSERT) && (out_front_vld && out_front_timestamp == in_timestamp);

// Update golden model
always_ff @(posedge clk) begin
    if (in_ready) begin
        case (in_op)
            INSERT: begin
                model_heap_insert(in_timestamp, in_meta);
            end
            DELETE: begin
                model_heap_delete();
            end
            REPLACE: begin
                model_heap_replace(in_timestamp, in_meta);
            end
        endcase
    end

    if (rst) begin
        model_heap = '{default: {TS_WIDTH+META_WIDTH{1'b0}}};
    end
end

endmodule
