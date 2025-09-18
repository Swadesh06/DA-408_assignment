// MNIST Hardware Accelerator Top Module - Sequential Version
// Centralized memory loading for reliable synthesis

module mnist_top_synth (
    input clk,
    input rst,
    input start,
    output reg [3:0] digit,
    output reg done,
    output reg [7:0] fsm_leds  // FSM state monitoring LEDs
);

    // Parameters
    parameter IMG_SIZE = 784;
    parameter HID_SIZE = 32;
    parameter OUT_SIZE = 10;
    
    // ==============================================================
    // CENTRALIZED MEMORY DECLARATIONS AND LOADING
    // Following friend's approach - all memories in top module
    // ==============================================================
    
    // Image memory
    reg signed [7:0] img_mem [0:IMG_SIZE-1];
    
    // Layer 1 memories (784x32 weights, 32 biases)
    reg signed [7:0] w1_mem [0:25087];  // 784 * 32 = 25088
    reg signed [7:0] b1_mem [0:31];     // 32 biases
    
    // Layer 2 memories (32x10 weights, 10 biases)  
    reg signed [7:0] w2_mem [0:319];    // 32 * 10 = 320
    reg signed [7:0] b2_mem [0:9];      // 10 biases
    
    // CRITICAL: Single initial block for ALL memory loading
    // This is what friend's code does and Vivado handles it properly
    initial begin
        // Load all memory files in one initial block
        $readmemh("test_img0.mem", img_mem);
        $readmemh("w1.mem", w1_mem);
        $readmemh("b1.mem", b1_mem);
        $readmemh("w2.mem", w2_mem);
        $readmemh("b2.mem", b2_mem);
        
        // Debug output
        $display("==========================================");
        $display("[TOP] Memory Loading Complete");
        $display("==========================================");
        $display("Image pixels [0:3]: %h %h %h %h", 
                img_mem[0], img_mem[1], img_mem[2], img_mem[3]);
        $display("W1 samples [0:3]: %h %h %h %h",
                w1_mem[0], w1_mem[1], w1_mem[2], w1_mem[3]);
        $display("B1 samples [0:3]: %h %h %h %h",
                b1_mem[0], b1_mem[1], b1_mem[2], b1_mem[3]);
        $display("W2 samples [0:3]: %h %h %h %h",
                w2_mem[0], w2_mem[1], w2_mem[2], w2_mem[3]);
        $display("B2 samples [0:3]: %h %h %h %h",
                b2_mem[0], b2_mem[1], b2_mem[2], b2_mem[3]);
        $display("==========================================");
    end
    
    // ==============================================================
    // FSM STATES
    // ==============================================================
    localparam IDLE     = 4'd0;
    localparam INIT     = 4'd1;
    localparam L1_COMP  = 4'd2;
    localparam L1_RELU  = 4'd3;
    localparam L2_COMP  = 4'd4;
    localparam ARGMAX   = 4'd5;
    localparam DONE     = 4'd6;
    
    reg [3:0] state, next_state;
    
    // ==============================================================
    // INTERNAL REGISTERS AND COUNTERS
    // ==============================================================
    
    // Counters for sequential processing
    reg [9:0] pix_cnt;      // Pixel counter (0-783)
    reg [4:0] hid_cnt;      // Hidden neuron counter (0-31)
    reg [3:0] out_cnt;      // Output neuron counter (0-9)
    reg [15:0] cyc_cnt;     // Cycle counter for timing
    
    // Accumulator for MAC operations
    reg signed [19:0] acc;  // Wide enough for 8-bit MAC accumulation
    
    // Storage for layer outputs
    reg signed [7:0] l1_out [0:31];  // Layer 1 outputs after ReLU
    reg signed [19:0] l2_out [0:9];  // Layer 2 outputs (before argmax)
    
    // Address calculation
    wire [14:0] w1_addr;
    wire [8:0] w2_addr;
    
    // Sequential weight addressing
    assign w1_addr = hid_cnt * IMG_SIZE + pix_cnt;
    assign w2_addr = out_cnt * HID_SIZE + hid_cnt;
    
    // ==============================================================
    // FSM LOGIC
    // ==============================================================
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            
            INIT: begin
                next_state = L1_COMP;
            end
            
            L1_COMP: begin
                // Move to ReLU when all neurons computed
                if (hid_cnt == 31 && pix_cnt == 783 && cyc_cnt == 2)
                    next_state = L1_RELU;
            end
            
            L1_RELU: begin
                // Single cycle for ReLU
                next_state = L2_COMP;
            end
            
            L2_COMP: begin
                // Move to argmax when all output neurons computed
                if (out_cnt == 9 && hid_cnt == 31 && cyc_cnt == 2)
                    next_state = ARGMAX;
            end
            
            ARGMAX: begin
                // Stay in argmax for 10 cycles
                if (cyc_cnt == 10)
                    next_state = DONE;
            end
            
            DONE: begin
                if (!start) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ==============================================================
    // DATAPATH - SEQUENTIAL MAC PROCESSING
    // ==============================================================
    
    integer i;
    reg signed [19:0] max_val;
    reg [3:0] max_idx;
    
    always @(posedge clk) begin
        if (rst) begin
            // Reset all counters
            pix_cnt <= 0;
            hid_cnt <= 0;
            out_cnt <= 0;
            cyc_cnt <= 0;
            acc <= 0;
            digit <= 0;
            done <= 0;
            
            // Reset max finding variables
            max_val <= -20'sd524288;  // Large negative value
            max_idx <= 0;
            
            // Clear outputs
            for (i = 0; i < 32; i = i + 1) l1_out[i] <= 0;
            for (i = 0; i < 10; i = i + 1) l2_out[i] <= 0;
            
            // Clear LEDs
            fsm_leds <= 8'b00000000;
            
        end else begin
            
            // Update FSM LEDs
            case (state)
                IDLE: fsm_leds <= 8'b00000001;
                INIT: fsm_leds <= 8'b00000011;
                L1_COMP: fsm_leds <= 8'b00000111;
                L1_RELU: fsm_leds <= 8'b00001111;
                L2_COMP: fsm_leds <= 8'b00011111;
                ARGMAX: fsm_leds <= 8'b00111111;
                DONE: fsm_leds <= 8'b01111111;
                default: fsm_leds <= 8'b10000000;
            endcase
            
            case (state)
                
                IDLE: begin
                    done <= 0;
                    digit <= 0;
                    cyc_cnt <= 0;
                end
                
                INIT: begin
                    // Initialize counters for Layer 1
                    pix_cnt <= 0;
                    hid_cnt <= 0;
                    out_cnt <= 0;
                    cyc_cnt <= 0;
                    acc <= 0;
                end
                
                L1_COMP: begin
                    // Sequential Layer 1 computation
                    // Process one pixel per cycle for current hidden neuron
                    
                    if (cyc_cnt == 0) begin
                        // Cycle 0: Read weight and pixel
                        cyc_cnt <= 1;
                        
                    end else if (cyc_cnt == 1) begin
                        // Cycle 1: Multiply and accumulate
                        if (pix_cnt == 0) begin
                            // First pixel - initialize with bias
                            acc <= $signed(img_mem[pix_cnt]) * $signed(w1_mem[w1_addr]) + 
                                   ($signed(b1_mem[hid_cnt]) << 7); // Scale bias
                        end else begin
                            // Subsequent pixels - accumulate
                            acc <= acc + $signed(img_mem[pix_cnt]) * $signed(w1_mem[w1_addr]);
                        end
                        cyc_cnt <= 2;
                        
                    end else if (cyc_cnt == 2) begin
                        // Cycle 2: Update counters
                        if (pix_cnt < 783) begin
                            // Next pixel
                            pix_cnt <= pix_cnt + 1;
                            cyc_cnt <= 0;
                        end else if (hid_cnt < 31) begin
                            // Store result and move to next hidden neuron
                            l1_out[hid_cnt] <= acc[19] ? 8'd0 : 
                                             (acc[18:7] > 127) ? 8'd127 : acc[14:7]; // ReLU + clamp
                            hid_cnt <= hid_cnt + 1;
                            pix_cnt <= 0;
                            cyc_cnt <= 0;
                            acc <= 0;
                        end else begin
                            // Last neuron - store and move to next state
                            l1_out[hid_cnt] <= acc[19] ? 8'd0 : 
                                             (acc[18:7] > 127) ? 8'd127 : acc[14:7];
                            cyc_cnt <= 2; // Stay for state transition
                        end
                    end
                end
                
                L1_RELU: begin
                    // ReLU already applied during L1_COMP
                    // Initialize for Layer 2
                    hid_cnt <= 0;
                    out_cnt <= 0;
                    cyc_cnt <= 0;
                    acc <= 0;
                end
                
                L2_COMP: begin
                    // Sequential Layer 2 computation
                    // Process one hidden neuron per cycle for current output neuron
                    
                    if (cyc_cnt == 0) begin
                        // Cycle 0: Read weight and hidden value
                        cyc_cnt <= 1;
                        
                    end else if (cyc_cnt == 1) begin
                        // Cycle 1: Multiply and accumulate
                        if (hid_cnt == 0) begin
                            // First hidden - initialize with bias
                            acc <= $signed(l1_out[hid_cnt]) * $signed(w2_mem[w2_addr]) + 
                                   ($signed(b2_mem[out_cnt]) << 7);
                        end else begin
                            // Subsequent hidden - accumulate
                            acc <= acc + $signed(l1_out[hid_cnt]) * $signed(w2_mem[w2_addr]);
                        end
                        cyc_cnt <= 2;
                        
                    end else if (cyc_cnt == 2) begin
                        // Cycle 2: Update counters
                        if (hid_cnt < 31) begin
                            // Next hidden neuron
                            hid_cnt <= hid_cnt + 1;
                            cyc_cnt <= 0;
                        end else if (out_cnt < 9) begin
                            // Store result and move to next output neuron
                            l2_out[out_cnt] <= acc;
                            out_cnt <= out_cnt + 1;
                            hid_cnt <= 0;
                            cyc_cnt <= 0;
                            acc <= 0;
                        end else begin
                            // Last neuron - store and move to argmax
                            l2_out[out_cnt] <= acc;
                            cyc_cnt <= 2; // Stay for state transition
                        end
                    end
                end
                
                ARGMAX: begin
                    // Find maximum output - sequential comparison
                    if (cyc_cnt == 0) begin
                        max_val <= l2_out[0];
                        max_idx <= 4'd0;
                        cyc_cnt <= 1;
                    end else if (cyc_cnt <= 9) begin
                        if ($signed(l2_out[cyc_cnt]) > $signed(max_val)) begin
                            max_val <= l2_out[cyc_cnt];
                            max_idx <= cyc_cnt[3:0];
                        end
                        cyc_cnt <= cyc_cnt + 1;
                    end else begin
                        digit <= max_idx;
                        cyc_cnt <= 10;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    // digit already set in ARGMAX
                end
                
            endcase
        end
    end
    
endmodule