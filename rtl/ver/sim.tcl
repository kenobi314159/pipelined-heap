vlib work

vlog ../comp/pipelined_heap_pkg.sv
vlog ../comp/sdp_ram.sv
vlog ../comp/ram_array.sv
vlog ../comp/heap_stage.sv
vlog ../pipelined_heap.sv

vlog tb.sv

vmap -c

vsim work.tb

add wave -allowconstants -group tb  /tb/*
add wave -allowconstants -group dut /tb/dut_i/*

for {set i 0} {$i < 32} {incr i} {
    set stage_path /tb/dut_i/stage_gen[$i]/stage_inst
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
