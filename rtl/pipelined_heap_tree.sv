//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

module pipelined_heap_tree
#(
    // Number of elements in the heap
    // (Optimal number is 2^n - 1)
    parameter ITEMS = 31
    // Timestamp width
   ,parameter TS_WIDTH = 32
    // Metadata width
   ,parameter META_WIDTH = 16
) (
    // Clocking
    input  logic clk
   ,input  logic rst

    // Input from user
    // Operation is accepted in cycle where in_ready is 1
    // When the heap is not empty (out_front_vld == 1) INSERT and REPLACE operation
    // may only use timestamp within (inclusive) range
    // <out_front_timestamp, out_front_timestamp + 2**(TS_WIDTH-1) - 1>
   ,input  logic [TS_WIDTH-1:0]   in_timestamp
   ,input  logic [META_WIDTH-1:0] in_meta
   ,input  heap_op_t              in_op
   ,output logic                  in_ready

    // Output to user
   ,output logic [TS_WIDTH-1:0]   out_front_timestamp
   ,output logic [META_WIDTH-1:0] out_front_meta
   ,output logic                  out_front_vld
);

localparam STAGES_NUM = $clog2(ITEMS+1);
localparam GLOBAL_PTR_WIDTH = $clog2(ITEMS+1);

localparam MEM_WIDTH = TS_WIDTH + META_WIDTH;

genvar I;

logic [GLOBAL_PTR_WIDTH+1-1:0]       next_insert_items_cnt_reg;
logic [$clog2(GLOBAL_PTR_WIDTH)-1:0] ptr_shift_reg;
logic [GLOBAL_PTR_WIDTH-1:0]         next_insert_items_cnt_reg_shift;
logic [GLOBAL_PTR_WIDTH-1:0]         next_insert_items_cnt_reg_shift_invld_mask;
logic [GLOBAL_PTR_WIDTH-1:0]         next_insert_items_cnt_reg_shift_masked;

logic [TS_WIDTH-1:0]   in_timestamp_reg;
logic [META_WIDTH-1:0] in_meta_reg;
heap_op_t              in_op_reg;
logic                  in_op_vld_reg;

localparam MAX_STAGE_ITEMS = getStageItems(STAGES_NUM+3); // +3 for reserve on signals width
localparam MAX_PARALLEL_MEMS = getParallelMems(MAX_STAGE_ITEMS);
localparam MAX_MEM_SIZE = getMemSize(MAX_STAGE_ITEMS, MAX_PARALLEL_MEMS);
localparam MAX_MEM_ADDR_WIDTH = getMemAddrWidth(MAX_MEM_SIZE);

logic         [STAGES_NUM-1:0][MAX_MEM_ADDR_WIDTH-1:0]                up_up_mem_addr;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0][TS_WIDTH-1:0]   up_mem_timestamp;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0][META_WIDTH-1:0] up_mem_meta;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0]                 up_mem_vld;
logic         [STAGES_NUM-1:0][MAX_MEM_ADDR_WIDTH-1:0]                up_mem_addr;
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          up_op_mem_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        up_op_mem_meta;
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          up_op_in_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        up_op_in_meta;
logic         [STAGES_NUM-1:0][GLOBAL_PTR_WIDTH-1:0]                  up_op_ptr;
heap_op_t                                                             up_op_code[STAGES_NUM-1:0];
logic         [STAGES_NUM-1:0][MAX_MEM_ADDR_WIDTH-1:0]                down_mem_addr;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0][TS_WIDTH-1:0]   down_mem_timestamp;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0][META_WIDTH-1:0] down_mem_meta;
logic         [STAGES_NUM-1:0][MAX_PARALLEL_MEMS-1:0]                 down_mem_vld;
logic         [STAGES_NUM-1:0][MAX_MEM_ADDR_WIDTH-1:0]                down_down_mem_addr;
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          down_op_mem_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        down_op_mem_meta;
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          down_op_in_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        down_op_in_meta;
logic         [STAGES_NUM-1:0][GLOBAL_PTR_WIDTH-1:0]                  down_op_ptr;
heap_op_t                                                             down_op_code[STAGES_NUM-1:0];
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          up_last_insert_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        up_last_insert_meta;
logic         [STAGES_NUM-1:0]                                        up_last_insert_in_mem;
logic         [STAGES_NUM-1:0]                                        up_last_insert_vld;
logic         [STAGES_NUM-1:0]                                        up_last_insert_take;
logic         [STAGES_NUM-1:0][TS_WIDTH-1:0]                          down_last_insert_timestamp;
logic         [STAGES_NUM-1:0][META_WIDTH-1:0]                        down_last_insert_meta;
logic         [STAGES_NUM-1:0]                                        down_last_insert_in_mem;
logic         [STAGES_NUM-1:0]                                        down_last_insert_vld;
logic         [STAGES_NUM-1:0]                                        down_last_insert_take;

logic [TS_WIDTH-1:0]   last_insert_timestamp_reg;
logic [META_WIDTH-1:0] last_insert_meta_reg;

