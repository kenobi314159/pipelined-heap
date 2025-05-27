# Pipelined Heap

Pipelined Heap (Priority Queue) implementation for FPGA based on the following paper:

- Ioannou, A., & Katevenis, M. G. H. (2007).
  Pipelined HEAP (Priority Queue) management for advanced scheduling in High-Speed networks.
  IEEE/ACM Transactions on Networking, 15(2), 450–461. https://doi.org/10.1109/tnet.2007.892882

The module implements a heap of values.
Each cycle an operation INSERT, DELETE or REPLACE can be issued to the heap.
The lowest of the values based on operations in previous cycles is always presented at the front of the heap.
The purpose of this structure is to allow precise scheduling of events based on timestamps.
A common example from networking is scheduling of packets to egress based on their priority (e.g. QoS - Quality of Service).

## Directory structure

```
└─── rtl - RTL source code
    ├─── comp - Auxiliary RTL components
    ├─── ver - RTL verification
    └─── synth - Quartus synthesis project
```

## QoS example use case

Here is what a possible use case in QoS application could look like:

We have packets assigned to different priority classes based on their priority.
Each priority has it's own packet queue and it's own desired pace of packets (minimum time interval between packets sent to egress from this class).
The packet on the front of each packet queue thus has a timestamp assigned to it as to when it should be sent to egress.
The task is to find the minimum of these values each cycle (while also ignoring the empty queues) to select packet from.
When the number of queues and bit width of timestamps is very large, this becomes a problem in an FPGA, as the complexity of the minimum-finding operation grows with the number of queues.
The growth is "only" logarithmic when recursive reduction is used, but the number of comparissons is still very large which takes a toll on resource consumption and creates issues with routing on the FPGA.

The Pipelined Heap simplifies this problem by storing the timestamp values to a binary tree structure (heap), where the number of levels is logarithmic to the number of queues.
For worst case, only one value from each level needs to be compared with the others to find the minimum.
The design further reduces resource consumption by allowing lower levels of the tree (with larger number of timestamps) to be stored in block memories.

## Operations

The Pipelined Heap supports the following operations:
- **INSERT**: Insert a new value into the heap.
- **DELETE**: Remove the minimum value from the front of the heap.
- **REPLACE**: Replace the minimum value at the front of the heap with a new value.

In case of the QoS example, the usage would be:
1. Set size of the heap to the number of queues.
2. Use operation **INSERT** when a packet arrives for a queue which is empty.
3. Use operation **REPLACE** when sending packet to egress from a queue that has another packet waiting after.
4. Use operation **DELETE** when sending packet to egress from a queue that has no more packets waiting (last packet in the queue).

## Limitations

1. Only one operation each cycle is supported.
   This may be a limitation in the QoS use case, where **INSERT** is requested by the queue write side and **REPLACE** or **DELETE** are requested by the queue read side.
   Possible solution is to stall read-side operation for one cycle whenever an **INSERT** is requested.
   Since **INSERT** is only requested when inserting into a queue that is empty, the stall should be compensated by available buffer space in the queues.
2. The **DELETE** operation sometimes requires 2 cycles.
   Due to structural limitations in the design, the **DELETE** operations sometimes causes a stall of operation on the next cycle.
   Again, in case of the QoS example, this operation is only done when a queue becomes empty, which signifies free buffer space in the queues, which reduces negative impact of this limitation.

## Parameters and ports

| Parameter    | Description |
|--------------|-------------|
| ITEMS        | Maximum number of items in the pipe. Optimal values are 2**N-1 as this is the number of nodes in a complete binary tree with N levels. |
| TS_WIDTH     | Width of the timestamp value in bits. This is the width of the values stored in the heap. |
| META_WIDTH   | Width of the value metadata in bits. Metadata can be used to store additional user-defined information about each value (e.g. queue ID for QoS). |

| Port                   | Direction | Description |
|------------------------|-----------|-------------|
| clk                    | Input     | Clock signal. |
| rst                    | Input     | Active high reset signal. |
| in_timestamp           | Input     | Timestamp value to be inserted or replaced with. |
| in_meta                | Input     | Metadata value to be inserted or replaced with |
| in_op                  | Input     | Operation to be performed on the heap (INSERT, DELETE, REPLACE). |
| in_ready               | Output    | Indicates that the heap is ready to accept a new operation in this cycle. |
| out_front_timestamp    | Output    | Timestamp value at the front of the heap. This is the minimum of all the valid values in the heap. |
| out_front_meta         | Output    | Metadata value at the front of the heap. |
| out_front_vld          | Output    | Indicates that the front value is valid. This is true when there is at least one valid value in the heap. |

## Resource consumption and timing

The resource consumption and timing was measured using the Quartus Lite 23.1 synthesis tool on a Cyclone V FPGA.
The synthesis project including complete set of measured data is available in the `synth` directory [here](rtl/synth/results_20250526_no_mem_wr_regs.csv).

| ITEMS | TS_WIDTH | META_WIDTH |   LUTs   |   Regs   |   LABs   |   M9Ks   | Fmax [MHz] |
|-------|----------|------------|----------|----------|----------|----------|------------|
|     1 |        8 |          8 |      279 |      216 |       23 |        0 |     54.203 |
|     1 |       32 |         32 |      836 |      648 |       59 |        0 |     44.549 |
|     3 |        8 |          8 |      604 |      389 |       48 |        0 |     44.111 |
|     3 |       32 |         32 |     2055 |     1301 |      160 |        0 |     32.369 |
|     7 |        8 |          8 |     1182 |      666 |       88 |        0 |     33.899 |
|     7 |       32 |         32 |     4124 |     2346 |      346 |        0 |     28.655 |
|    15 |        8 |          8 |     1834 |     1008 |      140 |        0 |     28.171 |
|    15 |       32 |         32 |     6625 |     3648 |      567 |        0 |     23.279 |
|    31 |        8 |          8 |     2729 |     1485 |      200 |        0 |     25.552 |
|    31 |       32 |         32 |     9632 |     5469 |      841 |        0 |     21.476 |
|    63 |        8 |          8 |     3840 |     2220 |      283 |        0 |     22.287 |
|    63 |       32 |         32 |    13718 |     8316 |     1116 |        0 |     19.101 |
|   127 |        8 |          8 |     4353 |     2383 |      322 |        4 |     20.704 |
|   127 |       32 |         32 |    15524 |     8863 |     1207 |        8 |     16.021 |
|   255 |        8 |          8 |     4900 |     2550 |      355 |        8 |     18.914 |
|   255 |       32 |         32 |    17195 |     9414 |     1300 |       16 |     14.047 |
|   511 |        8 |          8 |     5465 |     2722 |      402 |       12 |     16.280 |
|   511 |       32 |         32 |    19074 |     9970 |     1380 |       24 |     12.285 |
|  1023 |        8 |          8 |     6033 |     2897 |      446 |       16 |     14.980 |
|  1023 |       32 |         32 |    20858 |    10529 |     1454 |       32 |     10.902 |
|  2047 |        8 |          8 |     6614 |     3076 |      488 |       20 |     13.068 |
|  2047 |       32 |         32 |    22387 |    11092 |     1468 |       40 |      9.203 |
|  4095 |        8 |          8 |     7172 |     3259 |      528 |       24 |     12.125 |
|  4095 |       32 |         16 |    19156 |     8859 |     1366 |       52 |      9.363 |
