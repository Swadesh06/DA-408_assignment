# MNIST Accelerator - Vivado Synthesis Setup

This folder contains all files needed for Vivado synthesis in the correct layout.

## Files Included (16 total)

### Verilog Design Sources (8 files)
```
mnist_top_synth.v      # Top module with embedded test images
ctrl_fsm.v             # Control finite state machine
mem_ctrl_synth.v       # Memory controller for BRAM
mac_array_l1.v         # Layer 1 MAC array (32 units)
mac_array_l2.v         # Layer 2 MAC array (10 units)
mac_unit.v             # Single MAC unit
relu_unit.v            # ReLU activation unit
argmax_unit.v          # Classification unit
```

### Memory Data Files (7 files)
```
w1.mem                 # Layer 1 weights (784×32 = 25,088 values)
b1.mem                 # Layer 1 biases (32 values)
w2.mem                 # Layer 2 weights (32×10 = 320 values)
b2.mem                 # Layer 2 biases (10 values)
test_img0.mem          # Test image 0 (digit 6, 784 pixels)
test_img1.mem          # Test image 1 (digit 2, 784 pixels)
test_img2.mem          # Test image 2 (digit 3, 784 pixels)
```

### Constraints File (1 file)
```
mnist_basys3.xdc       # Pin mappings and timing constraints for Basys3
```

## Vivado Project Setup Instructions

### 1. Create New RTL Project
```
File → New Project → RTL Project
Project Name: MNIST_Accelerator
Target Part: xc7a35tcpg236-1 (Basys3)
```

### 2. Add Design Sources
```
Add Sources → Add or Create Design Sources
Click "Add Files" → Select ALL .v files (8 files)
Make sure "Copy sources into project" is CHECKED
```

### 3. Add Memory Files  
```
Add Sources → Add or Create Design Sources
Click "Add Files" → Select ALL .mem files (7 files)
Make sure "Copy sources into project" is CHECKED
```

### 4. Add Constraints
```
Add Sources → Add or Create Constraints
Click "Add Files" → Select mnist_basys3.xdc
Make sure "Copy sources into project" is CHECKED
```

### 5. Set Top Module
```
Right-click mnist_top_synth.v in Sources panel
Select "Set as Top"
```

### 6. Run Synthesis
```
Flow Navigator → Run Synthesis
Wait for completion (~5-10 minutes)
```

### 7. Run Implementation
```
Flow Navigator → Run Implementation  
Wait for completion (~5-10 minutes)
```

### 8. Generate Bitstream
```
Flow Navigator → Generate Bitstream
Wait for completion (~5-10 minutes)
```

### 9. Program FPGA
```
Flow Navigator → Open Hardware Manager
Auto Connect → Program Device
Select generated .bit file → Program
```

## Hardware Interface (Basys3 Board)

### Control Inputs
- **BTNC (Center Button)**: Reset - Press to reset accelerator
- **BTNU (Up Button)**: Start - Press to begin inference  
- **SW[1:0] (Switches 0-1)**: Image Selection
  - `00`: Test image 0 (digit 6)
  - `01`: Test image 1 (digit 2)  
  - `10`: Test image 2 (digit 3)
  - `11`: Invalid (error condition)

### Status Outputs
- **LED[0]**: Done - Lights when inference complete
- **LED[1]**: Valid - Lights when valid image selected
- **LED[15:12]**: Predicted Digit (4-bit binary)
  - `0000` = 0, `0001` = 1, `0010` = 2, etc.

### Usage Example
```
1. Set SW[1:0] = 01 (select image 1, digit 2)
2. Verify LED[1] is ON (valid selection)
3. Press BTNC to reset
4. Press BTNU to start inference
5. Wait ~8.35μs (832 cycles at 100MHz)
6. LED[0] turns ON (done)
7. LED[15:12] shows 0010 (binary for digit 2) ✓
```

## Expected Performance
- **Inference Time**: ~832 clock cycles
- **Clock Frequency**: 100MHz
- **Real Time**: ~8.35 microseconds per inference
- **Throughput**: ~120,000 inferences per second

## Resource Utilization (Estimated)
- **LUTs**: ~4,200 / 20,800 (20%)
- **Flip-Flops**: ~2,800 / 41,600 (7%)  
- **BRAM**: ~15 / 50 (30%)
- **DSP48**: ~42 / 90 (47%)

## Troubleshooting

### Synthesis Errors
- Ensure all 16 files are added to project
- Verify .mem files are in same directory as .v files
- Check that mnist_top_synth.v is set as top module

### Memory File Issues  
- All .mem files must be present during synthesis
- Paths in $readmemh calls are relative to project directory
- Files will be "baked into" the bitstream (not loaded at runtime)

### Hardware Issues
- Verify correct part number: xc7a35tcpg236-1
- Check constraints file is properly applied
- Use Vivado's Hardware Manager for programming

## File Modifications Made

The following files were modified from the original to work with flat layout:

### mem_ctrl_synth.v
```verilog
// Changed parameter defaults from:
parameter W1_FILE = "data_mem/w1.mem"
// To:
parameter W1_FILE = "w1.mem"
```

### mnist_top_synth.v  
```verilog
// Changed $readmemh calls from:
$readmemh("data_mem/test_img0.mem", test_imgs, 0, 783);
// To:
$readmemh("test_img0.mem", test_imgs, 0, 783);
```

## Contact
All files are ready for Vivado synthesis. No further modifications needed.
