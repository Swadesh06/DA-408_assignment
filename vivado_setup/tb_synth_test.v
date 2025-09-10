// Synthesis Version Testbench
// Tests mnist_top_synth module with embedded test images
// For verifying Vivado-compatible code with iVerilog

`timescale 1ns/1ps

module tb_synth_test;
    
    // Clock and control signals
    reg clk;
    reg rst;
    reg start;
    reg [1:0] img_sel;  // Test image selection
    
    // Outputs
    wire [3:0] digit;
    wire done;
    wire valid;
    
    // Test tracking
    integer test_cnt;
    reg [3:0] exp_labels [0:2];  // Expected labels for 3 test images
    
    // Clock generation - 25MHz (matches constraints)
    initial begin
        clk = 0;
        forever #20 clk = ~clk;  // 40ns period = 25MHz
    end
    
    // Expected labels for the 3 test images
    initial begin
        exp_labels[0] = 4'd6;  // First image is digit 6
        exp_labels[1] = 4'd2;  // Second image is digit 2
        exp_labels[2] = 4'd3;  // Third image is digit 3
    end
    
    // DUT instantiation - synthesis version
    mnist_top_synth dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_sel(img_sel),
        .digit(digit),
        .done(done),
        .valid(valid)
    );
    
    // Main test sequence
    initial begin
        $display("==========================================");
        $display("SYNTHESIS VERSION TEST");
        $display("==========================================");
        $display("Testing mnist_top_synth with embedded images");
        $display("Compatible with both iVerilog and Vivado");
        $display("==========================================\n");
        
        // Initialize
        rst = 1;
        start = 0;
        img_sel = 2'b00;
        test_cnt = 0;
        
        #100;
        rst = 0;
        #20;
        
        // Debug: Check if memories are loaded properly
        $display("\n=== MEMORY DEBUG INFO ===");
        $display("First few W1 weights: %h %h %h %h", 
                dut.accel.memory.w1_mem[0], dut.accel.memory.w1_mem[1], 
                dut.accel.memory.w1_mem[2], dut.accel.memory.w1_mem[3]);
        $display("First few test image pixels: %h %h %h %h",
                dut.test_imgs[0], dut.test_imgs[1], dut.test_imgs[2], dut.test_imgs[3]);
        
        if (dut.accel.memory.w1_mem[0] === 8'hxx || dut.accel.memory.w1_mem[0] === 8'h00) begin
            $display("WARNING: W1 weights appear uninitialized!");
        end else begin
            $display("SUCCESS: W1 weights loaded correctly");
        end
        
        if (dut.test_imgs[0] === 8'hxx || dut.test_imgs[0] === 8'h00) begin
            $display("WARNING: Test images appear uninitialized!");
        end else begin
            $display("SUCCESS: Test images loaded correctly");
        end
        $display("========================\n");
        
        // Test all 3 embedded images
        for (test_cnt = 0; test_cnt < 3; test_cnt = test_cnt + 1) begin
            $display("Testing image %d...", test_cnt);
            
            // Select image
            img_sel = test_cnt[1:0];
            #10;
            
            // Check if valid and run test
            if (!valid) begin
                $display("ERROR: Invalid image selection %d", img_sel);
            end else begin
                // Start inference
                @(posedge clk);
                start = 1;
                @(posedge clk);
                start = 0;
                
                // Wait for completion
                @(posedge done);
                @(posedge clk);  // Stabilize result
                
                // Check result
                if (digit == exp_labels[test_cnt]) begin
                    $display("Test %d: PASS - Predicted: %d, Expected: %d", 
                            test_cnt, digit, exp_labels[test_cnt]);
                end else begin
                    $display("Test %d: FAIL - Predicted: %d, Expected: %d", 
                            test_cnt, digit, exp_labels[test_cnt]);
                end
                
                // Wait for FSM to return to idle
                wait(!done);
            end
            #100;
        end
        
        // Test invalid image selection
        $display("\nTesting invalid image selection...");
        img_sel = 2'b11;  // Invalid selection
        #10;
        
        if (!valid) begin
            $display("PASS: Invalid selection correctly detected");
        end else begin
            $display("FAIL: Invalid selection not detected");
        end
        
        $display("\n==========================================");
        $display("SYNTHESIS VERSION TEST COMPLETE");
        $display("==========================================\n");
        
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #30000000;  // 30ms timeout for 3 images
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Optional: VCD dump
    initial begin
        $dumpfile("synth_test.vcd");
        $dumpvars(0, tb_synth_test);
    end
    
endmodule
