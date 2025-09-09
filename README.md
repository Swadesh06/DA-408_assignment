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
- Sequential MAC unit (8-bit signed multiply-accumulate)
- On-chip BRAM: 26KB for weights/biases storage
- FSM-controlled layer computation
- Performance: 25,414 cycles/inference at 100MHz
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
│   ├── train_mnist.py      # NN training, quantization, weight export
│   └── verify_test.py       # Python inference verification
├── verilog/
│   └── mnist_accel.v       # Standalone accelerator (integrated MAC/memory/FSM)
├── testbench/
│   ├── tb_mnist_fixed.v    # Full testbench (20 images)
│   └── tb_simple.v         # Single image test
├── data/                   # Generated after training
│   ├── w1.hex             # Layer 1 weights (784×32)
│   ├── b1.hex             # Layer 1 biases (32)
│   ├── w2.hex             # Layer 2 weights (32×10)
│   ├── b2.hex             # Layer 2 biases (10)
│   ├── test_imgs.hex      # Test images (20×784)
│   └── test_labels.txt    # Ground truth labels
├── sim/                    # Simulation outputs (created on build)
├── logs/                   # Test results (created on build)
├── requirements.txt        # Python dependencies
├── Makefile               # Build automation
└── run_demo.sh            # Quick demo script
```

## Execution Instructions

### Quick Start (Using Makefile)

```bash
conda activate fpga_mnist
make all        # Train model and run full simulation
make test       # Run all tests (Python + Verilog)
make help       # Show all available targets
```

### Manual Execution

#### Step 1: Train Neural Network and Generate Weights

```bash
conda activate fpga_mnist
cd python
python train_mnist.py
```

**Output:**
- Float32 test accuracy: ~96%
- Int8 quantized accuracy: ~90%
- Generates weight files in `data/`

**Expected console output:**
```
MNIST FPGA Accelerator - Model Training
Loading MNIST dataset...
Training model...
Epoch 1/10...
Test accuracy (float32): 0.9595
Quantizing model to Int8...
Quantized model accuracy: 0.8990 (899/1000)
Weights exported to ../data/
```

### Step 2: Verify Python Quantized Model

```bash
python verify_test.py
```

**Output:**
- Tests 20 images with quantized weights
- Expected accuracy: 75% (15/20)

### Step 3: Compile Verilog Design

```bash
cd ..
iverilog -o sim/mnist_accel \
    testbench/tb_mnist_fixed.v \
    verilog/mnist_accel.v
```

### Step 4: Run Full Simulation

```bash
cd sim
vvp mnist_accel | tee ../logs/full_test.log
```

**Output:**
- Tests 20 images
- Per-image results: PASS/FAIL with predictions
- Summary statistics

### Step 5: Run Single Image Test

```bash
cd ..
iverilog -o sim/single_test testbench/tb_simple.v verilog/mnist_accel.v
cd sim
vvp single_test
```

**Output:**
- Single inference timing
- Cycle count: 25,414
- Predicted digit

### Step 6: Quick Demo (All Steps)

```bash
chmod +x run_demo.sh
./run_demo.sh
```

## Performance Metrics

| Metric | Value |
|--------|-------|
| Inference cycles | 25,414 |
| Clock frequency | 100 MHz |
| Inference time | 254 μs |
| Throughput | 3,937 images/s |
| Processing | Sequential |
| Memory usage | 26 KB BRAM |
| Bit width | Int8 (signed) |

## Module Descriptions

### mnist_accel.v
Top-level accelerator with corrected weight indexing. Implements sequential processing:
1. Layer 1 computation (784→32)
2. Layer 2 computation (32→10)
3. Argmax for classification

**Ports:**
- `clk`: System clock
- `rst`: Active-high reset
- `start`: Begin inference
- `img_data[6271:0]`: Flattened image (784×8 bits)
- `pred_digit[3:0]`: Output digit (0-9)
- `done`: Inference complete flag

### mac_unit.v
8-bit signed multiply-accumulate unit.

**Operation:** `out = a × b + c`

**Ports:**
- `a[7:0]`: Input activation
- `b[7:0]`: Weight
- `c[31:0]`: Accumulator input
- `out[31:0]`: MAC result

### mem_ctrl.v
Memory controller for weight/bias storage.

**Memory map:**
- `0x00000-0x061FF`: W1 weights (25,088 bytes)
- `0x06200-0x0621F`: B1 biases (32 bytes)
- `0x06220-0x0635F`: W2 weights (320 bytes)
- `0x06360-0x06369`: B2 biases (10 bytes)

### ctrl_fsm.v
Control state machine.

**States:**
- `IDLE`: Wait for start
- `LOAD_IMG`: Load input image
- `COMP_L1`: Layer 1 computation
- `RELU_L1`: ReLU activation
- `COMP_L2`: Layer 2 computation
- `ARGMAX`: Find maximum
- `OUTPUT`: Signal completion

## Data Formats

### Weight Files (.hex)
- Format: 2-digit hexadecimal per line
- Encoding: Unsigned 8-bit (0x00-0xFF)
- Mapping: 0x00-0x7F → [0,127], 0x80-0xFF → [-128,-1]

### Test Images
- Format: 784 bytes per image
- Quantization: [0,255] → [0,127] (7-bit unsigned)

## Debugging

### Common Issues

1. **Simulation timeout**
   - Check FSM state transitions
   - Verify counter resets
   - Monitor `done` signal

2. **Wrong predictions**
   - Verify weight loading order
   - Check signed arithmetic
   - Validate quantization scales

3. **Compilation errors**
   - Ensure all modules included
   - Check file paths
   - Verify iVerilog installation

### Debug Commands

```bash
# Verbose compilation
iverilog -v -o sim/debug testbench/tb_simple.v verilog/*.v

# Generate VCD for waveform viewing
# Add to testbench: $dumpfile("wave.vcd"); $dumpvars(0, tb_simple);
vvp sim/debug
gtkwave wave.vcd  # Requires GTKWave installation
```

## FPGA Deployment

### Basys3 Constraints
- Clock: 100MHz (W5 pin)
- Reset: Button (U18)
- Start: Button (T18)
- Output: 7-segment display

### Resource Utilization (Estimated)
| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| LUT | 2,500 | 20,800 | 12% |
| FF | 1,200 | 41,600 | 3% |
| BRAM | 13 | 50 | 26% |
| DSP | 8 | 90 | 9% |

## Citation

If using this implementation, cite:
```
MNIST Hardware Accelerator
DA-408 Assignment Implementation
Basys3 FPGA Target, Int8 Quantization
```

## License

Academic use only. See project_instructions.md for requirements.
