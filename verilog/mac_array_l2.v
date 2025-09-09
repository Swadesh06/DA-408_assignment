// MAC Array Layer 2 - 10 parallel MAC units for second layer computation
// Processes 32 hidden neurons in parallel across 10 output neurons
// Synthesizable for Basys3 FPGA

module mac_array_l2 (
    input clk,
    input rst,
    input en,                               // Enable signal
    input clr,                              // Clear accumulators
    input init_bias,                        // Initialize with biases
    input signed [7:0] activation,          // Current activation value (shared across all MACs)
    input signed [7:0] weights [0:9],       // 10 weights for current activation
    input signed [7:0] biases [0:9],        // 10 bias values
    output reg signed [19:0] acc_out [0:9]  // 10 accumulator outputs
);
    
    // Internal registers for accumulation
    reg signed [15:0] prod [0:9];
    integer i;
    
    // Parallel MAC operations
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 10; i = i + 1) begin
                acc_out[i] <= 20'sd0;
            end
        end else if (clr) begin
            for (i = 0; i < 10; i = i + 1) begin
                acc_out[i] <= 20'sd0;
            end
        end else if (init_bias) begin
            // Initialize with biases (not scaled for L2)
            for (i = 0; i < 10; i = i + 1) begin
                acc_out[i] <= {{12{biases[i][7]}}, biases[i]};
            end
        end else if (en) begin
            // Parallel multiply-accumulate
            for (i = 0; i < 10; i = i + 1) begin
                prod[i] = activation * weights[i];
                acc_out[i] <= acc_out[i] + {{4{prod[i][15]}}, prod[i]};
            end
        end
    end
    
endmodule
