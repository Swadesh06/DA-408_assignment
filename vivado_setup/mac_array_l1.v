// MAC Array Layer 1 - 32 parallel MAC units for first layer computation
// Processes 784 inputs in parallel across 32 neurons
// Synthesizable for Basys3 FPGA - Fixed for Vivado synthesis

module mac_array_l1 (
    input clk,
    input rst,
    input en,                               // Enable signal
    input clr,                              // Clear accumulators
    input init_bias,                        // Initialize with biases
    input signed [7:0] pixel,               // Current pixel value (shared across all MACs)
    input [255:0] weights_packed,           // 32 * 8-bit weights packed
    input [255:0] biases_packed,            // 32 * 8-bit biases packed
    output [639:0] acc_out_packed           // 32 * 20-bit accumulator outputs packed
);
    
    // Unpack inputs for internal use
    wire signed [7:0] weights [0:31];
    wire signed [7:0] biases [0:31];
    reg signed [19:0] acc_out [0:31];
    
    generate
        genvar j;
        for (j = 0; j < 32; j = j + 1) begin : unpack_inputs
            assign weights[j] = weights_packed[j*8 +: 8];
            assign biases[j] = biases_packed[j*8 +: 8];
        end
        for (j = 0; j < 32; j = j + 1) begin : pack_outputs
            assign acc_out_packed[j*20 +: 20] = acc_out[j];
        end
    endgenerate
    
    // Internal registers for accumulation with pipeline stage
    reg signed [15:0] prod_reg [0:31];  // Pipeline register for products
    reg signed [7:0] pixel_reg;         // Pipeline register for pixel
    reg signed [7:0] weights_reg [0:31]; // Pipeline register for weights
    integer i;
    
    // Pipeline stage 1: Register inputs and compute products
    always @(posedge clk) begin
        if (rst) begin
            pixel_reg <= 8'sd0;
            for (i = 0; i < 32; i = i + 1) begin
                weights_reg[i] <= 8'sd0;
                prod_reg[i] <= 16'sd0;
            end
        end else if (en) begin
            pixel_reg <= pixel;
            for (i = 0; i < 32; i = i + 1) begin
                weights_reg[i] <= weights[i];
                prod_reg[i] <= pixel * weights[i];  // Product computation
            end
        end
    end
    
    // Pipeline stage 2: Accumulation
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
            // Use pipelined product for accumulation
            for (i = 0; i < 32; i = i + 1) begin
                acc_out[i] <= acc_out[i] + {{4{prod_reg[i][15]}}, prod_reg[i]};
            end
        end
    end
    
endmodule