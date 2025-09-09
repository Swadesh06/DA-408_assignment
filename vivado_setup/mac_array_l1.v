// MAC Array Layer 1 - 32 parallel MAC units for first layer computation
// Processes 784 inputs in parallel across 32 neurons
// Synthesizable for Basys3 FPGA

module mac_array_l1 (
    input clk,
    input rst,
    input en,                               // Enable signal
    input clr,                              // Clear accumulators
    input init_bias,                        // Initialize with biases
    input signed [7:0] pixel,               // Current pixel value (shared across all MACs)
    input signed [7:0] weights [0:31],      // 32 weights for current pixel
    input signed [7:0] biases [0:31],       // 32 bias values
    output reg signed [19:0] acc_out [0:31] // 32 accumulator outputs
);
    
    // Internal registers for accumulation
    reg signed [15:0] prod [0:31];
    integer i;
    
    // Parallel MAC operations
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                acc_out[i] <= 20'sd0;
            end
        end else if (clr) begin
            for (i = 0; i < 32; i = i + 1) begin
                acc_out[i] <= 20'sd0;
            end
        end else if (init_bias) begin
            // Initialize with scaled biases (multiply by 256)
            for (i = 0; i < 32; i = i + 1) begin
                acc_out[i] <= {{4{biases[i][7]}}, biases[i], 8'b0};
            end
        end else if (en) begin
            // Parallel multiply-accumulate
            for (i = 0; i < 32; i = i + 1) begin
                prod[i] = pixel * weights[i];
                acc_out[i] <= acc_out[i] + {{4{prod[i][15]}}, prod[i]};
            end
        end
    end
    
endmodule
