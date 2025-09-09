// MNIST Top Module - Parallel Hardware Accelerator
// Integrates all components for parallel neural network inference
// Architecture: 784-32-10 fully connected network with Int8 quantization
// Performance: ~820 cycles per inference (31x speedup over sequential)

module mnist_top (
    input clk,
    input rst,
    input start,
    input [6271:0] img_data,        // 784 pixels * 8 bits = 6272 bits
    
    output [3:0] pred_digit,         // Predicted digit (0-9)
    output done                      // Inference complete flag
);
    
    // Network parameters
    localparam IMG_SIZE = 784;
    localparam HID_SIZE = 32;
    localparam OUT_SIZE = 10;
    
    // Control signals from FSM
    wire busy;
    wire [1:0] layer_sel;
    wire [9:0] row_idx;
    wire mac_en_l1, mac_clr_l1;
    wire mac_en_l2, mac_clr_l2;
    wire load_img, comp_l1, apply_relu, comp_l2, find_max;
    wire [9:0] cycle_cnt;
    
    // Memory interface signals
    wire signed [7:0] w1_out [0:31];
    wire signed [7:0] b1_out [0:31];
    wire signed [7:0] w2_out [0:9];
    wire signed [7:0] b2_out [0:9];
    
    // Image buffer
    reg signed [7:0] img [0:783];
    wire signed [7:0] curr_pixel;
    
    // Layer 1 signals
    wire signed [19:0] l1_acc [0:31];
    wire signed [7:0] l1_act [0:31];
    reg signed [7:0] l1_act_reg [0:31];
    
    // Layer 2 signals
    wire signed [19:0] l2_acc [0:9];
    wire signed [7:0] curr_act;
    
    // Output signals
    reg [3:0] argmax_idx;
    
    // Control signals for MAC arrays
    reg mac_l1_init_bias;
    reg mac_l2_init_bias;
    
    integer i;
    
    // Image loading and pixel selection
    // Combinational pixel selection for immediate response
    assign curr_pixel = (comp_l1 && row_idx < IMG_SIZE) ? img[row_idx] : 8'sd0;
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img[i] <= 8'sd0;
            end
        end else if (load_img) begin
            // Load entire image in single cycle
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img[i] <= img_data[i*8 +: 8];
            end
        end
    end
    
    // Layer 1 activation register - store AFTER ReLU computes
    reg prev_apply_relu;
    always @(posedge clk) begin
        prev_apply_relu <= apply_relu;
    end
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < HID_SIZE; i = i + 1) begin
                l1_act_reg[i] <= 8'sd0;
            end
        end else if (prev_apply_relu && !apply_relu) begin
            // Store ReLU outputs on falling edge of apply_relu
            // This ensures ReLU has computed and output is stable
            for (i = 0; i < HID_SIZE; i = i + 1) begin
                l1_act_reg[i] <= l1_act[i];
            end
        end
    end
    
    // Layer 2 activation selection (combinational)
    assign curr_act = (comp_l2 && row_idx < HID_SIZE) ? l1_act_reg[row_idx] : 8'sd0;
    
    // Bias initialization control
    reg l1_bias_done;
    reg l2_bias_done;
    
    always @(posedge clk) begin
        if (rst) begin
            mac_l1_init_bias <= 1'b0;
            mac_l2_init_bias <= 1'b0;
            l1_bias_done <= 1'b0;
            l2_bias_done <= 1'b0;
        end else begin
            // Initialize L1 MACs with biases at START of L1_COMP
            if (comp_l1 && !l1_bias_done) begin
                mac_l1_init_bias <= 1'b1;
            end else begin
                mac_l1_init_bias <= 1'b0;
            end
            
            // Track bias init completion
            if (mac_l1_init_bias) begin
                l1_bias_done <= 1'b1;
            end else if (!comp_l1) begin
                l1_bias_done <= 1'b0;  // Reset when not in L1_COMP
            end
            
            // Initialize L2 MACs with biases during L1_RELU, complete before L2_COMP
            if (apply_relu && !l2_bias_done) begin
                mac_l2_init_bias <= 1'b1;
            end else begin
                mac_l2_init_bias <= 1'b0;
            end
            
            // Track L2 bias init completion
            if (mac_l2_init_bias) begin
                l2_bias_done <= 1'b1;
            end else if (apply_relu && l2_bias_done) begin
                l2_bias_done <= 1'b1;
            end else if (!apply_relu) begin
                l2_bias_done <= 1'b0;
            end
        end
    end
    
    // Module instantiations
    
    // Control FSM
    ctrl_fsm fsm (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .busy(busy),
        .layer_sel(layer_sel),
        .row_idx(row_idx),
        .mac_en_l1(mac_en_l1),
        .mac_clr_l1(mac_clr_l1),
        .mac_en_l2(mac_en_l2),
        .mac_clr_l2(mac_clr_l2),
        .load_img(load_img),
        .comp_l1(comp_l1),
        .apply_relu(apply_relu),
        .comp_l2(comp_l2),
        .find_max(find_max),
        .cycle_cnt(cycle_cnt)
    );
    
    // Memory Controller
    mem_ctrl memory (
        .clk(clk),
        .rst(rst),
        .layer_sel(layer_sel),
        .row_idx(row_idx),
        .w1_out(w1_out),
        .b1_out(b1_out),
        .w2_out(w2_out),
        .b2_out(b2_out)
    );
    
    // MAC Array Layer 1 (32 parallel MACs)
    mac_array_l1 mac_l1 (
        .clk(clk),
        .rst(rst),
        .en(mac_en_l1),
        .clr(mac_clr_l1),
        .init_bias(mac_l1_init_bias),
        .pixel(curr_pixel),
        .weights(w1_out),
        .biases(b1_out),
        .acc_out(l1_acc)
    );
    
    // ReLU Unit
    relu_unit relu (
        .clk(clk),
        .rst(rst),
        .en(apply_relu),
        .z_in(l1_acc),
        .a_out(l1_act)
    );
    
    // MAC Array Layer 2 (10 parallel MACs)
    mac_array_l2 mac_l2 (
        .clk(clk),
        .rst(rst),
        .en(mac_en_l2),
        .clr(mac_clr_l2),
        .init_bias(mac_l2_init_bias),
        .activation(curr_act),
        .weights(w2_out),
        .biases(b2_out),
        .acc_out(l2_acc)
    );
    
    // Argmax unit - purely combinational
    wire [3:0] argmax_comb;
    argmax_unit argmax (
        .scores(l2_acc),
        .max_idx(argmax_comb)
    );
    
    // Register argmax result when find_max is asserted
    always @(posedge clk) begin
        if (rst) begin
            argmax_idx <= 4'd0;
        end else if (find_max) begin
            argmax_idx <= argmax_comb;
        end
    end
    
    // Output assignment
    assign pred_digit = argmax_idx;
    
endmodule
