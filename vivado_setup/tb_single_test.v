`timescale 1ns / 1ps

module tb_single_test;

    // Inputs
    reg clk;
    reg rst;
    reg start;
    
    // Outputs
    wire [3:0] digit;
    wire done;
    wire [7:0] fsm_leds;
    
    // Instantiate the Unit Under Test (UUT)
    mnist_top_synth uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .digit(digit),
        .done(done),
        .fsm_leds(fsm_leds)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // FSM state names for display
    reg [63:0] state_name;
    always @(*) begin
        case(uut.state)
            4'd0: state_name = "IDLE";
            4'd1: state_name = "INIT";
            4'd2: state_name = "L1_COMP";
            4'd3: state_name = "L1_RELU";
            4'd4: state_name = "L2_COMP";
            4'd5: state_name = "ARGMAX";
            4'd6: state_name = "DONE";
            default: state_name = "UNKNOWN";
        endcase
    end
    
    // Monitor important signals
    initial begin
        $monitor("Time=%0t State=%s LEDs=%b digit=%d done=%b", 
                 $time, state_name, fsm_leds, digit, done);
    end
    
    // Test stimulus
    initial begin
        $display("==========================================");
        $display("MNIST Sequential Testbench Started");
        $display("==========================================");
        
        // Initialize
        rst = 1;
        start = 0;
        
        // Wait for memory initialization
        #100;
        
        // Release reset
        rst = 0;
        #20;
        
        $display("\n[TB] Starting inference...");
        
        // Start inference
        start = 1;
        #20;
        start = 0;
        
        // Wait for completion with timeout
        fork
            begin: timeout_block
                #1000000; // 1ms timeout for sequential processing
                $display("\n[TB] ERROR: Timeout - inference did not complete");
                $finish;
            end
            begin: wait_done_block
                @(posedge done);
                disable timeout_block;
            end
        join
        
        if (done) begin
            $display("\n==========================================");
            $display("[TB] Inference Complete!");
            $display("[TB] Predicted digit: %d", digit);
            $display("[TB] Expected digit: 6 (for test_img0.mem)");
            
            if (digit == 6) begin
                $display("[TB] PASS: Correct prediction!");
            end else begin
                $display("[TB] FAIL: Incorrect prediction");
            end
            $display("==========================================");
        end else begin
            $display("\n[TB] ERROR: Timeout - inference did not complete");
        end
        
        #100;
        $finish;
    end
    
    // Optional: Track progress
    integer cycle_count;
    always @(posedge clk) begin
        if (start) cycle_count <= 0;
        else if (!done) cycle_count <= cycle_count + 1;
        
        // Progress indicators for long operations
        if (uut.state == 4'd2 && uut.hid_cnt == 0 && uut.pix_cnt == 0 && uut.cyc_cnt == 0) begin
            $display("[TB] Starting Layer 1 computation...");
        end
        if (uut.state == 4'd4 && uut.out_cnt == 0 && uut.hid_cnt == 0 && uut.cyc_cnt == 0) begin
            $display("[TB] Starting Layer 2 computation...");
        end
        if (uut.state == 4'd5 && uut.cyc_cnt == 0) begin
            $display("[TB] Starting Argmax...");
        end
    end
    
    // Dump waveforms for debugging
    initial begin
        $dumpfile("mnist_test.vcd");
        $dumpvars(0, tb_single_test);
    end

endmodule