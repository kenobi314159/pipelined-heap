//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

import pipelined_heap_pkg::*;

// Single stage of the heap
module heap_stage
#(
    // Stage level in the heap
    parameter STAGE = 0
    // Width of global item pointer in heap
   ,parameter GLOBAL_PTR_WIDTH = 0

    // Timestamp width
   ,parameter TS_WIDTH = 0
    // Metadata width
   ,parameter META_WIDTH = 0

    // The following parameters are not to be changed
    // They are supposed to be localparams, but that is not supported in Quartus Lite

   ,parameter MEM_WIDTH = TS_WIDTH + META_WIDTH

   ,parameter STAGE_ITEMS = getStageItems(STAGE)
   ,parameter PARALLEL_MEMS = getParallelMems(STAGE_ITEMS)
   ,parameter MEM_SIZE = getMemSize(STAGE_ITEMS, PARALLEL_MEMS)
   ,parameter MEM_ADDR_WIDTH = getMemAddrWidth(MEM_SIZE)

   ,parameter NEXT_STAGE = STAGE+1
   ,parameter NEXT_STAGE_ITEMS = getStageItems(NEXT_STAGE)
   ,parameter NEXT_PARALLEL_MEMS = getParallelMems(NEXT_STAGE_ITEMS)
   ,parameter NEXT_MEM_SIZE = getMemSize(NEXT_STAGE_ITEMS, NEXT_PARALLEL_MEMS)
   ,parameter NEXT_MEM_ADDR_WIDTH = getMemAddrWidth(NEXT_MEM_SIZE)

   ,parameter NEXT_NEXT_MEM_ADDR_WIDTH = NEXT_MEM_ADDR_WIDTH + 1
) (
    // Clocking
    input  clk
   ,input  rst

    // Memory read from two stages above
   ,input  logic [MEM_ADDR_WIDTH-1:0]                     up_up_mem_addr
   ,output logic [PARALLEL_MEMS-1:0][TS_WIDTH-1:0]        up_mem_timestamp
   ,output logic [PARALLEL_MEMS-1:0][META_WIDTH-1:0]      up_mem_meta
   ,output logic [PARALLEL_MEMS-1:0]                      up_mem_vld

    // Memory read from stage above
   ,input  logic [NEXT_MEM_ADDR_WIDTH-1:0]                up_mem_addr

    // Input operation from stage above
   ,input  logic [TS_WIDTH-1:0]                           up_op_mem_timestamp
   ,input  logic [META_WIDTH-1:0]                         up_op_mem_meta
   ,input  logic [TS_WIDTH-1:0]                           up_op_in_timestamp
   ,input  logic [META_WIDTH-1:0]                         up_op_in_meta
   ,input  logic [GLOBAL_PTR_WIDTH-1:0]                   up_op_ptr
   ,input  heap_op_t                                      up_op_code

    // Memory read to stage below
   ,output logic [NEXT_MEM_ADDR_WIDTH-1:0]                down_mem_addr
   ,input  logic [NEXT_PARALLEL_MEMS-1:0][TS_WIDTH-1:0]   down_mem_timestamp
   ,input  logic [NEXT_PARALLEL_MEMS-1:0][META_WIDTH-1:0] down_mem_meta
   ,input  logic [NEXT_PARALLEL_MEMS-1:0]                 down_mem_vld

    // Memory read to two stages below
   ,output logic [NEXT_NEXT_MEM_ADDR_WIDTH-1:0]           down_down_mem_addr

    // Output operation to stage below
   ,output logic [TS_WIDTH-1:0]                           down_op_mem_timestamp
   ,output logic [META_WIDTH-1:0]                         down_op_mem_meta
   ,output logic [TS_WIDTH-1:0]                           down_op_in_timestamp
   ,output logic [META_WIDTH-1:0]                         down_op_in_meta
   ,output logic [GLOBAL_PTR_WIDTH-1:0]                   down_op_ptr
   ,output heap_op_t                                      down_op_code

    // Info about last inserted item to stage above
   ,output logic [TS_WIDTH-1:0]                           up_last_insert_timestamp
   ,output logic [META_WIDTH-1:0]                         up_last_insert_meta
   ,output logic                                          up_last_insert_in_mem
   ,output logic                                          up_last_insert_vld
   ,input  logic                                          up_last_insert_take

    // Info about last inserted item from stage below
   ,input  logic [TS_WIDTH-1:0]                           down_last_insert_timestamp
   ,input  logic [META_WIDTH-1:0]                         down_last_insert_meta
   ,input  logic                                          down_last_insert_in_mem
   ,input  logic                                          down_last_insert_vld
   ,output logic                                          down_last_insert_take
);

