// MNIST Top Module for FPGA Synthesis
// Includes test image storage in BRAM for hardware testing
// Supports 3 test images selectable via switches

module mnist_top_synth (
    input clk,
    input rst,           // btnC - center button
    input start,         // btnU - up button  
    input [1:0] img_sel, // SW[1:0] - select test image (0-2)
    
    output [3:0] digit,  // LED[15:12] - predicted digit
    output done,         // LED[0] - inference complete
    output valid         // LED[1] - valid image selected
);
    
    // Network parameters
    localparam IMG_SIZE = 784;
    localparam NUM_IMGS = 3;
    
    // Test image storage in BRAM
    (* ram_style = "block" *) reg [7:0] test_imgs [0:2351]; // 3 * 784
    reg [3:0] test_labels [0:2];
    
    // Initialize test images and labels
    initial begin
        // Load 3 test images
        $readmemh("test_img0.mem", test_imgs, 0, 783);
        $readmemh("test_img1.mem", test_imgs, 784, 1567);
        $readmemh("test_img2.mem", test_imgs, 1568, 2351);
        
        // Hardcode labels for the 3 test images
        test_labels[0] = 4'd6;  // First image is digit 6
        test_labels[1] = 4'd2;  // Second image is digit 2  
        test_labels[2] = 4'd3;  // Third image is digit 3
        
        // Debug: Print first few pixels of each image
        $display("[TOP_MODULE] Test images loaded:");
        $display("[TOP_MODULE] Image 0 pixels[0:3] = %h %h %h %h", test_imgs[0], test_imgs[1], test_imgs[2], test_imgs[3]);
        $display("[TOP_MODULE] Image 1 pixels[0:3] = %h %h %h %h", test_imgs[784], test_imgs[785], test_imgs[786], test_imgs[787]);
        $display("[TOP_MODULE] Image 2 pixels[0:3] = %h %h %h %h", test_imgs[1568], test_imgs[1569], test_imgs[1570], test_imgs[1571]);
    end
    
    // Image data preparation
    reg [6271:0] img_data;
    reg [3:0] exp_label;
    wire [3:0] pred_digit;
    
    // Valid image selection
    assign valid = (img_sel < NUM_IMGS);
    
    // Load selected image into img_data
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            img_data <= 0;
            exp_label <= 0;
        end else if (start && valid) begin
            // Load selected image
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img_data[i*8 +: 8] <= test_imgs[img_sel * IMG_SIZE + i];
            end
            exp_label <= test_labels[img_sel];
        end
    end
    
    // Instantiate accelerator with synthesis-compatible memory controller
    mnist_accel_synth accel (
        .clk(clk),
        .rst(rst),
        .start(start & valid),
        .img_data(img_data),
        .pred_digit(pred_digit),
        .done(done)
    );
    
    // Output predicted digit
    assign digit = pred_digit;
    
    // Debug output for Vivado console (synthesis will optimize away)
    always @(posedge done) begin
        if (done) begin
            $display("=== FPGA Inference Result ===");
            $display("Test Image: %d", img_sel);
            $display("Expected: %d", exp_label);
            $display("Predicted: %d", pred_digit);
            if (pred_digit == exp_label) begin
                $display("Result: PASS");
            end else begin
                $display("Result: FAIL");
            end
            $display("============================");
        end
    end
    
endmodule

