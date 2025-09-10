// Single Image Testbench - Simplified for Vivado
// Tests only test_img0 (digit 6) with no selection logic
// Fully compatible with Vivado simulation

`timescale 1ns/1ps

module tb_single_test;
    
    // ==========================================
    // Clock and control signals
    // ==========================================
    reg clk;
    reg rst;
    reg start;
    
    // Outputs
    wire [3:0] digit;
    wire done;
    
    // Expected result
    localparam EXPECTED_DIGIT = 4'd6;  // test_img0 is digit 6
    
    // Performance tracking
    reg [31:0] cycle_count;
    reg [31:0] wait_count;
    
    // Test state
    localparam IDLE      = 3'd0;
    localparam RESET     = 3'd1;
    localparam START_INF = 3'd2;
    localparam WAIT_DONE = 3'd3;
    localparam CHECK     = 3'd4;
    localparam FINISHED  = 3'd5;
    
    reg [2:0] state;
    
    // ==========================================
    // Clock generation - 25MHz (matches constraints)
    // ==========================================
    initial begin
        clk = 0;
        forever #20 clk = ~clk;  // 40ns period = 25MHz
    end
    
    // ==========================================
    // DUT instantiation - Simplified version
    // ==========================================
    mnist_top_synth dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .digit(digit),
        .done(done)
    );
    
    // ==========================================
    // Initialize signals
    // ==========================================
    initial begin
        $display("==========================================");
        $display("SINGLE IMAGE TEST - VIVADO COMPATIBLE");
        $display("==========================================");
        $display("Testing mnist_top_synth with test_img0");
        $display("Expected digit: %d", EXPECTED_DIGIT);
        $display("==========================================\n");
        
        // Initialize all signals
        rst = 1;
        start = 0;
        state = IDLE;
        cycle_count = 0;
        wait_count = 0;
        
        // Generate VCD for debugging
        $dumpfile("single_test.vcd");
        $dumpvars(0, tb_single_test);
    end
    
    // ==========================================
    // Main test state machine
    // ==========================================
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                // Wait a few cycles then reset
                if (wait_count < 10) begin
                    wait_count <= wait_count + 1;
                end else begin
                    wait_count <= 0;
                    rst <= 0;
                    state <= RESET;
                    
                    // Check memory initialization
                    $display("\n=== MEMORY CHECK ===");
                    $display("W1[0:3] = %h %h %h %h", 
                            dut.accel.memory.w1_mem[0], dut.accel.memory.w1_mem[1],
                            dut.accel.memory.w1_mem[2], dut.accel.memory.w1_mem[3]);
                    $display("B1[0:3] = %h %h %h %h",
                            dut.accel.memory.b1_mem[0], dut.accel.memory.b1_mem[1],
                            dut.accel.memory.b1_mem[2], dut.accel.memory.b1_mem[3]);
                    $display("Test img[0:7] = %h %h %h %h %h %h %h %h",
                            dut.test_img[0], dut.test_img[1], dut.test_img[2], dut.test_img[3],
                            dut.test_img[4], dut.test_img[5], dut.test_img[6], dut.test_img[7]);
                    
                    // Check for uninitialized memory
                    if (dut.accel.memory.w1_mem[0] === 8'hxx) begin
                        $display("ERROR: Weights not loaded!");
                    end else if (dut.accel.memory.w1_mem[0] === 8'h00 && 
                               dut.accel.memory.w1_mem[1] === 8'h00 &&
                               dut.accel.memory.w1_mem[2] === 8'h00) begin
                        $display("WARNING: Weights might be all zeros!");
                    end else begin
                        $display("SUCCESS: Weights loaded correctly");
                    end
                    $display("====================\n");
                end
            end
            
            RESET: begin
                // Wait after reset before starting
                if (wait_count < 5) begin
                    wait_count <= wait_count + 1;
                end else begin
                    wait_count <= 0;
                    state <= START_INF;
                    $display("Starting inference...");
                end
            end
            
            START_INF: begin
                // Pulse start signal for one cycle
                start <= 1;
                state <= WAIT_DONE;
                cycle_count <= 0;
                $display("Start signal asserted at time %t", $time);
            end
            
            WAIT_DONE: begin
                start <= 0;  // Clear start after one cycle
                cycle_count <= cycle_count + 1;
                
                if (done) begin
                    state <= CHECK;
                    $display("Inference complete after %d cycles", cycle_count);
                end else if (cycle_count > 2000) begin
                    // Timeout after ~80us at 25MHz
                    $display("ERROR: Inference timeout after %d cycles!", cycle_count);
                    $display("Check if memories are properly initialized");
                    state <= FINISHED;
                end
            end
            
            CHECK: begin
                // Wait for done to go low
                if (!done) begin
                    $display("\n==========================================");
                    $display("INFERENCE RESULT");
                    $display("==========================================");
                    $display("Predicted Digit: %d", digit);
                    $display("Expected Digit:  %d", EXPECTED_DIGIT);
                    
                    if (digit == EXPECTED_DIGIT) begin
                        $display("Result: PASS");
                    end else begin
                        $display("Result: FAIL");
                        
                        // Debug info on failure
                        $display("\n=== DEBUG INFO ===");
                        $display("FSM State: %d", dut.accel.fsm.state);
                        $display("Layer 2 outputs:");
                        $display("  l2_acc[0-4]: %d %d %d %d %d",
                                dut.accel.l2_acc[0], dut.accel.l2_acc[1], 
                                dut.accel.l2_acc[2], dut.accel.l2_acc[3], 
                                dut.accel.l2_acc[4]);
                        $display("  l2_acc[5-9]: %d %d %d %d %d",
                                dut.accel.l2_acc[5], dut.accel.l2_acc[6],
                                dut.accel.l2_acc[7], dut.accel.l2_acc[8],
                                dut.accel.l2_acc[9]);
                    end
                    
                    $display("==========================================\n");
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                wait_count <= wait_count + 1;
                if (wait_count > 10) begin
                    $display("TEST COMPLETE");
                    $finish;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
    
    // ==========================================
    // Global timeout watchdog
    // ==========================================
    initial begin
        #10000000;  // 10ms timeout
        $display("ERROR: Global simulation timeout!");
        $display("Current state: %d", state);
        $finish;
    end
    
endmodule
