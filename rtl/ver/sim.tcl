vlib work

vlog ../comp/pipelined_heap_pkg.sv
vlog ../comp/sdp_ram.sv
vlog ../comp/ram_array.sv
vlog ../comp/heap_stage.sv
vlog ../comp/heap_stage_linear.sv

# Alternative implementations
vlog ../pipelined_heap_tree.sv
vlog ../pipelined_heap_linear.sv

vlog tb.sv

vmap -c

vsim work.tb

add wave -allowconstants -group tb  /tb/*

set dut_linear_path /tb/gen_pipelined_heap_linear/dut_i
set dut_linear_inst [ find instance $dut_linear_path ]
if { [ llength $dut_linear_inst ] } {
    set dut_path $dut_linear_path
    set dut_inst $dut_linear_inst
}

set dut_tree_path /tb/gen_pipelined_heap_tree/dut_i
set dut_tree_inst [ find instance $dut_tree_path ]
if { [ llength $dut_tree_inst ] } {
    set dut_path $dut_tree_path
    set dut_inst $dut_tree_inst
}

add wave -allowconstants -group dut $dut_path/*

for {set i 0} {$i < 32} {incr i} {
    set stage_path $dut_path/stage_gen[$i]/stage_inst
    set stage_inst [ find instance $stage_path ]
    if { [ llength $stage_inst ] } {
        add wave -allowconstants -group stage$i $stage_path/*
    } else {
        break
    }
}

onfinish stop

config wave -signalnamewidth 1

run -all

wave zoom full
