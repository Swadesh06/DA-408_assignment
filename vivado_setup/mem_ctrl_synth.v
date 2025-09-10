// Memory Controller - BRAM-based weight and bias storage

module mem_ctrl_synth (
    input clk,
    input rst,
    input [1:0] layer_sel,
    input [9:0] row_idx,
    output [255:0] w1_out_packed,
    output [255:0] b1_out_packed,
    output [79:0] w2_out_packed,
    output [79:0] b2_out_packed
);

    // Memory arrays - will infer BRAM in Vivado
    (* ram_style = "block" *) reg signed [7:0] w1_mem [0:25087];  // 784 * 32
    (* ram_style = "block" *) reg signed [7:0] b1_mem [0:31];     // 32 biases
    (* ram_style = "block" *) reg signed [7:0] w2_mem [0:319];    // 32 * 10
    (* ram_style = "block" *) reg signed [7:0] b2_mem [0:9];      // 10 biases

    // Load weights and biases from memory files
    initial begin
        $readmemh("w1.mem", w1_mem);
        $readmemh("b1.mem", b1_mem);
        $readmemh("w2.mem", w2_mem);
        $readmemh("b2.mem", b2_mem);
    end

    // Address calculation
    wire [14:0] w1_base_addr;
    wire [8:0] w2_base_addr;

    assign w1_base_addr = row_idx * 32;
    assign w2_base_addr = row_idx * 10;

    // Internal unpacked arrays for easier indexing
    reg signed [7:0] w1_out [0:31];
    reg signed [7:0] b1_out [0:31];
    reg signed [7:0] w2_out [0:9];
    reg signed [7:0] b2_out [0:9];

    // Pack outputs for port compatibility
    generate
        genvar k;
        for (k = 0; k < 32; k = k + 1) begin : pack_w1_b1
            assign w1_out_packed[k*8 +: 8] = w1_out[k];
            assign b1_out_packed[k*8 +: 8] = b1_out[k];
        end
        for (k = 0; k < 10; k = k + 1) begin : pack_w2_b2
            assign w2_out_packed[k*8 +: 8] = w2_out[k];
            assign b2_out_packed[k*8 +: 8] = b2_out[k];
        end
    endgenerate

    // Combinational read for immediate response
    integer i;

    always @(*) begin
        // Default values
        for (i = 0; i < 32; i = i + 1) begin
            w1_out[i] = 8'sd0;
            b1_out[i] = 8'sd0;
        end
        for (i = 0; i < 10; i = i + 1) begin
            w2_out[i] = 8'sd0;
            b2_out[i] = 8'sd0;
        end

        case (layer_sel)
            2'd1: begin  // Layer 1 active
                // Output 32 weights in parallel
                for (i = 0; i < 32; i = i + 1) begin
                    w1_out[i] = w1_mem[w1_base_addr + i];
                    b1_out[i] = b1_mem[i];
                end
            end

            2'd2: begin  // Layer 2 active
                // Output 10 weights in parallel
                for (i = 0; i < 10; i = i + 1) begin
                    w2_out[i] = w2_mem[w2_base_addr + i];
                    b2_out[i] = b2_mem[i];
                end
            end

            default: begin
                // Keep default zeros
            end
        endcase
    end

endmodule
