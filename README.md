# MNIST Hardware Accelerator for FPGA

Hardware implementation of an Int8-quantized neural network (784-32-10) for MNIST digit classification on FPGA.

## Architecture

### Neural Network
- Input: 784 neurons (28×28 pixels)
- Hidden: 32 neurons, ReLU activation
- Output: 10 neurons (digits 0-9)
- Quantization: Int8 for weights, biases, activations
- Parameters: 25,450 Int8 values

### Hardware Design
- Parallel MAC arrays (32 units for L1, 10 units for L2)
- On-chip BRAM: 26KB for weights/biases storage
- FSM-controlled layer computation
- Performance: ~820 cycles/inference at 100MHz (~8.2μs)
- Accuracy: 75% (15/20) - matches Python model exactly

## Prerequisites

### System Requirements
- macOS (tested on M4 MacBook Air, macOS 15.6)
- Python 3.8+
- 4GB RAM minimum
- 1GB disk space

### Software Installation

#### 1. Install Homebrew (if not installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install iVerilog
```bash
brew install icarus-verilog
# Verify installation
iverilog -v
```

#### 3. Create Conda Environment
```bash
# Install Miniconda (if not installed)
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
sh Miniconda3-latest-MacOSX-arm64.sh

# Create environment
conda create -n fpga_mnist python=3.10
conda activate fpga_mnist

# Install dependencies
pip install -r requirements.txt
```

## Repository Structure

```
.
├── python/
│   ├── train_mnist.py          # NN training, quantization, weight export
│   └── verify_test.py          # Python inference verification
├── verilog/
│   ├── mnist_top.v            # Main accelerator (simulation version)
│   ├── mnist_top_synth.v      # Synthesis version with embedded images
│   ├── ctrl_fsm.v             # Control state machine
│   ├── mem_ctrl.v             # Memory controller (simulation)
│   ├── mem_ctrl_synth.v       # Memory controller (synthesis)
│   ├── mac_array_l1.v         # Layer 1 MAC array (32 units)
│   ├── mac_array_l2.v         # Layer 2 MAC array (10 units)
│   ├── mac_unit.v             # Single MAC unit
│   ├── relu_unit.v            # ReLU activation unit
│   └── argmax_unit.v          # Argmax unit for classification
├── testbench/
│   ├── tb_mnist_corrected.v   # Full testbench (20 images)
│   ├── tb_sequential.v        # Sequential version testbench
│   ├── tb_single_img.v        # Single image testbench
│   └── tb_synth_test.v        # Synthesis version testbench
├── data/                      # Training data files
│   ├── w1.hex                 # Layer 1 weights (784×32)
│   ├── b1.hex                 # Layer 1 biases (32)
│   ├── w2.hex                 # Layer 2 weights (32×10)
│   ├── b2.hex                 # Layer 2 biases (10)
│   ├── test_imgs.hex          # All test images (20×784)
│   └── test_labels.txt        # Ground truth labels
├── data_mem/                  # Vivado-compatible memory files
│   ├── w1.mem                 # Layer 1 weights (.mem format)
│   ├── b1.mem                 # Layer 1 biases (.mem format)
│   ├── w2.mem                 # Layer 2 weights (.mem format)
│   ├── b2.mem                 # Layer 2 biases (.mem format)
│   ├── test_img0.mem          # Test image 0 (digit 6)
│   ├── test_img1.mem          # Test image 1 (digit 2)
│   ├── test_img2.mem          # Test image 2 (digit 3)
│   └── test_labels.mem        # Labels for embedded images
├── sim/                       # Simulation outputs
├── logs/                      # Test results
├── mnist_basys3.xdc          # Constraints file for Basys3 FPGA
├── requirements.txt          # Python dependencies
├── Makefile                  # Build automation
└── run_demo.sh              # Quick demo script
```

## Verilog Compilation with iVerilog

### SystemVerilog Support Required
All testbenches require SystemVerilog support due to unpacked arrays:

```bash
iverilog -g2012 [options] [files...]
```

### Basic Compilation Commands

#### 1. Single Image Test (Simulation Version)
```bash
iverilog -g2012 -o sim/single_img_test \
    testbench/tb_single_img.v \
    verilog/mnist_top.v \
    verilog/ctrl_fsm.v \
    verilog/mem_ctrl.v \
    verilog/mac_array_l1.v \
    verilog/mac_array_l2.v \
    verilog/relu_unit.v \
    verilog/argmax_unit.v \
    verilog/mac_unit.v
```

#### 2. Full 20-Image Test
```bash
iverilog -g2012 -o sim/full_test \
    testbench/tb_mnist_corrected.v \
    verilog/mnist_top.v \
    verilog/ctrl_fsm.v \
    verilog/mem_ctrl.v \
    verilog/mac_array_l1.v \
    verilog/mac_array_l2.v \
    verilog/relu_unit.v \
    verilog/argmax_unit.v \
    verilog/mac_unit.v
```

