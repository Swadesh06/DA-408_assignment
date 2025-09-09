"""
MNIST Neural Network Training and Quantization
Architecture: 784-32-10 fully connected network
Quantization: Int8 for FPGA deployment
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
import struct
import os

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

def create_model():
    """Create simple FC network: 784-32-10"""
    model = keras.Sequential([
        keras.layers.Flatten(input_shape=(28, 28)),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dense(10, activation='softmax')
    ])
    return model

def train_model():
    """Train model on MNIST dataset"""
    print("Loading MNIST dataset...")
    (x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()
    
    # Normalize to [0,1]
    x_train = x_train.astype('float32') / 255.0
    x_test = x_test.astype('float32') / 255.0
    
    # Create and compile model
    model = create_model()
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    print("Training model...")
    history = model.fit(
        x_train, y_train,
        batch_size=128,
        epochs=10,
        validation_split=0.1,
        verbose=1
    )
    
    # Evaluate
    test_loss, test_acc = model.evaluate(x_test, y_test, verbose=0)
    print(f"\nTest accuracy (float32): {test_acc:.4f}")
    
    return model, (x_test, y_test)

def quantize_weights(weights, scale_factor=127):
    """Quantize weights to Int8"""
    # Find max absolute value
    max_val = np.max(np.abs(weights))
    
    # Calculate scale
    if max_val > 0:
        scale = scale_factor / max_val
    else:
        scale = 1.0
    
    # Quantize
    q_weights = np.round(weights * scale).astype(np.int8)
    
    return q_weights, scale

def quantize_model(model):
    """Quantize all model weights and biases to Int8"""
    layers = model.layers
    quantized_params = {}
    
    # Layer 1: Dense (784 -> 32)
    w1, b1 = layers[1].get_weights()
    qw1, sw1 = quantize_weights(w1)
    qb1, sb1 = quantize_weights(b1)
    
    # Layer 2: Dense (32 -> 10)  
    w2, b2 = layers[2].get_weights()
    qw2, sw2 = quantize_weights(w2)
    qb2, sb2 = quantize_weights(b2)
    
    quantized_params = {
        'w1': qw1, 'b1': qb1, 'sw1': sw1, 'sb1': sb1,
        'w2': qw2, 'b2': qb2, 'sw2': sw2, 'sb2': sb2
    }
    
    return quantized_params

def test_quantized_model(q_params, x_test, y_test, num_samples=100):
    """Test quantized model accuracy"""
    correct = 0
    
    for i in range(num_samples):
        # Get input
        x = x_test[i].flatten()
        
        # Quantize input
        x_q = np.round(x * 127).astype(np.int8)
        
        # Layer 1: FC + ReLU
        z1 = np.dot(q_params['w1'].T, x_q.astype(np.int32)) + \
             (q_params['b1'].astype(np.int32) * 127)
        a1 = np.maximum(0, z1)  # ReLU
        
        # Normalize for next layer
        a1_norm = (a1 / (127 * q_params['sw1'])).astype(np.int32)
        a1_q = np.clip(a1_norm, -128, 127).astype(np.int8)
        
        # Layer 2: FC
        z2 = np.dot(q_params['w2'].T, a1_q.astype(np.int32)) + \
             q_params['b2'].astype(np.int32)
        
        # Get prediction
        pred = np.argmax(z2)
        if pred == y_test[i]:
            correct += 1
    
    accuracy = correct / num_samples
    print(f"Quantized model accuracy: {accuracy:.4f} ({correct}/{num_samples})")
    return accuracy

def export_weights_hex(q_params, output_dir='../data'):
    """Export quantized weights as hex files for Verilog"""
    os.makedirs(output_dir, exist_ok=True)
    
    # Export Layer 1 weights (784x32)
    w1 = q_params['w1']
    with open(f'{output_dir}/w1.hex', 'w') as f:
        for i in range(w1.shape[0]):
            for j in range(w1.shape[1]):
                val = int(w1[i, j]) & 0xFF
                f.write(f'{val:02x}\n')
    
    # Export Layer 1 biases (32)
    b1 = q_params['b1']
    with open(f'{output_dir}/b1.hex', 'w') as f:
        for i in range(b1.shape[0]):
            val = int(b1[i]) & 0xFF
            f.write(f'{val:02x}\n')
    
    # Export Layer 2 weights (32x10)
    w2 = q_params['w2']
    with open(f'{output_dir}/w2.hex', 'w') as f:
        for i in range(w2.shape[0]):
            for j in range(w2.shape[1]):
                val = int(w2[i, j]) & 0xFF
                f.write(f'{val:02x}\n')
    
    # Export Layer 2 biases (10)
    b2 = q_params['b2']
    with open(f'{output_dir}/b2.hex', 'w') as f:
        for i in range(b2.shape[0]):
            val = int(b2[i]) & 0xFF
            f.write(f'{val:02x}\n')
    
    # Export scale factors
    with open(f'{output_dir}/scales.txt', 'w') as f:
        f.write(f"sw1: {q_params['sw1']}\n")
        f.write(f"sb1: {q_params['sb1']}\n")
        f.write(f"sw2: {q_params['sw2']}\n")
        f.write(f"sb2: {q_params['sb2']}\n")
    
    print(f"Weights exported to {output_dir}/")

def export_test_images(x_test, y_test, num_images=10, output_dir='../data'):
    """Export test images for Verilog testbench"""
    os.makedirs(output_dir, exist_ok=True)
    
    # Select random test images
    indices = np.random.choice(len(x_test), num_images, replace=False)
    
    with open(f'{output_dir}/test_imgs.hex', 'w') as f:
        for idx in indices:
            img = x_test[idx].flatten()
            # Quantize to Int8
            img_q = np.round(img * 127).astype(np.int8)
            
            for pixel in img_q:
                val = int(pixel) & 0xFF
                f.write(f'{val:02x}\n')
    
    # Save labels
    with open(f'{output_dir}/test_labels.txt', 'w') as f:
        for idx in indices:
            f.write(f"{y_test[idx]}\n")
    
    print(f"Test images exported to {output_dir}/")
    return indices

def main():
    print("="*50)
    print("MNIST FPGA Accelerator - Model Training")
    print("="*50)
    
    # Train model
    model, (x_test, y_test) = train_model()
    
    # Quantize model
    print("\nQuantizing model to Int8...")
    q_params = quantize_model(model)
    
    # Test quantized model
    print("\nTesting quantized model...")
    test_quantized_model(q_params, x_test, y_test, num_samples=1000)
    
    # Export weights
    print("\nExporting weights to hex files...")
    export_weights_hex(q_params)
    
    # Export test images
    print("\nExporting test images...")
    export_test_images(x_test, y_test, num_images=20)
    
    # Print weight dimensions
    print("\n" + "="*50)
    print("Model Parameters Summary:")
    print(f"Layer 1 weights: {q_params['w1'].shape} (784x32)")
    print(f"Layer 1 biases:  {q_params['b1'].shape} (32,)")
    print(f"Layer 2 weights: {q_params['w2'].shape} (32x10)")
    print(f"Layer 2 biases:  {q_params['b2'].shape} (10,)")
    print(f"Total parameters: {784*32 + 32 + 32*10 + 10} Int8 values")
    print("="*50)

if __name__ == "__main__":
    main()