localparam LOCAL_PTR_WIDTH = $clog2(STAGE_ITEMS);

localparam META_WIDTH_MIN1 = (META_WIDTH > 0) ? META_WIDTH : 1;

logic                    [MEM_ADDR_WIDTH-1:0] mem_w_addr;
logic [PARALLEL_MEMS-1:0][MEM_WIDTH-1:0]      mem_w_data;
logic [PARALLEL_MEMS-1:0]                     mem_w_en;
logic                    [MEM_ADDR_WIDTH-1:0] mem_r_addr;
logic [PARALLEL_MEMS-1:0][MEM_WIDTH-1:0]      mem_r_data;

logic                                         mem_w_new_insert;
logic                                         mem_w_replace_last;
logic                    [MEM_ADDR_WIDTH-1:0] mem_r_addr_reg;

logic [PARALLEL_MEMS-1:0][TS_WIDTH-1:0]       mem_w_data_ts;
logic [PARALLEL_MEMS-1:0][META_WIDTH-1:0]     mem_w_data_meta;
logic [PARALLEL_MEMS-1:0][TS_WIDTH-1:0]       mem_r_data_ts;
logic [PARALLEL_MEMS-1:0][META_WIDTH-1:0]     mem_r_data_meta;

logic [PARALLEL_MEMS-1:0][TS_WIDTH-1:0]       up_mem_timestamp_reg;
logic [PARALLEL_MEMS-1:0][META_WIDTH-1:0]     up_mem_meta_reg;
logic [PARALLEL_MEMS-1:0]                     up_mem_vld_reg;

logic                    [TS_WIDTH-1:0]       mem_w_data_single_ts;
logic                    [META_WIDTH-1:0]     mem_w_data_single_meta;

localparam [LOCAL_PTR_WIDTH+1-1:0] full_fill_value = '{LOCAL_PTR_WIDTH:'0, default:'1};

logic [LOCAL_PTR_WIDTH+1-1:0] fill_cntr_reg;
logic [LOCAL_PTR_WIDTH+1-1:0] fill_cntr_reg_next;
logic [MEM_ADDR_WIDTH-1:0]    last_vld_item_ptr_addr;
logic [IDX_WIDTH-1:0]         last_vld_item_ptr_idx;
logic [MEM_ADDR_WIDTH-1:0]    last_vld_item_ptr_next_addr;
logic [IDX_WIDTH-1:0]         last_vld_item_ptr_next_idx;
logic                         stage_empty_next;
logic                         stage_full_next;
logic                         stage_empty;
logic                         stage_full;

logic [MEM_ADDR_WIDTH-1:0]    up_op_addr;
logic [IDX_WIDTH-1:0]         up_op_idx;
logic [LOCAL_PTR_WIDTH-1:0]   up_op_addr_idx;
logic                         up_op_next_idx_high;
logic                         up_op_next_idx_low;

logic [2-1:0][TS_WIDTH-1:0]   selected_down_mem_timestamp;
logic [2-1:0][META_WIDTH-1:0] selected_down_mem_meta;
logic [2-1:0]                 selected_down_mem_vld;

logic [TS_WIDTH-1:0]   ts_in_mem_diff;
logic [TS_WIDTH-1:0]   ts_in_child0_diff;
logic [TS_WIDTH-1:0]   ts_in_child1_diff;
logic [TS_WIDTH-1:0]   ts_child0_child1_diff;

logic                  ts_in_le_mem;
logic                  ts_in_le_child0;
logic                  ts_in_le_child1;
logic                  ts_child0_le_child1;

logic                  inserting_in_this_stage;
logic                  not_replacing_child0;
logic                  not_replacing_child1;
logic                  replacing_child0_over_child1;

logic [TS_WIDTH-1:0]   last_vld_item_timestamp;
logic [META_WIDTH-1:0] last_vld_item_meta;
logic [TS_WIDTH-1:0]   last_vld_item_timestamp_reg;
logic [META_WIDTH-1:0] last_vld_item_meta_reg;

