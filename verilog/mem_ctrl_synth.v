// Memory Controller for Synthesis - BRAM-based weight and bias storage
// Compatible with both simulation and Vivado synthesis
// Uses parameterized paths for flexibility

module mem_ctrl_synth #(
    parameter W1_FILE = "data_mem/w1.mem",
    parameter B1_FILE = "data_mem/b1.mem", 
    parameter W2_FILE = "data_mem/w2.mem",
    parameter B2_FILE = "data_mem/b2.mem"
)(
    input clk,
    input rst,
    
    // Control signals
    input [1:0] layer_sel,          // 0: idle, 1: L1, 2: L2
    input [9:0] row_idx,            // Current input index
    
    // Layer 1 weight outputs (32 parallel outputs)
    output reg signed [7:0] w1_out [0:31],
    output reg signed [7:0] b1_out [0:31],
    
    // Layer 2 weight outputs (10 parallel outputs)
    output reg signed [7:0] w2_out [0:9],
    output reg signed [7:0] b2_out [0:9]
);
    
    // Memory arrays - will infer BRAM in Vivado
    (* ram_style = "block" *) reg signed [7:0] w1_mem [0:25087];  // 784 * 32
    (* ram_style = "block" *) reg signed [7:0] b1_mem [0:31];     // 32 biases
    (* ram_style = "block" *) reg signed [7:0] w2_mem [0:319];    // 32 * 10
    (* ram_style = "block" *) reg signed [7:0] b2_mem [0:9];      // 10 biases
    
    // Initialize memories from mem files
    initial begin
        $readmemh(W1_FILE, w1_mem);
        $readmemh(B1_FILE, b1_mem);
        $readmemh(W2_FILE, w2_mem);
        $readmemh(B2_FILE, b2_mem);
    end
    
    // Address calculation
    wire [14:0] w1_base_addr;
    wire [8:0] w2_base_addr;
    
    assign w1_base_addr = row_idx * 32;
    assign w2_base_addr = row_idx * 10;
    
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
