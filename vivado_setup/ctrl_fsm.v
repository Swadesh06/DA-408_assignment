// Control FSM - Orchestrates MNIST inference pipeline

module ctrl_fsm (
    input clk,
    input rst,
    input start,
    output reg done,
    output reg busy,
    output reg [1:0] layer_sel,
    output reg [9:0] row_idx,
    output reg mac_en_l1,
    output reg mac_clr_l1,
    output reg mac_en_l2,
    output reg mac_clr_l2,
    output reg load_img,
    output reg comp_l1,
    output reg apply_relu,
    output reg comp_l2,
    output reg find_max,
    output reg [9:0] cycle_cnt
);

    // FSM states
    localparam IDLE     = 4'd0;
    localparam INIT     = 4'd1;
    localparam LOAD_IMG = 4'd2;
    localparam L1_COMP  = 4'd3;
    localparam L1_RELU  = 4'd4;
    localparam L2_COMP  = 4'd5;
    localparam ARGMAX   = 4'd6;
    localparam DONE     = 4'd7;

    reg [3:0] state, next_state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = LOAD_IMG;
            end

            LOAD_IMG: begin
                // Three cycles: load image, stabilize, init bias
                if (cycle_cnt < 2) begin
                    next_state = LOAD_IMG;
                end else begin
                    next_state = L1_COMP;
                end
            end

            L1_COMP: begin
                if (cycle_cnt >= 786) begin
                    next_state = L1_RELU;
                end
            end

            L1_RELU: begin
                // Three cycles: ReLU compute + stabilize + L2 bias init
                if (cycle_cnt < 2) begin
                    next_state = L1_RELU;
                end else begin
                    next_state = L2_COMP;
                end
            end

            L2_COMP: begin
                if (cycle_cnt >= 33) begin
                    next_state = ARGMAX;
                end
            end

            ARGMAX: begin
                // Two cycles: compute argmax then signal done
                if (cycle_cnt == 0) begin
                    next_state = ARGMAX;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic and control signals
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            busy <= 1'b0;
            layer_sel <= 2'd0;
            row_idx <= 10'd0;
            mac_en_l1 <= 1'b0;
            mac_clr_l1 <= 1'b0;
            mac_en_l2 <= 1'b0;
            mac_clr_l2 <= 1'b0;
            load_img <= 1'b0;
            comp_l1 <= 1'b0;
            apply_relu <= 1'b0;
            comp_l2 <= 1'b0;
            find_max <= 1'b0;
            cycle_cnt <= 10'd0;
        end else begin
            // Default values
            load_img <= 1'b0;
            apply_relu <= 1'b0;
            find_max <= 1'b0;
            mac_clr_l1 <= 1'b0;
            mac_clr_l2 <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    layer_sel <= 2'd0;
                    row_idx <= 10'd0;
                    cycle_cnt <= 10'd0;
                    mac_en_l1 <= 1'b0;
                    mac_en_l2 <= 1'b0;
                    comp_l1 <= 1'b0;
                    comp_l2 <= 1'b0;
                end

                INIT: begin
                    busy <= 1'b1;
                    // Clear all MAC accumulators
                    mac_clr_l1 <= 1'b1;
                    mac_clr_l2 <= 1'b1;
                    cycle_cnt <= 10'd0;
                    layer_sel <= 2'd0;
                    row_idx <= 10'd0;
                end

                LOAD_IMG: begin
                    layer_sel <= 2'd1;
                    row_idx <= 10'd0;

                    if (cycle_cnt == 0) begin
                        load_img <= 1'b1;  // Load image on first cycle
                        cycle_cnt <= cycle_cnt + 1;
                    end else if (cycle_cnt == 1) begin
                        load_img <= 1'b0;  // Stop loading, let image stabilize
                        cycle_cnt <= cycle_cnt + 1;
                    end else begin
                        load_img <= 1'b0;  // Bias init happens in L1_COMP now
                        cycle_cnt <= 10'd0;  // Reset for L1_COMP
                    end
                end

                L1_COMP: begin
                    comp_l1 <= 1'b1;
                    layer_sel <= 2'd1;
                    if (cycle_cnt < 786) begin
                        if (cycle_cnt == 0) begin
                            mac_en_l1 <= 1'b0;
                        end else if (cycle_cnt >= 2 && cycle_cnt <= 785) begin
                            row_idx <= (cycle_cnt - 2);
                            mac_en_l1 <= 1'b1;
                        end else begin
                            mac_en_l1 <= 1'b0;
                        end
                        cycle_cnt <= cycle_cnt + 1;
                    end else begin
                        mac_en_l1 <= 1'b0;
                        cycle_cnt <= 10'd0;
                    end
                end

                L1_RELU: begin
                    comp_l1 <= 1'b0;
                    mac_en_l1 <= 1'b0;

                    if (cycle_cnt == 0) begin
                        apply_relu <= 1'b1;  // Apply ReLU on first cycle
                        cycle_cnt <= cycle_cnt + 1;
                    end else if (cycle_cnt == 1) begin
                        apply_relu <= 1'b0;  // ReLU output stabilizes
                        cycle_cnt <= cycle_cnt + 1;
                    end else begin
                        apply_relu <= 1'b0;  // Prepare for L2_COMP
                        cycle_cnt <= 10'd0;  // Reset for L2_COMP
                    end
                end

                L2_COMP: begin
                    comp_l2 <= 1'b1;
                    layer_sel <= 2'd2;
                    if (cycle_cnt < 33) begin
                        if (cycle_cnt > 0 && cycle_cnt <= 32) begin
                            row_idx <= (cycle_cnt - 1);
                            mac_en_l2 <= 1'b1;
                        end else begin
                            mac_en_l2 <= 1'b0;
                        end
                        cycle_cnt <= cycle_cnt + 1;
                    end else begin
                        mac_en_l2 <= 1'b0;
                        cycle_cnt <= 10'd0;
                    end
                end

                ARGMAX: begin
                    comp_l2 <= 1'b0;
                    if (cycle_cnt == 0) begin
                        find_max <= 1'b1;
                        cycle_cnt <= cycle_cnt + 1;
                    end else if (cycle_cnt == 1) begin
                        find_max <= 1'b0;
                        cycle_cnt <= cycle_cnt + 1;
                    end else begin
                        find_max <= 1'b0;
                        cycle_cnt <= 10'd0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end

                default: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