logic                  up_last_insert_take_from_mem;
logic                  up_last_insert_take_from_mem_reg;

////////////////////////////////
// Input preprocessing

always_comb begin
    if (LOCAL_PTR_WIDTH > IDX_WIDTH) begin
        up_op_addr_idx = up_op_ptr[$bits(up_op_ptr)-1-:LOCAL_PTR_WIDTH];
        {up_op_addr, up_op_idx} = up_op_addr_idx;
    end else begin
        up_op_addr = '0;
        if (LOCAL_PTR_WIDTH > 0) begin
            up_op_idx = up_op_ptr[$bits(up_op_ptr)-1-:LOCAL_PTR_WIDTH];
        end else begin
            up_op_idx = '0;
        end
        up_op_addr_idx = {up_op_addr, up_op_idx};
    end
    up_op_next_idx_high = up_op_idx[0];
    up_op_next_idx_low  = up_op_ptr[GLOBAL_PTR_WIDTH-LOCAL_PTR_WIDTH-1];

    // Choose the relevant pair of children from the pre-fetched values from below
    selected_down_mem_timestamp = down_mem_timestamp[2-1:0];
    selected_down_mem_meta      = down_mem_meta     [2-1:0];
    selected_down_mem_vld       = down_mem_vld      [2-1:0];
    if (NEXT_PARALLEL_MEMS > 2) begin
        if (up_op_next_idx_high == 1) begin
            selected_down_mem_timestamp = down_mem_timestamp[4-1:2];
            selected_down_mem_meta      = down_mem_meta     [4-1:2];
            selected_down_mem_vld       = down_mem_vld      [4-1:2];
        end
    end
end

////////////////////////////////

////////////////////////////////
// Stage memory

ram_array #(
    .MEMS   (PARALLEL_MEMS)
   ,.SIZE   (MEM_SIZE     )
   ,.WIDTH  (MEM_WIDTH    )
) stage_mem_inst (
    .clk    (clk)
   ,.w_addr (mem_w_addr)
   ,.w_data (mem_w_data)
   ,.w_en   (mem_w_en  )
   ,.r_addr (mem_r_addr)
   ,.r_data (mem_r_data)
);

always_comb begin
    for (int i=0; i < PARALLEL_MEMS; i++) begin
        mem_w_data_ts  [i] = mem_w_data_single_ts;
        mem_w_data_meta[i] = mem_w_data_single_meta;
        mem_w_data[i] = {mem_w_data_meta[i], mem_w_data_ts[i]};
        mem_r_data_ts  [i] = mem_r_data[i][TS_WIDTH-1:0];
        mem_r_data_meta[i] = mem_r_data[i][MEM_WIDTH-1:MEM_WIDTH-META_WIDTH_MIN1];
    end
end

////////////////////////////////

////////////////////////////////
// Stage fill counter (number of valid in memory)

always_ff @(posedge clk) begin
    fill_cntr_reg <= fill_cntr_reg_next;
    stage_empty   <= stage_empty_next;
    stage_full    <= stage_full_next;

    if (rst) begin
        fill_cntr_reg <= '1;
        stage_empty   <= '1;
        stage_full    <= '0;
    end
end

always_comb begin
    fill_cntr_reg_next = fill_cntr_reg;
    if (up_op_code == INSERT && !stage_full && !up_last_insert_take) begin
        fill_cntr_reg_next = fill_cntr_reg_next + 1;
    end else if (up_op_code != INSERT && up_last_insert_take && !down_last_insert_vld) begin
        fill_cntr_reg_next = fill_cntr_reg_next - 1;
    end
end

always_comb begin
    stage_empty_next = (fill_cntr_reg_next[$bits(fill_cntr_reg_next)-1] == 1);
    stage_full_next  = (fill_cntr_reg_next == full_fill_value);
end

