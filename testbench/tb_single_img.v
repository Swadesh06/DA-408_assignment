// Single Image Testbench for MNIST Accelerator
// Tests individual images with easy modification
// Compatible with both iVerilog and Vivado Simulator

`timescale 1ns/1ps

module tb_single_img;
    
    // ==========================================
    // TEST CONFIGURATION - MODIFY HERE
    // ==========================================
    parameter TEST_IMG_IDX = 0;  // Change this to test different images (0-19)
    parameter IMG_FILE = "data_mem/test_img0.mem";  // Path to image file
    parameter EXPECTED_DIGIT = 6;  // Expected result for this image
    
    // ==========================================
    // Clock and control signals
    // ==========================================
    reg clk;
    reg rst;
    reg start;
    
    // Image data
    reg [6271:0] img_data;  // 784 * 8 bits
    
    // Outputs
    wire [3:0] pred_digit;
    wire done;
    
    // Test data storage
    reg [7:0] test_img [0:783];  // Single image
    integer i;
    
    // Performance tracking
    integer cycle_count;
    real start_time, end_time;
    
    // ==========================================
    // Clock generation - 100MHz
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // ==========================================
    // DUT instantiation
    // ==========================================
    mnist_top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_data(img_data),
        .pred_digit(pred_digit),
        .done(done)
    );
    
    // ==========================================
    // Load test image from file
    // ==========================================
    initial begin
        // Load single test image
        $readmemh(IMG_FILE, test_img);
        
        // Verify image loaded correctly
        $display("Loaded test image from: %s", IMG_FILE);
        $display("First 10 pixels (hex): %02h %02h %02h %02h %02h %02h %02h %02h %02h %02h",
                test_img[0], test_img[1], test_img[2], test_img[3], test_img[4],
                test_img[5], test_img[6], test_img[7], test_img[8], test_img[9]);
    end
    
    // ==========================================
    // Main test sequence
    // ==========================================
    initial begin
        // Initialize signals
        $display("==========================================");
        $display("MNIST SINGLE IMAGE TEST");
        $display("==========================================");
        $display("Test Configuration:");
        $display("  Image Index: %d", TEST_IMG_IDX);
        $display("  Image File: %s", IMG_FILE);
        $display("  Expected Digit: %d", EXPECTED_DIGIT);
        $display("==========================================\n");
        
        rst = 1;
        start = 0;
        img_data = 0;
        cycle_count = 0;
        
        // Reset sequence
        #100;
        rst = 0;
        #20;
        
        // Load image data into flattened vector
        $display("Loading image data...");
        for (i = 0; i < 784; i = i + 1) begin
            img_data[i*8 +: 8] = test_img[i];
        end
        
        // Start inference
        $display("Starting inference...\n");
        start_time = $realtime;
        
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Count cycles during inference
        fork
            begin
                while (!done) begin
                    @(posedge clk);
                    cycle_count = cycle_count + 1;
                end
            end
        join
        
        // Wait for result to stabilize
        @(posedge clk);
        end_time = $realtime;
        
        // Display results
        $display("==========================================");
        $display("INFERENCE COMPLETE");
        $display("==========================================");
        $display("Predicted Digit: %d", pred_digit);
        $display("Expected Digit:  %d", EXPECTED_DIGIT);
        
        if (pred_digit == EXPECTED_DIGIT) begin
            $display("Result: PASS");
        end else begin
            $display("Result: FAIL");
        end
        
        $display("------------------------------------------");
        $display("Performance Metrics:");
        $display("  Inference Cycles: %d", cycle_count);
        $display("  Inference Time: %.2f ns", end_time - start_time);
        $display("  Clock Frequency: 100 MHz");
        $display("  Real Time: %.2f us", (end_time - start_time) / 1000);
        $display("==========================================\n");
        
        // Additional debug info if needed
        if (pred_digit != EXPECTED_DIGIT) begin
            $display("DEBUG INFO:");
            $display("  FSM State: %d", dut.fsm.state);
            $display("  Layer 2 outputs (scores):");
            for (i = 0; i < 10; i = i + 1) begin
                $display("    Digit %d: %d", i, dut.l2_acc[i]);
            end
            $display("\n");
        end
        
        #100;
        $finish;
    end
    
    // ==========================================
    // Timeout watchdog
    // ==========================================
    initial begin
        #10000000;  // 10ms timeout
        $display("ERROR: Simulation timeout!");
        $display("Inference did not complete within 10ms");
        $finish;
    end
    
    // ==========================================
    // Optional: Waveform dump for debugging
    // ==========================================
    initial begin
        $dumpfile("single_img_test.vcd");
        $dumpvars(0, tb_single_img);
    end
    
endmodule
