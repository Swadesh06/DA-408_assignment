// MAC Unit - Multiply-accumulate operation

module mac_unit (
    input clk,
    input rst,
    input en,
    input clr,
    input signed [7:0] a,
    input signed [7:0] b,
    output reg signed [19:0] acc
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