#### 3. Synthesis Version Test
```bash
iverilog -g2012 -o sim/synth_test \
    testbench/tb_synth_test.v \
    verilog/mnist_top_synth.v \
    verilog/ctrl_fsm.v \
    verilog/mem_ctrl_synth.v \
    verilog/mac_array_l1.v \
    verilog/mac_array_l2.v \
    verilog/relu_unit.v \
    verilog/argmax_unit.v \
    verilog/mac_unit.v
```

## Running Testbenches

### 1. Single Image Testing

#### Quick Test (Default: Image 0, Digit 6)
```bash
./sim/single_img_test
```

#### Testing Different Images
Edit `testbench/tb_single_img.v` parameters:

```verilog
// ==========================================
// TEST CONFIGURATION - MODIFY HERE
// ==========================================
parameter TEST_IMG_IDX = 0;  // Change this (0-19)
parameter IMG_FILE = "data_mem/test_img0.mem";  // Change image file
parameter EXPECTED_DIGIT = 6;  // Change expected result
```

#### Available Test Images
| Image File | Index | Expected Digit | Description |
|------------|-------|----------------|-------------|
| `data_mem/test_img0.mem` | 0 | 6 | First test image |
| `data_mem/test_img1.mem` | 1 | 2 | Second test image |
| `data_mem/test_img2.mem` | 2 | 3 | Third test image |

For images 3-19, you can extract them from the main file:
```bash
# Extract image N (where N is 3-19)
head -n $((784*(N+1))) data/test_imgs.hex | tail -n 784 > data_mem/test_imgN.mem
```

#### Complete Test Image Labels (0-19)
```
0: 6    5: 2    10: 6   15: 6
1: 2    6: 3    11: 9   16: 8  
2: 3    7: 4    12: 2   17: 0
3: 7    8: 7    13: 0   18: 6
4: 2    9: 6    14: 9   19: 5
```

### 2. Full Test Suite
```bash
./sim/full_test
```
Tests all 20 images, reports accuracy.

### 3. Synthesis Version Test
```bash
./sim/synth_test
```
Tests 3 embedded images for Vivado compatibility.

## Image Data Storage Format

### Original Data Format
- **Source**: MNIST dataset (28×28 grayscale images)
- **Quantization**: [0,255] → [0,127] (7-bit signed)
- **Storage**: Each pixel = 8-bit signed integer

### File Formats

#### .hex Files (Simulation)
```
00
01  
7f
ff
...
```
- Format: 2-digit hexadecimal per line
- One pixel per line
- 784 lines per image

#### .mem Files (Synthesis)
```
00
01
7f
ff
...
```
- Format: Same as .hex but Vivado-compatible
- Used for BRAM initialization during synthesis
- Same structure: one pixel per line, 784 lines per image

### Image Data Layout
```
Pixel Layout (28×28):
Row 0: pixels 0-27    (lines 0-27 in file)
Row 1: pixels 28-55   (lines 28-55 in file)
...
Row 27: pixels 756-783 (lines 756-783 in file)
```

### Memory Organization in Hardware
```
Image Buffer: img[0:783]
- img[0] = top-left pixel
- img[27] = top-right pixel  
- img[756] = bottom-left pixel
- img[783] = bottom-right pixel
```

## FPGA Synthesis Files

### For Vivado Synthesis Use These Files:

#### Core Design Files
```
verilog/mnist_top_synth.v      # Top module with embedded test images
verilog/ctrl_fsm.v             # Control FSM (same for both versions)
verilog/mem_ctrl_synth.v       # Memory controller with synthesis paths
verilog/mac_array_l1.v         # Layer 1 MAC array
verilog/mac_array_l2.v         # Layer 2 MAC array  
verilog/mac_unit.v             # Single MAC unit
verilog/relu_unit.v            # ReLU activation
verilog/argmax_unit.v          # Argmax unit
```

#### Memory Files (Include in Vivado Project)
```
data_mem/w1.mem               # Layer 1 weights
data_mem/b1.mem               # Layer 1 biases
data_mem/w2.mem               # Layer 2 weights
data_mem/b2.mem               # Layer 2 biases
data_mem/test_img0.mem        # Test image 0
data_mem/test_img1.mem        # Test image 1
data_mem/test_img2.mem        # Test image 2
```

#### Constraints File
```
mnist_basys3.xdc              # Pin mappings and timing constraints
```

### Vivado Project Setup
1. Create new RTL project
2. Add all `.v` files from synthesis list above
3. Add all `.mem` files to project (for BRAM initialization)
4. Add constraints file `mnist_basys3.xdc`
5. Set `mnist_top_synth` as top module
6. Run synthesis and implementation

## Hardware Interface (Basys3 Board)

### Control Interface
- **Reset**: Center button (BTNC) - Active high
- **Start**: Up button (BTNU) - Pulse to start inference
- **Image Select**: SW[1:0] - Select test image (00, 01, 10)

### Output Interface  
- **Done**: LED[0] - Lights when inference complete
- **Valid**: LED[1] - Lights when valid image selected  
- **Digit**: LED[15:12] - 4-bit binary result (0000=0, 0001=1, ..., 1001=9)