// Modified accelerator using synthesis-compatible memory controller
module mnist_accel_synth (
    input clk,
    input rst,
    input start,
    input [6271:0] img_data,
    
    output [3:0] pred_digit,
    output done
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
    
    // Memory interface signals - packed from mem_ctrl_synth
    wire [255:0] w1_out_packed;  // 32 * 8 bits
    wire [255:0] b1_out_packed;  // 32 * 8 bits
    wire [79:0] w2_out_packed;   // 10 * 8 bits
    wire [79:0] b2_out_packed;   // 10 * 8 bits
    
    // Unpack for internal use by other modules
    wire signed [7:0] w1_out [0:31];
    wire signed [7:0] b1_out [0:31];
    wire signed [7:0] w2_out [0:9];
    wire signed [7:0] b2_out [0:9];
    
    generate
        genvar m;
        for (m = 0; m < 32; m = m + 1) begin : unpack_w1_b1
            assign w1_out[m] = w1_out_packed[m*8 +: 8];
            assign b1_out[m] = b1_out_packed[m*8 +: 8];
        end
        for (m = 0; m < 10; m = m + 1) begin : unpack_w2_b2
            assign w2_out[m] = w2_out_packed[m*8 +: 8];
            assign b2_out[m] = b2_out_packed[m*8 +: 8];
        end
    endgenerate
    
    // Image buffer
    reg signed [7:0] img [0:783];
    wire signed [7:0] curr_pixel;
    
    // Layer 1 signals
    wire signed [19:0] l1_acc [0:31];
    wire signed [7:0] l1_act [0:31];
    reg signed [7:0] l1_act_reg [0:31];
    
    // Packed signals for module interfaces (Vivado synthesis compatibility)
    wire [639:0] l1_acc_packed;  // 32 * 20 bits = 640 bits (from MAC L1)
    wire [255:0] l1_act_packed;  // 32 * 8 bits = 256 bits (from ReLU)
    
    // Unpack signals for internal use
    generate
        genvar n;
        for (n = 0; n < 32; n = n + 1) begin : unpack_l1_signals
            assign l1_acc[n] = l1_acc_packed[n*20 +: 20];
            assign l1_act[n] = l1_act_packed[n*8 +: 8];
        end
    endgenerate
    
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
    assign curr_pixel = (comp_l1 && row_idx < IMG_SIZE) ? img[row_idx] : 8'sd0;
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img[i] <= 8'sd0;
            end
        end else if (load_img) begin
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img[i] <= img_data[i*8 +: 8];
            end
        end
    end
    
    // Layer 1 activation register
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
            for (i = 0; i < HID_SIZE; i = i + 1) begin
                l1_act_reg[i] <= l1_act[i];
            end
        end
    end
    
    // Layer 2 activation selection
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
            if (comp_l1 && !l1_bias_done) begin
                mac_l1_init_bias <= 1'b1;
            end else begin
                mac_l1_init_bias <= 1'b0;
            end
            
            if (mac_l1_init_bias) begin
                l1_bias_done <= 1'b1;
            end else if (!comp_l1) begin
                l1_bias_done <= 1'b0;
            end
            
            if (apply_relu && !l2_bias_done) begin
                mac_l2_init_bias <= 1'b1;
            end else begin
                mac_l2_init_bias <= 1'b0;
            end
            
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
    
    // Memory Controller with synthesis paths
    mem_ctrl_synth memory (
        .clk(clk),
        .rst(rst),
        .layer_sel(layer_sel),
        .row_idx(row_idx),
        .w1_out_packed(w1_out_packed),
        .b1_out_packed(b1_out_packed),
        .w2_out_packed(w2_out_packed),
        .b2_out_packed(b2_out_packed)
    );
    
    // MAC Array Layer 1
    mac_array_l1 mac_l1 (
        .clk(clk),
        .rst(rst),
        .en(mac_en_l1),
        .clr(mac_clr_l1),
        .init_bias(mac_l1_init_bias),
        .pixel(curr_pixel),
        .weights_packed(w1_out_packed),
        .biases_packed(b1_out_packed),
        .acc_out_packed(l1_acc_packed)
    );
    
    // ReLU Unit
    relu_unit relu (
        .clk(clk),
        .rst(rst),
        .en(apply_relu),
        .z_in_packed(l1_acc_packed),
        .a_out_packed(l1_act_packed)
    );
    
    // Packed signal for Layer 2 output (from MAC to argmax)
    wire [199:0] l2_acc_packed;  // 10 * 20 bits = 200 bits
    
    // Unpack l2_acc from packed version for internal use
    generate
        genvar j;
        for (j = 0; j < 10; j = j + 1) begin : unpack_l2_acc
            assign l2_acc[j] = l2_acc_packed[j*20 +: 20];
        end
    endgenerate
    
    // MAC Array Layer 2
    mac_array_l2 mac_l2 (
        .clk(clk),
        .rst(rst),
        .en(mac_en_l2),
        .clr(mac_clr_l2),
        .init_bias(mac_l2_init_bias),
        .activation(curr_act),
        .weights_packed(w2_out_packed),
        .biases_packed(b2_out_packed),
        .acc_out_packed(l2_acc_packed)
    );
    
    // Argmax unit
    wire [3:0] argmax_comb;
    argmax_unit argmax (
        .scores_packed(l2_acc_packed),
        .max_idx(argmax_comb)
    );
    
    // Register argmax result
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