// Parse different parts of the counter into memory address and parallel items index
generate
    if (LOCAL_PTR_WIDTH > IDX_WIDTH) begin
        always_comb begin
            last_vld_item_ptr_addr      = fill_cntr_reg     [LOCAL_PTR_WIDTH-1:IDX_WIDTH];
            last_vld_item_ptr_idx       = fill_cntr_reg     [IDX_WIDTH-1:0];
            last_vld_item_ptr_next_addr = fill_cntr_reg_next[LOCAL_PTR_WIDTH-1:IDX_WIDTH];
            last_vld_item_ptr_next_idx  = fill_cntr_reg_next[IDX_WIDTH-1:0];
        end
    end else begin
        always_comb begin
            last_vld_item_ptr_addr      = '0;
            last_vld_item_ptr_next_addr = '0;
            if (LOCAL_PTR_WIDTH > 0) begin
                last_vld_item_ptr_idx      = fill_cntr_reg     [LOCAL_PTR_WIDTH-1:0];
                last_vld_item_ptr_next_idx = fill_cntr_reg_next[LOCAL_PTR_WIDTH-1:0];
            end else begin
                last_vld_item_ptr_idx      = '0;
                last_vld_item_ptr_next_idx = '0;
            end
        end
    end
endgenerate

////////////////////////////////

////////////////////////////////
// Memory access control

always_comb begin
    // Memory read from two stages above
    // (Data will be passed to one stage above in up_mem_ iface)
    mem_r_addr = up_up_mem_addr;
    up_mem_timestamp = mem_r_data_ts;
    up_mem_meta      = mem_r_data_meta;
    // Bypass to currently written value if it is being written to the same address
    if (mem_w_addr == mem_r_addr_reg) begin
        for (int i=0; i < PARALLEL_MEMS; i++) begin
            if (mem_w_en[i]) begin
                up_mem_timestamp[i] = mem_w_data_ts  [i];
                up_mem_meta     [i] = mem_w_data_meta[i];
            end
        end
    end
    // Bypass to next written value if it will be written to the same address
    if (up_op_addr == mem_r_addr_reg) begin
        if (up_op_code == INSERT) begin
            if (   inserting_in_this_stage
                && !up_last_insert_take
               ) begin
                up_mem_timestamp[up_op_idx] = up_op_in_timestamp;
                up_mem_meta     [up_op_idx] = up_op_in_meta;
            end
        end
        if (up_op_code == REPLACE) begin
            if (   not_replacing_child0
                && not_replacing_child1
               ) begin
                up_mem_timestamp[up_op_idx] = up_op_in_timestamp;
                up_mem_meta     [up_op_idx] = up_op_in_meta;
            end else if (
                   replacing_child0_over_child1
               ) begin
                up_mem_timestamp[up_op_idx] = selected_down_mem_timestamp[0];
                up_mem_meta     [up_op_idx] = selected_down_mem_meta     [0];
            end else begin
                up_mem_timestamp[up_op_idx] = selected_down_mem_timestamp[1];
                up_mem_meta     [up_op_idx] = selected_down_mem_meta     [1];
            end
        end
    end

    // Valid generated based on the last valid item pointer
    up_mem_vld = '0;
    if (   !stage_empty_next
       ) begin
        if (last_vld_item_ptr_next_addr == mem_r_addr_reg) begin
            for (int i=0; i < PARALLEL_MEMS; i++) begin
                up_mem_vld[i] = (i <= last_vld_item_ptr_next_idx);
            end
        end else if (last_vld_item_ptr_next_addr > mem_r_addr_reg) begin
            up_mem_vld = '1;
        end else begin
            up_mem_vld = '0;
        end
    end

    // If last valid item was being updated from memory, prevent all changes in the output values
    if (up_last_insert_take_from_mem_reg) begin
        up_mem_timestamp = up_mem_timestamp_reg;
        up_mem_meta      = up_mem_meta_reg;
        up_mem_vld       = up_mem_vld_reg;
    end

    // Override memory read when last valid item info needs to be updated
    if (up_last_insert_take_from_mem) begin
        mem_r_addr = last_vld_item_ptr_next_addr;
    end

    // Memory read from one stage above
    // (Data will be passed to this stage in down_mem_ iface)
    down_mem_addr = up_mem_addr;

    // Memory read to two stages below
    // (Decided based on actual operation addr and index)
    down_down_mem_addr = up_op_addr_idx;
end

always_ff @(posedge clk) begin
    mem_r_addr_reg       <= up_up_mem_addr;
    up_mem_timestamp_reg <= up_mem_timestamp;
    up_mem_meta_reg      <= up_mem_meta;
    up_mem_vld_reg       <= up_mem_vld;
end

////////////////////////////////

////////////////////////////////
// Comparing timestamp values