### Usage on Hardware
1. Set SW[1:0] to select image (00, 01, or 10)
2. Verify LED[1] lights (valid selection)
3. Press BTNC to reset
4. Press BTNU to start inference  
5. Wait for LED[0] to light (done)
6. Read result from LED[15:12] in binary

### LED Interpretation
```
LED[15:12] Binary → Decimal Digit
0000 → 0    0101 → 5
0001 → 1    0110 → 6  
0010 → 2    0111 → 7
0011 → 3    1000 → 8
0100 → 4    1001 → 9
```

## Debugging and Waveform Generation

### Generate VCD Files
Add to testbench `initial` block:
```verilog
initial begin
    $dumpfile("debug.vcd");
    $dumpvars(0, tb_module_name);
end
```

### View Waveforms
```bash
# Install GTKWave (optional)
brew install gtkwave

# View waveforms
gtkwave debug.vcd
```

### Debug Output
All testbenches include detailed console output:
- Inference timing (cycles, real time)
- Prediction results (pass/fail)
- Debug information on failures

## Performance Metrics

| Version | Inference Cycles | Time@100MHz | Throughput |
|---------|------------------|-------------|------------|
| Parallel | ~820 | ~8.2 μs | 122,000 img/s |
| Sequential | 25,414 | ~254 μs | 3,937 img/s |

## Execution Instructions

### Quick Start (Using Makefile)
```bash
conda activate fpga_mnist
make all        # Train model and run full simulation
make test       # Run all tests (Python + Verilog)
make help       # Show all available targets
```

### Manual Pipeline

#### Step 1: Train Neural Network
```bash
conda activate fpga_mnist
cd python
python train_mnist.py
```

#### Step 2: Verify Python Model
```bash
python verify_test.py
```

#### Step 3: Test Single Image
```bash
cd ..
# Compile
iverilog -g2012 -o sim/single_img_test testbench/tb_single_img.v verilog/mnist_top.v verilog/ctrl_fsm.v verilog/mem_ctrl.v verilog/mac_array_l1.v verilog/mac_array_l2.v verilog/relu_unit.v verilog/argmax_unit.v verilog/mac_unit.v

# Run
./sim/single_img_test
```

#### Step 4: Test All Images  
```bash
# Compile
iverilog -g2012 -o sim/full_test testbench/tb_mnist_corrected.v verilog/mnist_top.v verilog/ctrl_fsm.v verilog/mem_ctrl.v verilog/mac_array_l1.v verilog/mac_array_l2.v verilog/relu_unit.v verilog/argmax_unit.v verilog/mac_unit.v

# Run
./sim/full_test
```

#### Step 5: Test Synthesis Version
```bash
# Compile
iverilog -g2012 -o sim/synth_test testbench/tb_synth_test.v verilog/mnist_top_synth.v verilog/ctrl_fsm.v verilog/mem_ctrl_synth.v verilog/mac_array_l1.v verilog/mac_array_l2.v verilog/relu_unit.v verilog/argmax_unit.v verilog/mac_unit.v

# Run
./sim/synth_test
```

## Module Descriptions

### mnist_top.v (Simulation Version)
Top-level accelerator for simulation with external image loading.

**Ports:**
- `clk`: System clock
- `rst`: Active-high reset
- `start`: Begin inference
- `img_data[6271:0]`: Flattened image (784×8 bits)
- `pred_digit[3:0]`: Output digit (0-9)
- `done`: Inference complete flag

### mnist_top_synth.v (Synthesis Version)  
Top-level accelerator for FPGA synthesis with embedded test images.

**Additional Ports:**
- `img_sel[1:0]`: Test image selection (0-2)
- `valid`: Valid image selected flag

### mac_unit.v
8-bit signed multiply-accumulate unit.

**Operation:** `out = a × b + c`

### mem_ctrl.v vs mem_ctrl_synth.v
- **mem_ctrl.v**: Uses relative paths for simulation
- **mem_ctrl_synth.v**: Parameterized paths for synthesis compatibility

### ctrl_fsm.v
Control state machine managing inference pipeline.

**States:**
- `IDLE`: Wait for start
- `LOAD_IMG`: Load input image  
- `L1_COMP`: Layer 1 computation
- `L1_RELU`: ReLU activation
- `L2_COMP`: Layer 2 computation
- `ARGMAX`: Find maximum
- `DONE`: Signal completion

## Resource Utilization (Estimated for Basys3)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT | 4,200 | 20,800 | 20% |
| FF | 2,800 | 41,600 | 7% |
| BRAM | 15 | 50 | 30% |
| DSP | 42 | 90 | 47% |

## Citation

If using this implementation, cite:
```
MNIST Hardware Accelerator
DA-408 Assignment Implementation  
Basys3 FPGA Target, Int8 Quantization
Parallel MAC Array Architecture
```

## License

Academic use only. See project_instructions.md for requirements.