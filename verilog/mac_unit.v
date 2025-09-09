// MAC Unit - Fundamental building block for MNIST accelerator
// Performs signed 8-bit multiply-accumulate operation
// Synthesizable on Basys3 FPGA DSP slices

module mac_unit (
    input clk,
    input rst,
    input en,                      // Enable signal
    input clr,                     // Clear accumulator
    input signed [7:0] a,          // Input activation
    input signed [7:0] b,          // Weight
    output reg signed [19:0] acc   // Accumulator output (20 bits for overflow protection)
);
    
    // Internal signals
    wire signed [15:0] prod;
    
    // Signed multiplication
    assign prod = a * b;
    
    // Accumulator with synchronous reset and clear
    always @(posedge clk) begin
        if (rst) begin
            acc <= 20'sd0;
        end else if (clr) begin
            acc <= 20'sd0;
        end else if (en) begin
            acc <= acc + {{4{prod[15]}}, prod};  // Sign extend and accumulate
        end
    end
    
endmodule