// Input register
always_ff @(posedge clk) begin
    in_timestamp_reg <= in_timestamp;
    in_meta_reg      <= in_meta;
    in_op_reg        <= in_op;
    in_op_vld_reg    <= in_ready;

    if (rst) begin
        in_op_reg     <= NONE;
        in_op_vld_reg <= 0;
    end
end

// Input preprocessing
always_ff @(posedge clk) begin
    if (in_op_vld_reg) begin
        if (in_op_reg == INSERT) begin
            next_insert_items_cnt_reg <= next_insert_items_cnt_reg + 1;
            if (next_insert_items_cnt_reg_shift_masked == '1) begin
                ptr_shift_reg <= ptr_shift_reg + 1;
            end
        end else if (in_op_reg == DELETE) begin
            next_insert_items_cnt_reg <= next_insert_items_cnt_reg - 1;
            if (next_insert_items_cnt_reg_shift == '0) begin
                ptr_shift_reg <= ptr_shift_reg - 1;
            end
        end
    end

    if (rst) begin
        next_insert_items_cnt_reg    <= '0;
        next_insert_items_cnt_reg[0] <= '1;
        ptr_shift_reg <= '0;
    end
end

always_comb begin
    // The pointer of next inserted item is determined by the total number of items in the heap after the insert
    // However, it needs to be shifted based on the position of the highest 1 bit in the value
    // Example for heap with 7 items and 2-bit pointer:
    // ------------------|----------------|--------------------
    //   number of items | insert pointer |  number of ignored 
    //    after insert   |                | LSB bits of pointer
    // ------------------|----------------|--------------------
    //                 1 |       00       | 2
    //                 2 |       00       | 1
    //                 3 |       10       | 1
    //                 4 |       00       | 0
    //                 5 |       01       | 0
    //                 6 |       10       | 0
    //                 7 |       11       | 0
    next_insert_items_cnt_reg_shift            = (next_insert_items_cnt_reg[GLOBAL_PTR_WIDTH-1:0] << (GLOBAL_PTR_WIDTH-ptr_shift_reg));
    next_insert_items_cnt_reg_shift_invld_mask = ({GLOBAL_PTR_WIDTH{1'b1}} >> ptr_shift_reg);
    next_insert_items_cnt_reg_shift_masked     = (next_insert_items_cnt_reg_shift | next_insert_items_cnt_reg_shift_invld_mask);
end

always_comb begin
    up_up_mem_addr     [0] = '0;
    up_mem_addr        [0] = '0;
    up_op_in_timestamp [0] = in_timestamp_reg;
    up_op_in_meta      [0] = in_meta_reg;
    up_op_ptr          [0] = next_insert_items_cnt_reg_shift;
    up_op_code         [0] = in_op_reg;
    up_last_insert_take[0] = 0;
    in_ready = 1;

    if (in_op_vld_reg && in_op_reg == DELETE) begin
        // On DELETE operation, take last inserted item and put it on input as REPLACE
        up_last_insert_take[0] = 1;
        up_op_in_timestamp [0] = up_last_insert_timestamp[0];
        up_op_in_meta      [0] = up_last_insert_meta[0];
        up_op_code         [0] = REPLACE;
        if (up_last_insert_in_mem[0]) begin
            // If last inserted item was taken from memory, insert 1 cycle delay to read next last inserted item
            in_ready = 0;
        end
    end

    if (!in_op_vld_reg) begin
        // On empty cycle after DELETE, insert REPLACE operation performing the DELETE
        up_last_insert_take[0] = 0;
        up_op_in_timestamp [0] = last_insert_timestamp_reg;
        up_op_in_meta      [0] = last_insert_meta_reg;
        up_op_code         [0] = REPLACE;
    end

    out_front_timestamp = up_mem_timestamp[0][0];
    out_front_meta      = up_mem_meta     [0][0];
    out_front_vld       = up_mem_vld      [0][0];
end

always_ff @(posedge clk) begin
    up_op_mem_timestamp[0] <= up_mem_timestamp[0][0];
    up_op_mem_meta     [0] <= up_mem_meta     [0][0];
end

always_ff @(posedge clk) begin
    last_insert_timestamp_reg <= up_last_insert_timestamp[0];
    last_insert_meta_reg      <= up_last_insert_meta     [0];
end

// Stages
generate
    for (I=0; I<STAGES_NUM; I++) begin : stage_gen

        localparam STAGE_ITEMS = getStageItems(I);
        localparam PARALLEL_MEMS = getParallelMems(STAGE_ITEMS);
        localparam MEM_SIZE = getMemSize(STAGE_ITEMS, PARALLEL_MEMS);
        localparam MEM_ADDR_WIDTH = getMemAddrWidth(MEM_SIZE);

        localparam NEXT_STAGE_ITEMS = getStageItems(I+1);
        localparam NEXT_PARALLEL_MEMS = getParallelMems(NEXT_STAGE_ITEMS);
        localparam NEXT_MEM_SIZE = getMemSize(NEXT_STAGE_ITEMS, NEXT_PARALLEL_MEMS);
        localparam NEXT_MEM_ADDR_WIDTH = getMemAddrWidth(NEXT_MEM_SIZE);

        localparam NEXT_NEXT_MEM_ADDR_WIDTH = NEXT_MEM_ADDR_WIDTH + 1;

        heap_stage #(
            .STAGE               (I               )
           ,.GLOBAL_PTR_WIDTH    (GLOBAL_PTR_WIDTH)
           ,.TS_WIDTH            (TS_WIDTH        )
           ,.META_WIDTH          (META_WIDTH      )
        ) stage_inst (
            .clk                        (clk)
           ,.rst                        (rst)
           ,.up_up_mem_addr             (up_up_mem_addr            [I][MEM_ADDR_WIDTH-1:0])
           ,.up_mem_timestamp           (up_mem_timestamp          [I][PARALLEL_MEMS-1:0])
           ,.up_mem_meta                (up_mem_meta               [I][PARALLEL_MEMS-1:0])
           ,.up_mem_vld                 (up_mem_vld                [I][PARALLEL_MEMS-1:0])
           ,.up_mem_addr                (up_mem_addr               [I][NEXT_MEM_ADDR_WIDTH-1:0])
           ,.up_op_mem_timestamp        (up_op_mem_timestamp       [I])
           ,.up_op_mem_meta             (up_op_mem_meta            [I])
           ,.up_op_in_timestamp         (up_op_in_timestamp        [I])
           ,.up_op_in_meta              (up_op_in_meta             [I])
           ,.up_op_ptr                  (up_op_ptr                 [I])
           ,.up_op_code                 (up_op_code                [I])
           ,.down_mem_addr              (down_mem_addr             [I][NEXT_MEM_ADDR_WIDTH-1:0])
           ,.down_mem_timestamp         (down_mem_timestamp        [I][NEXT_PARALLEL_MEMS-1:0])
           ,.down_mem_meta              (down_mem_meta             [I][NEXT_PARALLEL_MEMS-1:0])
           ,.down_mem_vld               (down_mem_vld              [I][NEXT_PARALLEL_MEMS-1:0])
           ,.down_down_mem_addr         (down_down_mem_addr        [I][NEXT_NEXT_MEM_ADDR_WIDTH-1:0])
           ,.down_op_mem_timestamp      (down_op_mem_timestamp     [I])
           ,.down_op_mem_meta           (down_op_mem_meta          [I])
           ,.down_op_in_timestamp       (down_op_in_timestamp      [I])
           ,.down_op_in_meta            (down_op_in_meta           [I])
           ,.down_op_ptr                (down_op_ptr               [I])
           ,.down_op_code               (down_op_code              [I])
           ,.up_last_insert_timestamp   (up_last_insert_timestamp  [I])
           ,.up_last_insert_meta        (up_last_insert_meta       [I])
           ,.up_last_insert_in_mem      (up_last_insert_in_mem     [I])
           ,.up_last_insert_vld         (up_last_insert_vld        [I])
           ,.up_last_insert_take        (up_last_insert_take       [I])
           ,.down_last_insert_timestamp (down_last_insert_timestamp[I])
           ,.down_last_insert_meta      (down_last_insert_meta     [I])
           ,.down_last_insert_in_mem    (down_last_insert_in_mem   [I])
           ,.down_last_insert_vld       (down_last_insert_vld      [I])
           ,.down_last_insert_take      (down_last_insert_take     [I])
        );

        if (I > 0) begin
            always_comb begin
                up_up_mem_addr          [I] = down_mem_addr           [I-1][MEM_ADDR_WIDTH-1:0];
                up_mem_addr             [I] = down_down_mem_addr      [I-1][NEXT_MEM_ADDR_WIDTH-1:0];
                up_op_mem_timestamp     [I] = down_op_mem_timestamp   [I-1];
                up_op_mem_meta          [I] = down_op_mem_meta        [I-1];
                up_op_in_timestamp      [I] = down_op_in_timestamp    [I-1];
                up_op_in_meta           [I] = down_op_in_meta         [I-1];
                up_op_ptr               [I] = down_op_ptr             [I-1];
                up_op_code              [I] = down_op_code            [I-1];
                up_last_insert_take     [I] = down_last_insert_take   [I-1];
            end
        end

        if (I < STAGES_NUM-1) begin
            always_comb begin
                down_mem_timestamp        [I] = up_mem_timestamp        [I+1][NEXT_PARALLEL_MEMS-1:0];
                down_mem_meta             [I] = up_mem_meta             [I+1][NEXT_PARALLEL_MEMS-1:0];
                down_mem_vld              [I] = up_mem_vld              [I+1][NEXT_PARALLEL_MEMS-1:0];
                down_last_insert_timestamp[I] = up_last_insert_timestamp[I+1];
                down_last_insert_meta     [I] = up_last_insert_meta     [I+1];
                down_last_insert_in_mem   [I] = up_last_insert_in_mem   [I+1];
                down_last_insert_vld      [I] = up_last_insert_vld      [I+1];
            end
        end

    end
endgenerate

// Last stage trimming
always_comb begin
    down_mem_vld           [STAGES_NUM-1] = '0;
    down_last_insert_in_mem[STAGES_NUM-1] = '0;
    down_last_insert_vld   [STAGES_NUM-1] = '0;
end

endmodule
