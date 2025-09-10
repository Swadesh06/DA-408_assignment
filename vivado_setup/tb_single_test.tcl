# Simulation script for tb_single_test
# This overrides the default 1000ns simulation time
# Vivado will automatically use this file for the tb_single_test testbench

set curr_wave [current_wave_config]
if { [string length $curr_wave] == 0 } {
  if { [llength [get_objects]] > 0} {
    add_wave /
    set_property needs_save false [current_wave_config]
  } else {
     send_msg_id Add_Wave-1 WARNING "No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console."
  }
}

# Run for 100ms to ensure MNIST inference completes
# The inference needs ~800 cycles at 25MHz = ~32µs minimum
# 100ms provides plenty of margin for completion
run 100ms
