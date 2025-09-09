// Memory Controller - BRAM-based weight and bias storage
// Provides parallel access to weights for MAC arrays
// Synthesizable BRAM inference for Basys3 FPGA

module mem_ctrl (
    input clk,
    input rst,
    
    // Control signals
    input [1:0] layer_sel,          // 0: idle, 1: L1, 2: L2
    input [9:0] row_idx,            // Current input index (0-783 for L1, 0-31 for L2)
    
    // Layer 1 weight outputs (32 parallel outputs for 32 MAC units)
    output reg signed [7:0] w1_out [0:31],
    output reg signed [7:0] b1_out [0:31],
    
    // Layer 2 weight outputs (10 parallel outputs for 10 MAC units)
    output reg signed [7:0] w2_out [0:9],
    output reg signed [7:0] b2_out [0:9]
);
    
    // Memory arrays - will infer BRAM
    // Layer 1: 784x32 weights + 32 biases
    reg signed [7:0] w1_mem [0:25087];  // 784 * 32 = 25088 weights
    reg signed [7:0] b1_mem [0:31];     // 32 biases
    
    // Layer 2: 32x10 weights + 10 biases  
    reg signed [7:0] w2_mem [0:319];    // 32 * 10 = 320 weights
    reg signed [7:0] b2_mem [0:9];      // 10 biases
    
    // Initialize memories from hex files
    initial begin
        $readmemh("../data/w1.hex", w1_mem);
        $readmemh("../data/b1.hex", b1_mem);
        $readmemh("../data/w2.hex", w2_mem);
        $readmemh("../data/b2.hex", b2_mem);
    end
    
    // Address calculation
    wire [14:0] w1_base_addr;
    wire [8:0] w2_base_addr;
    
    assign w1_base_addr = row_idx * 32;  // Base address for Layer 1 weights
    assign w2_base_addr = row_idx * 10;  // Base address for Layer 2 weights
    
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
                // Output 32 weights in parallel for current input
                for (i = 0; i < 32; i = i + 1) begin
                    w1_out[i] = w1_mem[w1_base_addr + i];
                    b1_out[i] = b1_mem[i];
                end
            end
            
            2'd2: begin  // Layer 2 active
                // Output 10 weights in parallel for current input
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
