// Single Image Testbench for Synthesis Version
// Tests individual images using embedded BRAM storage
// Compatible with both iVerilog and Vivado Simulator

`timescale 1ns/1ps

module tb_single_img_synth;
    
    // ==========================================
    // TEST CONFIGURATION - MODIFY HERE
    // ==========================================
    parameter TEST_IMG_SEL = 2'b00;  // Change this to test different images
                                      // 00 = Image 0 (digit 6)
                                      // 01 = Image 1 (digit 2)
                                      // 10 = Image 2 (digit 3)
                                      // 11 = Invalid (for testing)
    
    parameter EXPECTED_DIGIT = 6;    // Change based on TEST_IMG_SEL:
                                      // Image 0 expects 6
                                      // Image 1 expects 2
                                      // Image 2 expects 3
    
    // ==========================================
    // Clock and control signals
    // ==========================================
    reg clk;
    reg rst;
    reg start;
    reg [1:0] img_sel;
    
    // Outputs
    wire [3:0] digit;
    wire done;
    wire valid;
    
    // Performance tracking
    integer cycle_count;
    real start_time, end_time;
    integer i;
    
    // ==========================================
    // Clock generation - 100MHz
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // ==========================================
    // DUT instantiation - Synthesis Version
    // ==========================================
    mnist_top_synth dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_sel(img_sel),
        .digit(digit),
        .done(done),
        .valid(valid)
    );
    
    // ==========================================
    // Main test sequence
    // ==========================================
    initial begin
        // Initialize signals
        $display("==========================================");
        $display("MNIST SINGLE IMAGE TEST - SYNTHESIS VERSION");
        $display("==========================================");
        $display("Test Configuration:");
        $display("  Image Selection: %b", TEST_IMG_SEL);
        
        case(TEST_IMG_SEL)
            2'b00: $display("  Selected Image: 0 (embedded test_img0.mem)");
            2'b01: $display("  Selected Image: 1 (embedded test_img1.mem)");
            2'b10: $display("  Selected Image: 2 (embedded test_img2.mem)");
            2'b11: $display("  Selected Image: INVALID (testing error handling)");
        endcase
        
        $display("  Expected Digit: %d", EXPECTED_DIGIT);
        $display("==========================================\n");
        
        rst = 1;
        start = 0;
        img_sel = TEST_IMG_SEL;
        cycle_count = 0;
        
        // Reset sequence
        #100;
        rst = 0;
        #20;
        
        // Check if valid image selected
        $display("Checking image validity...");
        if (valid) begin
            $display("Valid image selected: YES\n");
            
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
            $display("Predicted Digit: %d", digit);
            $display("Expected Digit:  %d", EXPECTED_DIGIT);
            
            if (digit == EXPECTED_DIGIT) begin
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
            if (digit != EXPECTED_DIGIT) begin
                $display("DEBUG INFO:");
                $display("  FSM State: %d", dut.accel.fsm.state);
                $display("  Layer 2 outputs (scores):");
                for (i = 0; i < 10; i = i + 1) begin
                    $display("    Digit %d: %d", i, dut.accel.l2_acc[i]);
                end
                $display("\n");
            end
            
        end else begin
            $display("Valid image selected: NO");
            $display("ERROR: Invalid image selection %b", img_sel);
            $display("Valid selections are: 00, 01, 10");
            
            // Test that start signal is ignored for invalid selection
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait a few cycles to confirm no inference starts
            repeat(100) @(posedge clk);
            
            if (!done) begin
                $display("\nPASS: Inference correctly blocked for invalid selection");
            end else begin
                $display("\nFAIL: Inference should not run for invalid selection");
            end
        end
        
        $display("==========================================");
        $display("TEST COMPLETE");
        $display("==========================================\n");
        
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
        $dumpfile("single_img_synth_test.vcd");
        $dumpvars(0, tb_single_img_synth);
    end
    
    // ==========================================
    // Console message on FPGA inference result
    // ==========================================
    always @(posedge done) begin
        if (done) begin
            $display("\n[FPGA Console Output Expected]:");
            $display("=== FPGA Inference Result ===");
            $display("Test Image: %d", img_sel);
            $display("Expected: %d", dut.exp_label);
            $display("Predicted: %d", digit);
            if (digit == dut.exp_label) begin
                $display("Result: PASS");
            end else begin
                $display("Result: FAIL");
            end
            $display("============================");
        end
    end
    
endmodule
