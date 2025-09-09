#!/bin/bash
# Verify all required files are present for Vivado synthesis

echo "==================================================="
echo "MNIST Accelerator - Vivado File Verification"
echo "==================================================="

# Expected files
VERILOG_FILES=(
    "mnist_top_synth.v"
    "ctrl_fsm.v" 
    "mem_ctrl_synth.v"
    "mac_array_l1.v"
    "mac_array_l2.v"
    "mac_unit.v"
    "relu_unit.v"
    "argmax_unit.v"
)

MEMORY_FILES=(
    "w1.mem"
    "b1.mem"
    "w2.mem"
    "b2.mem"
    "test_img0.mem"
    "test_img1.mem"
    "test_img2.mem"
)

CONSTRAINT_FILES=(
    "mnist_basys3.xdc"
)

# Check Verilog files
echo "Checking Verilog Design Files (8 expected):"
verilog_count=0
for file in "${VERILOG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
        verilog_count=$((verilog_count + 1))
    else
        echo "  ✗ $file (MISSING)"
    fi
done

# Check memory files
echo ""
echo "Checking Memory Data Files (7 expected):"
memory_count=0
for file in "${MEMORY_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
        memory_count=$((memory_count + 1))
    else
        echo "  ✗ $file (MISSING)"
    fi
done

# Check constraints file
echo ""
echo "Checking Constraint Files (1 expected):"
constraint_count=0
for file in "${CONSTRAINT_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
        constraint_count=$((constraint_count + 1))
    else
        echo "  ✗ $file (MISSING)"
    fi
done

# Summary
echo ""
echo "==================================================="
echo "SUMMARY:"
echo "  Verilog Files:    $verilog_count/8"
echo "  Memory Files:     $memory_count/7"  
echo "  Constraint Files: $constraint_count/1"
echo "  Total Files:      $((verilog_count + memory_count + constraint_count))/16"

if [ $((verilog_count + memory_count + constraint_count)) -eq 16 ]; then
    echo ""
    echo "✅ ALL FILES PRESENT - Ready for Vivado synthesis!"
else
    echo ""
    echo "❌ MISSING FILES - Check above for details"
    exit 1
fi

echo "==================================================="
