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
## Status LEDs
## ==========================================
# LED[0] - Done signal
set_property PACKAGE_PIN U16 [get_ports done]
set_property IOSTANDARD LVCMOS33 [get_ports done]

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
## FSM State Monitoring LEDs (LED[1-8])
## ==========================================
# LED[1] - FSM State bit 0
set_property PACKAGE_PIN E19 [get_ports {fsm_leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[0]}]

# LED[2] - FSM State bit 1
set_property PACKAGE_PIN U19 [get_ports {fsm_leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[1]}]

# LED[3] - FSM State bit 2
set_property PACKAGE_PIN V19 [get_ports {fsm_leds[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[2]}]

# LED[4] - FSM State bit 3
set_property PACKAGE_PIN W18 [get_ports {fsm_leds[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[3]}]

# LED[5] - FSM State bit 4
set_property PACKAGE_PIN U15 [get_ports {fsm_leds[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[4]}]

# LED[6] - FSM State bit 5
set_property PACKAGE_PIN U14 [get_ports {fsm_leds[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[5]}]

# LED[7] - FSM State bit 6
set_property PACKAGE_PIN V14 [get_ports {fsm_leds[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[6]}]

# LED[8] - FSM State bit 7
set_property PACKAGE_PIN V13 [get_ports {fsm_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {fsm_leds[7]}]

## ==========================================
## Timing Constraints
## ==========================================
# Input delay constraints (relaxed for 25MHz operation)
set_input_delay -clock sys_clk_pin -min -add_delay 5.000 [get_ports rst]
set_input_delay -clock sys_clk_pin -max -add_delay 10.000 [get_ports rst]
set_input_delay -clock sys_clk_pin -min -add_delay 5.000 [get_ports start]
set_input_delay -clock sys_clk_pin -max -add_delay 10.000 [get_ports start]

# Output delay constraints (relaxed for 25MHz operation)
set_output_delay -clock sys_clk_pin -min -add_delay -2.000 [get_ports done]
set_output_delay -clock sys_clk_pin -max -add_delay 5.000 [get_ports done]
set_output_delay -clock sys_clk_pin -min -add_delay -2.000 [get_ports {digit[*]}]
set_output_delay -clock sys_clk_pin -max -add_delay 5.000 [get_ports {digit[*]}]
set_output_delay -clock sys_clk_pin -min -add_delay -2.000 [get_ports {fsm_leds[*]}]
set_output_delay -clock sys_clk_pin -max -add_delay 5.000 [get_ports {fsm_leds[*]}]

# NO multicycle paths needed - sequential processing doesn't require them

## ==========================================
## Configuration Options
## ==========================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ==========================================
## LED Interpretation Guide  
## ==========================================
## When running on hardware:
## 1. Press BTNC (center) to reset - all LEDs turn off
## 2. Press BTNU (up) to start inference
## 3. FSM monitoring LEDs show progressive pattern:
##    - IDLE:    00000001
##    - INIT:    00000011  
##    - L1_COMP: 00000111
##    - L1_RELU: 00001111
##    - L2_COMP: 00011111
##    - ARGMAX:  00111111
##    - DONE:    01111111
##    - ERROR:   10000000 (if unexpected state)
## 4. LED[0] = Done signal (inference complete)
## 5. LED[15:12] = Predicted digit in binary (0-9)
##
## Memory Fallback Behavior:
## If memory files fail to load during synthesis,
## all LEDs will light up (showing all 1s) to indicate error
