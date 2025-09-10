// ReLU Activation Unit - Parallel ReLU for 32 neurons

module relu_unit (
    input clk,
    input rst,
    input en,
    input [639:0] z_in_packed,
    output [255:0] a_out_packed
);

    // Unpack inputs for internal processing
    wire signed [19:0] z_in [0:31];
    reg signed [7:0] a_out [0:31];

    generate
        genvar j;
        for (j = 0; j < 32; j = j + 1) begin : unpack_inputs
            assign z_in[j] = z_in_packed[j*20 +: 20];
        end
        for (j = 0; j < 32; j = j + 1) begin : pack_outputs
            assign a_out_packed[j*8 +: 8] = a_out[j];
        end
    endgenerate

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
