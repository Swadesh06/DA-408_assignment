// MNIST Hardware Accelerator Top Module
// Test image loaded from test_img0.mem (change line 24 for different images)

module mnist_top_synth (
    input clk,
    input rst,
    input start,
    output [3:0] digit,
    output done,
    output reg [7:0] fsm_leds  // FSM state monitoring LEDs
);

    localparam IMG_SIZE = 784;

    // Memory for test image - will infer appropriate storage
    reg [7:0] test_img [0:783];  // 784 pixels
    reg [3:0] test_label;

    // Single initial block for memory loading (inspired by friend's approach)
    initial begin
        // Load test image
        $readmemh("test_img0.mem", test_img);
        test_label = 4'd6;  // Expected label for test_img0
        
        $display("==========================================");
        $display("[TOP_MODULE] MNIST Image Loading");
        $display("==========================================");
        $display("Image file: test_img0.mem");
        $display("Expected digit: %d", test_label);
        $display("Sample pixels [0:7]: %h %h %h %h %h %h %h %h", 
                test_img[0], test_img[1], test_img[2], test_img[3],
                test_img[4], test_img[5], test_img[6], test_img[7]);
        $display("Sample pixels [392:399]: %h %h %h %h %h %h %h %h",
                test_img[392], test_img[393], test_img[394], test_img[395],
                test_img[396], test_img[397], test_img[398], test_img[399]);
        
        // Verify non-zero content
        if (test_img[0] == 0 && test_img[1] == 0 && test_img[100] == 0 && test_img[200] == 0) begin
            $display("WARNING: Image appears to be mostly zeros - verify file loading");
        end else begin
            $display("SUCCESS: Image contains non-zero data");
        end
        $display("==========================================");
    end

    reg [6271:0] img_data;
    wire [3:0] pred_digit;

    // Pack test image into img_data on start signal
    integer i;
    reg start_prev;
    always @(posedge clk) begin
        start_prev <= start;
        if (rst) begin
            img_data <= 0;
        end else if (start) begin
            for (i = 0; i < IMG_SIZE; i = i + 1) begin
                img_data[i*8 +: 8] <= test_img[i];
            end
            // Debug image transfer on start edge
            if (!start_prev) begin
                $display("[IMG_TRANSFER] Packing image data for inference");
                $display("[IMG_TRANSFER] Source pixels [0:7]: %h %h %h %h %h %h %h %h",
                        test_img[0], test_img[1], test_img[2], test_img[3],
                        test_img[4], test_img[5], test_img[6], test_img[7]);
            end
        end
    end

    mnist_accel_synth accel (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_data(img_data),
        .pred_digit(pred_digit),
        .done(done)
    );

    assign digit = pred_digit;
    
    // FSM State Monitoring - Progressive LED pattern
    // Each LED turns on as FSM reaches that state and stays on until reset
    wire [3:0] fsm_state;
    assign fsm_state = accel.fsm.state;
    
    always @(posedge clk) begin
        if (rst) begin
            fsm_leds <= 8'b00000000;  // All LEDs off on reset
        end else begin
            // Progressive pattern - LEDs accumulate as FSM progresses
            case (fsm_state)
                4'd0: fsm_leds <= fsm_leds;           // IDLE - keep current
                4'd1: fsm_leds[0] <= 1'b1;            // INIT reached
                4'd2: fsm_leds[1] <= 1'b1;            // LOAD_IMG reached
                4'd3: fsm_leds[2] <= 1'b1;            // L1_COMP reached
                4'd4: fsm_leds[3] <= 1'b1;            // L1_RELU reached
                4'd5: fsm_leds[4] <= 1'b1;            // L2_COMP reached
                4'd6: fsm_leds[5] <= 1'b1;            // ARGMAX reached
                4'd7: fsm_leds[6] <= 1'b1;            // DONE reached
                default: fsm_leds <= fsm_leds;        // Hold current state
            endcase
        end
    end

endmodule

// MNIST Accelerator Core
module mnist_accel_synth (
    input clk,
    input rst,
    input start,
    input [6271:0] img_data,
    output [3:0] pred_digit,
    output done
);

    localparam IMG_SIZE = 784;
    localparam HID_SIZE = 32;
    localparam OUT_SIZE = 10;

    // Control signals
    wire busy;
    wire [1:0] layer_sel;
    wire [9:0] row_idx;
    wire mac_en_l1, mac_clr_l1;
    wire mac_en_l2, mac_clr_l2;
    wire load_img, comp_l1, apply_relu, comp_l2, find_max;
    wire [9:0] cycle_cnt;

    // Memory interface (packed for synthesis)
    wire [255:0] w1_out_packed, b1_out_packed;
    wire [79:0] w2_out_packed, b2_out_packed;

    // Unpacked weights and biases
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
            // Debug image loading into accelerator
            $display("[ACCEL] Image loaded into accelerator");
            $display("[ACCEL] Sample pixels from img_data: %h %h %h %h",
                    img_data[400*8 +: 8], img_data[401*8 +: 8],
                    img_data[402*8 +: 8], img_data[403*8 +: 8]);
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

            if (comp_l2 && !l2_bias_done) begin
                mac_l2_init_bias <= 1'b1;
            end else begin
                mac_l2_init_bias <= 1'b0;
            end

            if (mac_l2_init_bias) begin
                l2_bias_done <= 1'b1;
            end else if (!comp_l2) begin
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

    // Initialize and latch prediction result
    always @(posedge clk) begin
        if (rst) begin
            argmax_idx <= 4'd15;  // Initialize to all 1s (debug: if LEDs stay 1111, memory failed)
        end else if (find_max) begin
            argmax_idx <= argmax_comb;
        end
        // Hold value between predictions
    end

    // Output assignment - always show latest available prediction
    assign pred_digit = argmax_idx;

endmodule
