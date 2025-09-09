// Corrected testbench with proper timing
`timescale 1ns/1ps

module tb_mnist_corrected;
    
    // Clock and reset
    reg clk;
    reg rst;
    reg start;
    
    // Image data (flattened to single vector)
    reg [6271:0] img_data;  // 784 * 8 bits
    
    // Outputs
    wire [3:0] pred_digit;
    wire done;
    
    // Test variables
    integer test_cnt;
    integer correct_cnt;
    integer total_tests;
    reg [7:0] test_imgs [0:15679];  // 20 images * 784 pixels
    reg [3:0] test_labels [0:19];    // 20 labels
    integer i, j;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // DUT instantiation
    mnist_top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_data(img_data),
        .pred_digit(pred_digit),
        .done(done)
    );
    
    // Load test data
    initial begin
        // Load test images
        $readmemh("../data/test_imgs.hex", test_imgs);
        
        // Load test labels
        test_labels[0] = 4'd6; test_labels[1] = 4'd2; test_labels[2] = 4'd3; test_labels[3] = 4'd7; test_labels[4] = 4'd2;
        test_labels[5] = 4'd2; test_labels[6] = 4'd3; test_labels[7] = 4'd4; test_labels[8] = 4'd7; test_labels[9] = 4'd6;
        test_labels[10] = 4'd6; test_labels[11] = 4'd9; test_labels[12] = 4'd2; test_labels[13] = 4'd0; test_labels[14] = 4'd9;
        test_labels[15] = 4'd6; test_labels[16] = 4'd8; test_labels[17] = 4'd0; test_labels[18] = 4'd6; test_labels[19] = 4'd5;
    end
    
    // Test sequence
    initial begin
        // Initialize
        $display("========================================");
        $display("Accelerator");
        $display("========================================");
        $display("Fixed: Proper result timing");
        $display("Starting inference tests...\n");
        
        rst = 1;
        start = 0;
        test_cnt = 0;
        correct_cnt = 0;
        total_tests = 20;
        img_data = 0;
        
        #100;
        rst = 0;
        #20;
        
        // Run tests on all images
        for (test_cnt = 0; test_cnt < total_tests; test_cnt = test_cnt + 1) begin
            // Load image data into flattened vector
            for (i = 0; i < 784; i = i + 1) begin
                img_data[i*8 +: 8] = test_imgs[test_cnt * 784 + i];
            end
            
            // Start inference
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait for completion
            @(posedge done);

            // The argmax_idx updates on the same edge as done, so we need
            // to wait for the next clock edge for the result to be stable
            @(posedge clk);
            
            // Now read the stable result
            if (pred_digit == test_labels[test_cnt]) begin
                $display("Test %2d: PASS - Predicted: %d, Expected: %d", 
                        test_cnt + 1, pred_digit, test_labels[test_cnt]);
                correct_cnt = correct_cnt + 1;
            end else begin
                $display("Test %2d: FAIL - Predicted: %d, Expected: %d", 
                        test_cnt + 1, pred_digit, test_labels[test_cnt]);
            end
            
            // Wait for FSM to return to IDLE  
            wait(dut.fsm.state == 0);
            #100;  // Additional delay before next test
        end
        
        // Display final results
        $display("\n========================================");
        $display("FINAL RESULTS:");
        $display("Total Tests: %d", total_tests);
        $display("Correct: %d", correct_cnt);
        $display("Accuracy: %d%%", (correct_cnt * 100) / total_tests);
        $display("========================================\n");
        #100;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #200000000;  // 200ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
