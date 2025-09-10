## ==========================================
## Clock Signal - 25MHz (relaxed from 100MHz for timing closure)
## ==========================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 40.00 -waveform {0 20} [get_ports clk]

## ==========================================
## Control Buttons
## ==========================================
# Reset - Center Button (BTNC)
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# Start - Up Button (BTNU)
set_property PACKAGE_PIN T18 [get_ports start]
set_property IOSTANDARD LVCMOS33 [get_ports start]

## ==========================================
## Image Selection Switches - REMOVED
## ==========================================
# No image selection - single test image hardcoded

## ==========================================
## Status LEDs
## ==========================================
# LED[0] - Done signal
set_property PACKAGE_PIN U16 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports done]

# LED[1] - UNUSED (was valid signal)
# set_property PACKAGE_PIN E19 [get_ports valid]
# set_property IOSTANDARD LVCMOS33 [get_ports valid]

## ==========================================
## Predicted Digit Output LEDs
## ==========================================
# LED[12] - Digit bit 0 (LSB)
set_property PACKAGE_PIN L1 [get_ports {digit[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[0]}]

# LED[13] - Digit bit 1
set_property PACKAGE_PIN P1 [get_ports {digit[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[1]}]

# LED[14] - Digit bit 2
set_property PACKAGE_PIN N3 [get_ports {digit[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[2]}]

# LED[15] - Digit bit 3 (MSB)
set_property PACKAGE_PIN P3 [get_ports {digit[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {digit[3]}]

## ==========================================
## Timing Constraints
## ==========================================
# Input delay constraints (relaxed for 25MHz operation)
set_input_delay -clock sys_clk_pin -min -add_delay 5.000 [get_ports rst]
set_input_delay -clock sys_clk_pin -max -add_delay 10.000 [get_ports rst]
set_input_delay -clock sys_clk_pin -min -add_delay 5.000 [get_ports start]
set_input_delay -clock sys_clk_pin -max -add_delay 10.000 [get_ports start]
# Image selection delays removed - no img_sel port

# Output delay constraints (relaxed for 25MHz operation)
set_output_delay -clock sys_clk_pin -min -add_delay -2.000 [get_ports done]
set_output_delay -clock sys_clk_pin -max -add_delay 5.000 [get_ports done]
# Valid output delays removed - no valid port
set_output_delay -clock sys_clk_pin -min -add_delay -2.000 [get_ports {digit[*]}]
set_output_delay -clock sys_clk_pin -max -add_delay 5.000 [get_ports {digit[*]}]

# Multicycle paths for MAC operations (critical timing paths)
set_multicycle_path 2 -setup -from [get_cells */mac_array_l1/*] -to [get_cells */l1_acc_reg[*]]
set_multicycle_path 1 -hold -from [get_cells */mac_array_l1/*] -to [get_cells */l1_acc_reg[*]]
set_multicycle_path 2 -setup -from [get_cells */mac_array_l2/*] -to [get_cells */l2_acc_reg[*]]
set_multicycle_path 1 -hold -from [get_cells */mac_array_l2/*] -to [get_cells */l2_acc_reg[*]]

## ==========================================
## Configuration Options
## ==========================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ==========================================
## LED Interpretation Guide
## ==========================================
## When running on hardware:
## 1. Set SW[1:0] to select test image (00, 01, or 10)
## 2. Press BTNC (center) to reset
## 3. Press BTNU (up) to start inference
## 4. LED[1] lights if valid image selected
## 5. LED[0] lights when inference complete
## 6. LED[15:12] shows predicted digit in binary:
##    - 0000 = 0
##    - 0001 = 1
##    - 0010 = 2
##    - 0011 = 3
##    - 0100 = 4
##    - 0101 = 5
##    - 0110 = 6
##    - 0111 = 7
##    - 1000 = 8
##    - 1001 = 9