always_comb begin
    ts_in_mem_diff        = up_op_in_timestamp - up_op_mem_timestamp;
    ts_in_child0_diff     = up_op_in_timestamp - selected_down_mem_timestamp[0];
    ts_in_child1_diff     = up_op_in_timestamp - selected_down_mem_timestamp[1];
    ts_child0_child1_diff = selected_down_mem_timestamp[0] - selected_down_mem_timestamp[1];

    ts_in_le_mem        = ts_in_mem_diff       [TS_WIDTH-1];
    ts_in_le_child0     = ts_in_child0_diff    [TS_WIDTH-1];
    ts_in_le_child1     = ts_in_child1_diff    [TS_WIDTH-1];
    ts_child0_le_child1 = ts_child0_child1_diff[TS_WIDTH-1];

    inserting_in_this_stage      = (ts_in_le_mem || !stage_full);
    not_replacing_child0         = (ts_in_le_child0 || !selected_down_mem_vld[0]);
    not_replacing_child1         = (ts_in_le_child1 || !selected_down_mem_vld[1]);
    replacing_child0_over_child1 = (ts_child0_le_child1 || !selected_down_mem_vld[1]);
end

////////////////////////////////

////////////////////////////////
// Performing operation

always_ff @(posedge clk) begin
    down_op_mem_timestamp  <= selected_down_mem_timestamp[0];
    down_op_mem_meta       <= selected_down_mem_meta     [0];
    down_op_in_timestamp   <= up_op_in_timestamp;
    down_op_in_meta        <= up_op_in_meta;
    down_op_ptr            <= up_op_ptr;
    down_op_code           <= NONE;
    mem_w_addr             <= up_op_addr;
    mem_w_data_single_ts   <= up_op_mem_timestamp;
    mem_w_data_single_meta <= up_op_mem_meta;
    mem_w_en               <= '0;
    mem_w_new_insert       <= 0;
    mem_w_replace_last     <= 0;

    if (up_op_code == REPLACE) begin
        if (   not_replacing_child0
            && not_replacing_child1
           ) begin
            // Replace current memory value with operation value
            mem_w_data_single_ts   <= up_op_in_timestamp;
            mem_w_data_single_meta <= up_op_in_meta;
            mem_w_en[up_op_idx]    <= 1;
            mem_w_replace_last     <= (up_op_addr == last_vld_item_ptr_next_addr && up_op_idx == last_vld_item_ptr_next_idx);
        end else if (
               replacing_child0_over_child1
           ) begin
            // Replace current memory value with child 0
            // and propagate operation to child 0
            mem_w_data_single_ts   <= selected_down_mem_timestamp[0];
            mem_w_data_single_meta <= selected_down_mem_meta     [0];
            mem_w_en[up_op_idx]    <= 1;

            down_op_mem_timestamp  <= selected_down_mem_timestamp[0];
            down_op_mem_meta       <= selected_down_mem_meta     [0];
            down_op_in_timestamp   <= up_op_in_timestamp;
            down_op_in_meta        <= up_op_in_meta;
            down_op_ptr            <= up_op_ptr;
            down_op_code           <= REPLACE;
            down_op_ptr[GLOBAL_PTR_WIDTH-LOCAL_PTR_WIDTH-1] <= 0;
        end else begin
            // Replace current memory value with child 1
            // and propagate operation to child 1
            mem_w_data_single_ts   <= selected_down_mem_timestamp[1];
            mem_w_data_single_meta <= selected_down_mem_meta     [1];
            mem_w_en[up_op_idx]    <= 1;

            down_op_mem_timestamp  <= selected_down_mem_timestamp[1];
            down_op_mem_meta       <= selected_down_mem_meta     [1];
            down_op_in_timestamp   <= up_op_in_timestamp;
            down_op_in_meta        <= up_op_in_meta;
            down_op_ptr            <= up_op_ptr;
            down_op_code           <= REPLACE;
            down_op_ptr[GLOBAL_PTR_WIDTH-LOCAL_PTR_WIDTH-1] <= 1;
        end
    end else if (up_op_code == INSERT) begin
        if (   !up_last_insert_take) begin
            if (   inserting_in_this_stage
               ) begin
                // Insert operation value instead of current memory value
                // and propagate insert if this stage is already full
                mem_w_data_single_ts   <= up_op_in_timestamp;
                mem_w_data_single_meta <= up_op_in_meta;
                mem_w_en[up_op_idx]    <= 1;
                mem_w_new_insert       <= !stage_full;

                down_op_mem_timestamp  <= selected_down_mem_timestamp[up_op_next_idx_low];
                down_op_mem_meta       <= selected_down_mem_meta     [up_op_next_idx_low];
                down_op_in_timestamp   <= up_op_mem_timestamp;
                down_op_in_meta        <= up_op_mem_meta;
                down_op_ptr            <= up_op_ptr;
                down_op_code           <= (stage_full) ? INSERT : NONE;
            end else begin
                // Propagate insert with the same value
                down_op_mem_timestamp  <= selected_down_mem_timestamp[up_op_next_idx_low];
                down_op_mem_meta       <= selected_down_mem_meta     [up_op_next_idx_low];
                down_op_in_timestamp   <= up_op_in_timestamp;
                down_op_in_meta        <= up_op_in_meta;
                down_op_ptr            <= up_op_ptr;
                down_op_code           <= INSERT;
            end
        end
    end

    // If last valid item needs to be updated from memory, prevent all changes in the output registers
    if (up_last_insert_take && up_last_insert_in_mem) begin
        down_op_mem_timestamp <= down_op_mem_timestamp;
        down_op_mem_meta      <= down_op_mem_meta;
        down_op_in_timestamp  <= down_op_in_timestamp;
        down_op_in_meta       <= down_op_in_meta;
        down_op_ptr           <= down_op_ptr;
        down_op_code          <= down_op_code;
    end

    if (rst) begin
        mem_w_en     <= '0;
        down_op_code <= NONE;
    end
