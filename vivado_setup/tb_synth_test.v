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

    // Test tracking - Vivado compatible
    reg [1:0] test_cnt;
    reg [3:0] exp_labels [0:2];  // Expected labels for 3 test images

    // State machine for testbench control
    localparam TB_IDLE     = 3'd0;
    localparam TB_RESET    = 3'd1;
    localparam TB_START_TEST = 3'd2;
    localparam TB_WAIT_DONE = 3'd3;
    localparam TB_CHECK_RESULT = 3'd4;
    localparam TB_NEXT_TEST = 3'd5;
    localparam TB_FINISHED = 3'd6;

    reg [2:0] tb_state;
    reg [15:0] wait_counter;

    // Clock generation - 25MHz (matches constraints)
    initial begin
        clk = 0;
        forever #20 clk = ~clk;  // 40ns period = 25MHz
    end

    // Expected labels initialized in main initial block

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

    // Initialize test parameters
    initial begin
        exp_labels[0] = 4'd6;  // Image 0 is digit 6
        exp_labels[1] = 4'd2;  // Image 1 is digit 2
        exp_labels[2] = 4'd3;  // Image 2 is digit 3

        $display("==========================================");
        $display("SYNTHESIS VERSION TEST - VIVADO COMPATIBLE");
        $display("==========================================");
        $display("Testing mnist_top_synth with embedded images");
        $display("Using state machine approach for Vivado compatibility");
        $display("==========================================\n");

        // Initialize all signals
        rst = 1;
        start = 0;
        img_sel = 2'b00;
        test_cnt = 2'd0;
        tb_state = TB_IDLE;
        wait_counter = 16'd0;
    end

    // Main testbench state machine - Vivado compatible
    always @(posedge clk) begin
        if (rst) begin
            tb_state <= TB_IDLE;
            test_cnt <= 2'd0;
            start <= 1'b0;
            wait_counter <= 16'd0;
        end else begin
            case (tb_state)
                TB_IDLE: begin
                    if (wait_counter < 16'd10) begin
                        wait_counter <= wait_counter + 1;
                    end else begin
                        tb_state <= TB_RESET;
                        wait_counter <= 16'd0;
                        rst <= 1'b0;

                        // Debug memory loading
                        $display("\n=== MEMORY DEBUG INFO ===");
                        $display("First few W1 weights: %h %h %h %h",
                                dut.accel.memory.w1_mem[0], dut.accel.memory.w1_mem[1],
                                dut.accel.memory.w1_mem[2], dut.accel.memory.w1_mem[3]);

                        if (dut.accel.memory.w1_mem[0] === 8'hxx) begin
                            $display("ERROR: W1 weights are undefined!");
                        end else if (dut.accel.memory.w1_mem[0] === 8'h00 &&
                                     dut.accel.memory.w1_mem[1] === 8'h00) begin
                            $display("WARNING: W1 weights might be uninitialized!");
                        end else begin
                            $display("SUCCESS: W1 weights loaded correctly");
                        end
                        $display("========================\n");
                    end
                end

                TB_RESET: begin
                    if (wait_counter < 16'd5) begin
                        wait_counter <= wait_counter + 1;
                    end else begin
                        tb_state <= TB_START_TEST;
                        wait_counter <= 16'd0;
                        img_sel <= test_cnt;
                        $display("Starting test %d (image %d, expected digit %d)...",
                                test_cnt, test_cnt, exp_labels[test_cnt]);
                    end
                end

                TB_START_TEST: begin
                    if (wait_counter < 16'd2) begin
                        wait_counter <= wait_counter + 1;  // Small delay for img_sel to settle
                    end else if (valid) begin
                        start <= 1'b1;
                        tb_state <= TB_WAIT_DONE;
                        wait_counter <= 16'd0;
                        $display("  Start signal asserted, waiting for inference...");
                    end else begin
                        $display("ERROR: Invalid image selection %d", img_sel);
                        tb_state <= TB_NEXT_TEST;
                        wait_counter <= 16'd0;
                    end
                end

                TB_WAIT_DONE: begin
                    start <= 1'b0;  // Pulse start for only one cycle
                    if (done) begin
                        tb_state <= TB_CHECK_RESULT;
                    end
                    // Timeout protection
                    wait_counter <= wait_counter + 1;
                    if (wait_counter > 16'd2000) begin  // ~80μs timeout at 25MHz
                        $display("ERROR: Timeout waiting for inference completion!");
                        tb_state <= TB_NEXT_TEST;
                        wait_counter <= 16'd0;
                    end
                end

                TB_CHECK_RESULT: begin
                    // Wait for done to go low before checking next
                    if (!done) begin
                        // Check result
                        if (digit == exp_labels[test_cnt]) begin
                            $display("  Test %d: PASS - Predicted: %d, Expected: %d",
                                    test_cnt, digit, exp_labels[test_cnt]);
                        end else begin
                            $display("  Test %d: FAIL - Predicted: %d, Expected: %d",
                                    test_cnt, digit, exp_labels[test_cnt]);
                        end
                        tb_state <= TB_NEXT_TEST;
                        wait_counter <= 16'd0;
                    end
                end

                TB_NEXT_TEST: begin
                    if (wait_counter < 16'd10) begin  // Small delay between tests
                        wait_counter <= wait_counter + 1;
                    end else begin
                        wait_counter <= 16'd0;
                        if (test_cnt < 2'd2) begin
                            test_cnt <= test_cnt + 1;
                            img_sel <= test_cnt + 1;  // Update image selection
                            tb_state <= TB_START_TEST;
                            $display("Starting test %d (image %d, expected digit %d)...",
                                    test_cnt + 1, test_cnt + 1, exp_labels[test_cnt + 1]);
                        end else begin
                            tb_state <= TB_FINISHED;
                            // Test invalid selection
                            img_sel <= 2'b11;
                            $display("\nTesting invalid image selection...");
                        end
                    end
                end

                TB_FINISHED: begin
                    if (wait_counter < 16'd5) begin
                        wait_counter <= wait_counter + 1;
                    end else begin
                        if (!valid) begin
                            $display("PASS: Invalid selection correctly detected");
                        end else begin
                            $display("FAIL: Invalid selection not detected");
                        end

                        $display("\n==========================================");
                        $display("SYNTHESIS VERSION TEST COMPLETE");
                        $display("==========================================\n");
                        $finish;
                    end
                end

                default: tb_state <= TB_IDLE;
            endcase
        end
    end

    // Reset control
    initial begin
        #200;
        rst = 0;
    end

    // Timeout watchdog (appropriate for state machine)
    initial begin
        #20000000;  // 20ms timeout - should be plenty for 3 tests
        $display("ERROR: Global simulation timeout!");
        $display("This may indicate stuck state machine or memory issues.");
        $display("Current state: %d, test_cnt: %d", tb_state, test_cnt);
        $finish;
    end

    // Optional: VCD dump
    initial begin
        $dumpfile("synth_test.vcd");
        $dumpvars(0, tb_synth_test);
    end

endmodule
