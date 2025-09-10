// Argmax Unit - Parallel comparator for finding maximum of 10 outputs
// Purely combinational for immediate result
// Synthesizable for Basys3 FPGA

module argmax_unit (
    input [199:0] scores_packed,            // 10 * 20-bit scores packed together
    output wire [3:0] max_idx               // Index of maximum (0-9)
);
    
    // Unpack input scores for internal use
    wire signed [19:0] scores [0:9];
    generate
        genvar i;
        for (i = 0; i < 10; i = i + 1) begin : unpack_scores
            assign scores[i] = scores_packed[i*20 +: 20];
        end
    endgenerate
    
    // Combinational logic for argmax computation
    reg signed [19:0] max_val;
    reg [3:0] computed_idx;
    
    // Purely combinational argmax computation
    always @(*) begin
        // Initialize with first value
        max_val = scores[0];
        computed_idx = 4'd0;
        
        // Parallel comparison - fully unrolled for synthesis
        if (scores[1] > max_val) begin max_val = scores[1]; computed_idx = 4'd1; end
        if (scores[2] > max_val) begin max_val = scores[2]; computed_idx = 4'd2; end
        if (scores[3] > max_val) begin max_val = scores[3]; computed_idx = 4'd3; end
        if (scores[4] > max_val) begin max_val = scores[4]; computed_idx = 4'd4; end
        if (scores[5] > max_val) begin max_val = scores[5]; computed_idx = 4'd5; end
        if (scores[6] > max_val) begin max_val = scores[6]; computed_idx = 4'd6; end
        if (scores[7] > max_val) begin max_val = scores[7]; computed_idx = 4'd7; end
        if (scores[8] > max_val) begin max_val = scores[8]; computed_idx = 4'd8; end
        if (scores[9] > max_val) begin max_val = scores[9]; computed_idx = 4'd9; end
    end
    
    // Combinational output
    assign max_idx = computed_idx;
    
endmodule
