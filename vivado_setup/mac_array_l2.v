// MAC Array Layer 2 - 10 parallel MAC units for second layer computation
// Processes 32 hidden neurons in parallel across 10 output neurons
// Synthesizable for Basys3 FPGA - Fixed for Vivado synthesis

module mac_array_l2 (
    input clk,
    input rst,
    input en,                               // Enable signal
    input clr,                              // Clear accumulators
    input init_bias,                        // Initialize with biases
    input signed [7:0] activation,          // Current activation value (shared across all MACs)
    input [79:0] weights_packed,            // 10 * 8-bit weights packed
    input [79:0] biases_packed,             // 10 * 8-bit biases packed
    output [199:0] acc_out_packed           // 10 * 20-bit accumulator outputs packed
);
    
    // Unpack inputs for internal use
    wire signed [7:0] weights [0:9];
    wire signed [7:0] biases [0:9];
    reg signed [19:0] acc_out [0:9];
    
    generate
        genvar j;
        for (j = 0; j < 10; j = j + 1) begin : unpack_inputs
            assign weights[j] = weights_packed[j*8 +: 8];
            assign biases[j] = biases_packed[j*8 +: 8];
        end
        for (j = 0; j < 10; j = j + 1) begin : pack_outputs
            assign acc_out_packed[j*20 +: 20] = acc_out[j];
        end
    endgenerate
    
    // Internal registers for accumulation
    reg signed [15:0] prod [0:9];
    integer i;
    
    // Parallel MAC operations - simplified without pipeline
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