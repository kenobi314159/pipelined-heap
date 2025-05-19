//-------------------------------------------------------------------------------
// AUTHORS: Jan Kubalek <kubalekj492@gmail.com>
// LICENSE: The MIT License, please read LICENSE file
//-------------------------------------------------------------------------------

package pipelined_heap_pkg;

    // Type for a heap operation
    typedef enum {
        INSERT,
        DELETE,
        REPLACE,
        NONE
    } heap_op_t;

    // Maximum number of parallel items needed to be read from memory
    localparam MAX_PRL_ITEMS = 4;
    // Parallel items index width
    localparam IDX_WIDTH = $clog2(MAX_PRL_ITEMS);

    // Functions for stage local params calculation
    function int getStageItems(int stage);
        return 1 << stage;
    endfunction

    function int getParallelMems(int stage_items);
       if (stage_items < MAX_PRL_ITEMS)
           return stage_items;
       return MAX_PRL_ITEMS;
    endfunction

    function int getMemSize(int stage_items, int parallel_mems);
       return stage_items / parallel_mems;
    endfunction

    function int getMemAddrWidth(int mem_size);
       if (mem_size == 1) begin
           return 1;
       end
       return $clog2(mem_size);
    endfunction

endpackage
