// ReLU Unit - Parallel ReLU activation for 32 neurons
// Applies ReLU and requantization in single cycle
// Synthesizable for Basys3 FPGA

module relu_unit (
    input clk,
    input rst,
    input en,                               // Enable signal
    input signed [19:0] z_in [0:31],       // 32 pre-activation values
    output reg signed [7:0] a_out [0:31]   // 32 post-activation values (requantized)
);
    
    integer i;
    
    // Apply ReLU and requantize
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                a_out[i] <= 8'sd0;
            end
        end else if (en) begin
            for (i = 0; i < 32; i = i + 1) begin
                // Check if negative
                if (z_in[i][19]) begin
                    a_out[i] <= 8'sd0;  // ReLU: max(0, x)
                end else if (z_in[i] > 20'sd32767) begin
                    a_out[i] <= 8'sd127;  // Saturate at max positive value
                end else begin
                    a_out[i] <= z_in[i][15:8];  // Requantize: divide by 256
                end
            end
        end
    end
    
endmodule