end

////////////////////////////////

////////////////////////////////
// Last inserted item propagation

always_comb begin
    up_last_insert_timestamp = down_last_insert_timestamp;
    up_last_insert_meta      = down_last_insert_meta;
    up_last_insert_in_mem    = down_last_insert_in_mem;
    up_last_insert_vld       = down_last_insert_vld;
    down_last_insert_take    = up_last_insert_take;

    // Stage below has no items
    if (down_last_insert_vld == 0) begin
        up_last_insert_timestamp = last_vld_item_timestamp;
        up_last_insert_meta      = last_vld_item_meta;
        up_last_insert_in_mem    = 1'b1;
        up_last_insert_vld       = !stage_empty;
        down_last_insert_take    = 1'b0;
    end

    // Last inserted item hasn't been processed yet
    if (up_op_code == INSERT) begin
        up_last_insert_in_mem = 1'b0;
    end

    // Last valid item is the one in current operation
    if (   up_op_code == INSERT
        || (   up_op_code == REPLACE
            && !down_last_insert_vld
            && (up_op_addr == last_vld_item_ptr_addr)
            && (up_op_idx  == last_vld_item_ptr_idx )
           )
       ) begin
        up_last_insert_timestamp = up_op_in_timestamp;
        up_last_insert_meta      = up_op_in_meta;
        up_last_insert_vld       = 1'b1;
        down_last_insert_take    = 1'b0;
    end
end

always_comb begin
    up_last_insert_take_from_mem = (up_last_insert_take && up_last_insert_in_mem);
end

always_comb begin
    last_vld_item_timestamp = last_vld_item_timestamp_reg;
    last_vld_item_meta      = last_vld_item_meta_reg;
    // Last valid item is being replaced or new one is being inserted
    if (   mem_w_replace_last
        || mem_w_new_insert
       ) begin
        last_vld_item_timestamp = mem_w_data_single_ts;
        last_vld_item_meta      = mem_w_data_single_meta;
    end
end

always_ff @(posedge clk) begin
    // Last valid item was taken, update to previous valid item
    if (up_last_insert_take_from_mem_reg) begin
        last_vld_item_timestamp_reg <= mem_r_data_ts  [last_vld_item_ptr_idx];
        last_vld_item_meta_reg      <= mem_r_data_meta[last_vld_item_ptr_idx];
    end
    // Last valid item is being replaced or new one is being inserted
    if (   mem_w_replace_last
        || mem_w_new_insert
       ) begin
        last_vld_item_timestamp_reg <= mem_w_data_single_ts;
        last_vld_item_meta_reg      <= mem_w_data_single_meta;
    end
    up_last_insert_take_from_mem_reg <= up_last_insert_take_from_mem;
end

////////////////////////////////

endmodule
