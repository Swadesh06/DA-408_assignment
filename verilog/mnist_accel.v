// MNIST Hardware Accelerator - Correct Implementation
// Fixed weight indexing and optimized computation

module mnist_accel (
    input clk,
    input rst,
    input start,
    input [6271:0] img_data,
    
    output reg [3:0] pred_digit,
    output reg done
);

    // Network parameters
    localparam IMG_SIZE = 784;
    localparam HID_SIZE = 32;
    localparam OUT_SIZE = 10;
    
    // States
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam L1_MAC = 3'd2;
    localparam L1_RELU = 3'd3;
    localparam L2_MAC = 3'd4;
    localparam FIND_MAX = 3'd5;
    
    reg [2:0] state;
    
    // Memories for weights/biases
    reg signed [7:0] w1_mem [0:25087];  // Layer 1: 784x32
    reg signed [7:0] b1_mem [0:31];     // Layer 1 biases
    reg signed [7:0] w2_mem [0:319];    // Layer 2: 32x10  
    reg signed [7:0] b2_mem [0:9];      // Layer 2 biases
    
    // Working memory
    reg signed [7:0] img [0:783];       // Input image
    reg signed [19:0] z1 [0:31];        // L1 pre-activation
    reg signed [7:0] a1 [0:31];         // L1 post-activation (ReLU)
    reg signed [19:0] z2 [0:9];         // L2 outputs
    
    // Computation control
    reg [15:0] cnt;      // General counter
    reg [4:0] n_idx;     // Neuron index
    reg [9:0] i_idx;     // Input index
    
    // MAC computation
    wire signed [15:0] prod;
    reg signed [7:0] op_a, op_b;
    assign prod = op_a * op_b;
    
    // Variables for argmax
    reg signed [19:0] max_val;
    reg [3:0] max_idx;
    
    integer i;
    
    // Load weights at startup
    initial begin
        $readmemh("../data/w1.hex", w1_mem);
        $readmemh("../data/b1.hex", b1_mem);
        $readmemh("../data/w2.hex", w2_mem);
        $readmemh("../data/b2.hex", b2_mem);
    end
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            pred_digit <= 0;
            cnt <= 0;
            n_idx <= 0;
            i_idx <= 0;
            
            for (i = 0; i < 32; i = i + 1) begin
                z1[i] <= 0;
                a1[i] <= 0;
            end
            for (i = 0; i < 10; i = i + 1)
                z2[i] <= 0;
                
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                        cnt <= 0;
                    end
                end
                
                INIT: begin
                    // Load image in single cycle
                    if (cnt == 0) begin
                        for (i = 0; i < IMG_SIZE; i = i + 1)
                            img[i] <= img_data[i*8 +: 8];
                        
                        // Initialize z1 with biases (scaled by 256)
                        for (i = 0; i < HID_SIZE; i = i + 1)
                            z1[i] <= {{4{b1_mem[i][7]}}, b1_mem[i], 8'b0};
                        
                        cnt <= 1;
                    end else begin
                        state <= L1_MAC;
                        cnt <= 0;
                        n_idx <= 0;
                        i_idx <= 0;
                    end
                end
                
                L1_MAC: begin
                    // Compute Layer 1: Process one MAC per cycle
                    // Total cycles: 784 * 32 = 25,088
                    
                    if (cnt < IMG_SIZE * HID_SIZE) begin
                        // Determine current neuron and input
                        n_idx = cnt % HID_SIZE;
                        i_idx = cnt / HID_SIZE;
                        
                        // MAC operation
                        // Weight indexing: w1[input][neuron] = w1[i_idx * 32 + n_idx]
                        op_a = img[i_idx];
                        op_b = w1_mem[i_idx * HID_SIZE + n_idx];
                        z1[n_idx] <= z1[n_idx] + {{4{prod[15]}}, prod};
                        
                        cnt <= cnt + 1;
                    end else begin
                        state <= L1_RELU;
                        cnt <= 0;
                    end
                end
                
                L1_RELU: begin
                    // Apply ReLU and requantize in single cycle
                    for (i = 0; i < HID_SIZE; i = i + 1) begin
                        if (z1[i][19])  // Negative
                            a1[i] <= 0;
                        else if (z1[i] > 20'd32767)
                            a1[i] <= 127;
                        else
                            a1[i] <= z1[i][15:8];  // Divide by 256
                    end
                    
                    // Initialize z2 with biases
                    for (i = 0; i < OUT_SIZE; i = i + 1)
                        z2[i] <= {{12{b2_mem[i][7]}}, b2_mem[i]};
                    
                    state <= L2_MAC;
                    cnt <= 0;
                end
                
                L2_MAC: begin
                    // Compute Layer 2: Process one MAC per cycle
                    // Total cycles: 32 * 10 = 320
                    
                    if (cnt < HID_SIZE * OUT_SIZE) begin
                        // Determine current output and input
                        n_idx = cnt % OUT_SIZE;
                        i_idx = cnt / OUT_SIZE;
                        
                        // MAC operation
                        // Weight indexing: w2[input][output] = w2[i_idx * 10 + n_idx]
                        op_a = a1[i_idx];
                        op_b = w2_mem[i_idx * OUT_SIZE + n_idx];
                        z2[n_idx] <= z2[n_idx] + {{4{prod[15]}}, prod};
                        
                        cnt <= cnt + 1;
                    end else begin
                        state <= FIND_MAX;
                        cnt <= 0;
                    end
                end
                
                FIND_MAX: begin
                    // Find argmax in single cycle
                    max_val = z2[0];
                    max_idx = 0;
                    
                    for (i = 1; i < OUT_SIZE; i = i + 1) begin
                        if (z2[i] > max_val) begin
                            max_val = z2[i];
                            max_idx = i[3:0];
                        end
                    end
                    
                    pred_digit <= max_idx;
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
