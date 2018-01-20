# set the working dir, where all compiled verilog goes
vlib work

# compile all verilog modules in file to working dir
# could also have multiple verilog files
vlog SmartLot.v
vlog SmartLot_bckgrn_HD.v
vlog SmartLot_bckgrn_two_HD.v

#load simulation using the file as the top level simulation module
vsim -L altera_mf_ver SmartLot

#log all signals and add some signals to waveform window
log {/*}

# add wave {/*} would add all items in top level simulation module
add wave {/*}

force {trigger} 0
force {GPIO_0[0]} 0 
force {SW[8]} 0
force {CLOCK_50} 0 
run 1ns

force {GPIO_0[0]} 0 
force {SW[8]} 0
force {CLOCK_50} 1 
run 1ns

force {SW[8]} 1
force {CLOCK_50} 1 0ns, 0 {1ns} -r 2ns
run 10000000000ns
