// Test sequential implementation
`timescale 1ns/1ps

module tb_sequential;
    
    reg clk;
    reg rst;
    reg start;
    reg [6271:0] img_data;
    wire [3:0] pred_digit;
    wire done;
    
    reg [7:0] test_imgs [0:15679];
    reg [3:0] test_labels [0:19];
    integer i, test_cnt, correct_cnt;
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT - Sequential implementation
    mnist_accel dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .img_data(img_data),
        .pred_digit(pred_digit),
        .done(done)
    );
    
    // Test
    initial begin
        $readmemh("../data/test_imgs.hex", test_imgs);
        test_labels[0] = 4'd6; test_labels[1] = 4'd2; test_labels[2] = 4'd3;
        test_labels[3] = 4'd7; test_labels[4] = 4'd2;
        
        $display("Testing Sequential Implementation:");
        
        rst = 1;
        start = 0;
        img_data = 0;
        correct_cnt = 0;
        #100;
        rst = 0;
        #20;
        
        // Test first 5 images
        for (test_cnt = 0; test_cnt < 5; test_cnt = test_cnt + 1) begin
            // Load image
            for (i = 0; i < 784; i = i + 1) begin
                img_data[i*8 +: 8] = test_imgs[test_cnt * 784 + i];
            end
            
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            @(posedge done);
            
            if (pred_digit == test_labels[test_cnt]) begin
                $display("Test %d: PASS - Pred=%d, Exp=%d", 
                         test_cnt+1, pred_digit, test_labels[test_cnt]);
                correct_cnt = correct_cnt + 1;
            end else begin
                $display("Test %d: FAIL - Pred=%d, Exp=%d",
                         test_cnt+1, pred_digit, test_labels[test_cnt]);
            end
            
            #100;
        end
        
        $display("Sequential: %d/5 correct", correct_cnt);
        #100;
        $finish;
    end
    
endmodule
