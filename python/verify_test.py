"""
Verify test images with quantized model
Compare Python inference with Verilog results
"""

import numpy as np

def load_test_data():
    """Load test images and labels"""
    # Load test images
    with open('../data/test_imgs.hex', 'r') as f:
        hex_data = [int(line.strip(), 16) for line in f.readlines()]
    
    # Reshape to 20 images of 784 pixels
    imgs = np.array(hex_data).reshape(20, 784).astype(np.int8)
    
    # Load labels
    with open('../data/test_labels.txt', 'r') as f:
        labels = [int(line.strip()) for line in f.readlines()]
    
    return imgs, labels

def load_weights():
    """Load quantized weights"""
    # Load W1
    with open('../data/w1.hex', 'r') as f:
        w1_flat = []
        for line in f.readlines():
            val = int(line.strip(), 16)
            # Convert unsigned to signed
            if val > 127:
                val = val - 256
            w1_flat.append(val)
    w1 = np.array(w1_flat).reshape(784, 32).astype(np.int8)
    
    # Load B1
    with open('../data/b1.hex', 'r') as f:
        b1_vals = []
        for line in f.readlines():
            val = int(line.strip(), 16)
            if val > 127:
                val = val - 256
            b1_vals.append(val)
    b1 = np.array(b1_vals).astype(np.int8)
    
    # Load W2
    with open('../data/w2.hex', 'r') as f:
        w2_flat = []
        for line in f.readlines():
            val = int(line.strip(), 16)
            if val > 127:
                val = val - 256
            w2_flat.append(val)
    w2 = np.array(w2_flat).reshape(32, 10).astype(np.int8)
    
    # Load B2
    with open('../data/b2.hex', 'r') as f:
        b2_vals = []
        for line in f.readlines():
            val = int(line.strip(), 16)
            if val > 127:
                val = val - 256
            b2_vals.append(val)
    b2 = np.array(b2_vals).astype(np.int8)
    
    return w1, b1, w2, b2

def inference_int8(img, w1, b1, w2, b2):
    """Perform inference with Int8 arithmetic"""
    # Layer 1: FC + ReLU
    z1 = np.zeros(32, dtype=np.int32)
    
    # Add biases (scaled)
    for i in range(32):
        z1[i] = int(b1[i]) * 256  # Scale bias
    
    # Matrix multiplication
    for i in range(32):
        for j in range(784):
            z1[i] += int(img[j]) * int(w1[j, i])
    
    # ReLU and requantize
    a1 = np.zeros(32, dtype=np.int8)
    for i in range(32):
        if z1[i] < 0:
            a1[i] = 0
        elif z1[i] > 32767:
            a1[i] = 127
        else:
            a1[i] = z1[i] >> 8  # Divide by 256
    
    # Layer 2: FC
    z2 = np.zeros(10, dtype=np.int32)
    
    # Add biases
    for i in range(10):
        z2[i] = int(b2[i])
    
    # Matrix multiplication
    for i in range(10):
        for j in range(32):
            z2[i] += int(a1[j]) * int(w2[j, i])
    
    # Argmax
    pred = np.argmax(z2)
    
    return pred, z2

def main():
    print("="*50)
    print("Verifying Test Images with Quantized Model")
    print("="*50)
    
    # Load data
    imgs, labels = load_test_data()
    w1, b1, w2, b2 = load_weights()
    
    print(f"\nLoaded {len(imgs)} test images")
    print(f"W1 shape: {w1.shape}")
    print(f"W2 shape: {w2.shape}")
    
    # Test each image
    correct = 0
    for i in range(len(imgs)):
        pred, scores = inference_int8(imgs[i], w1, b1, w2, b2)
        
        if pred == labels[i]:
            result = "PASS"
            correct += 1
        else:
            result = "FAIL"
        
        print(f"Test {i+1:2d}: {result} - Predicted: {pred}, Expected: {labels[i]}")
    
    print(f"\nAccuracy: {correct}/{len(imgs)} = {correct*100/len(imgs):.1f}%")
    
    # Debug first image
    print("\n" + "="*50)
    print("Debug Info for First Image:")
    print("="*50)
    pred, scores = inference_int8(imgs[0], w1, b1, w2, b2)
    print(f"Output scores: {scores}")
    print(f"Predicted: {pred}, Expected: {labels[0]}")
    
    # Check weight ranges
    print(f"\nW1 range: [{w1.min()}, {w1.max()}]")
    print(f"B1 range: [{b1.min()}, {b1.max()}]")
    print(f"W2 range: [{w2.min()}, {w2.max()}]")
    print(f"B2 range: [{b2.min()}, {b2.max()}]")
    print(f"Image range: [{imgs[0].min()}, {imgs[0].max()}]")

if __name__ == "__main__":
    main()
