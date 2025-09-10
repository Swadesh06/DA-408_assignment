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
                    
                    // Detailed test image verification
                    if (dut.test_img[0] === 8'hxx) begin
                        $display("ERROR: Test image not loaded!");
                    end else if (dut.test_img[0] === 8'h00 && 
                               dut.test_img[1] === 8'h00 && 
                               dut.test_img[10] === 8'h00 && 
                               dut.test_img[100] === 8'h00) begin
                        $display("WARNING: Test image appears to be all zeros!");
                        $display("Check if test_img0.mem file exists in Vivado project directory");
                    end else begin
                        $display("SUCCESS: Test image loaded with non-zero data");
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
                
                // Detailed FSM monitoring every 100 cycles
                if (cycle_count % 100 == 0) begin
                    $display("Progress: Cycle %d, FSM State %d, Done=%b", 
                            cycle_count, dut.accel.fsm.state, done);
                    $display("  FSM Details: comp_l1=%b, comp_l2=%b, find_max=%b", 
                            dut.accel.fsm.comp_l1, dut.accel.fsm.comp_l2, dut.accel.fsm.find_max);
                    $display("  Cycle_cnt=%d, row_idx=%d", 
                            dut.accel.fsm.cycle_cnt, dut.accel.fsm.row_idx);
                end
                
                if (done) begin
                    state <= CHECK;
                    $display("Inference complete after %d cycles", cycle_count);
                end else if (cycle_count > 5000) begin
                    // Extended timeout for detailed debugging
                    $display("ERROR: Inference timeout after %d cycles!", cycle_count);
                    $display("Final FSM State: %d", dut.accel.fsm.state);
                    $display("Final FSM cycle_cnt: %d", dut.accel.fsm.cycle_cnt);
                    $display("Final FSM row_idx: %d", dut.accel.fsm.row_idx);
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
                    
                    // Always show detailed computation results for debugging
                    $display("\n=== DETAILED COMPUTATION RESULTS ===");
                    $display("Final Layer 2 outputs (signed 20-bit):");
                    $display("  Class 0: %d", dut.accel.l2_acc[0]);
                    $display("  Class 1: %d", dut.accel.l2_acc[1]);
                    $display("  Class 2: %d", dut.accel.l2_acc[2]);
                    $display("  Class 3: %d", dut.accel.l2_acc[3]);
                    $display("  Class 4: %d", dut.accel.l2_acc[4]);
                    $display("  Class 5: %d", dut.accel.l2_acc[5]);
                    $display("  Class 6: %d (Expected Maximum)", dut.accel.l2_acc[6]);
                    $display("  Class 7: %d", dut.accel.l2_acc[7]);
                    $display("  Class 8: %d", dut.accel.l2_acc[8]);
                    $display("  Class 9: %d", dut.accel.l2_acc[9]);
                    $display("Argmax result: %d", digit);
                    $display("=======================================");
                    
                    if (digit == EXPECTED_DIGIT) begin
                        $display("Result: PASS - Correct prediction!");
                    end else begin
                        $display("Result: FAIL - Wrong prediction!");
                    end
                    
                    $display("==========================================\n");
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                $display("TEST COMPLETE");
                $finish;  // Finish immediately when done
            end
            
            default: state <= IDLE;
        endcase
    end
    
    // ==========================================
    // Global timeout watchdog - Extended for Vivado
    // ==========================================
    initial begin
        #50000000;  // 50ms timeout - much longer for Vivado
        $display("ERROR: Global simulation timeout after 50ms!");
        $display("Current state: %d", state);
        $display("Cycle count: %d", cycle_count);
        $display("FSM state: %d", dut.accel.fsm.state);
        $finish;
    end
    
endmodule
