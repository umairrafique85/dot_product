// single module for vector multiplication and accumulation.
module vector_dot_product_fixed_treeadd (
    // input interfaces
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 in_valid,     // analogous to enable / compute
    input  logic                 in_last,
    input  logic                 in_first,     // Wouldn't it be better if we just set the accummulator to 0 on reset, or after last is read out?
    output logic                 in_ready,
    input  logic [8-1:0][ 8-1:0] t_data,
    input  logic [8-1:0][ 8-1:0] weights,
    // output interfaces
    output logic                 out_valid,
    output logic        [32-1:0] dot_product,
    input  logic                 out_ready     // to control pipeline and assert that signal has been read
);
    // Stage 0: Multiply
    logic [16-1:0] products      [8];
    logic          valid_stage_0;
    logic last_stage_0, first_stage_0;
    int i;  // iterator for products array

    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_0_product
        if (~rst_n) begin
            valid_stage_0 <= 1'b0;
            for (i = 0; i < 8; i++) begin
                products[i] <= '0;
            end
            last_stage_0  <= 1'b0;
            first_stage_0 <= 1'b0;
        end else if (in_valid && in_ready) begin
            for (i = 0; i < 8; i++) begin
                products[i] <= t_data[i] * weights[i];  // REVIEW: Reason for not registering inputs at first pulse
            end  // Also: what happens to products when above is false?
            valid_stage_0 <= 1'b1;
            last_stage_0  <= in_last;
            first_stage_0 <= in_first;
        end else valid_stage_0 <= 1'b0;  // else: hold current value (stall)
        // valid_stage_0 <= 1'b0;
        // last_stage_0  <= 1'b0;
        // first_stage_0 <= 1'b0;
        // end
    end
    /* ****************************************************************
     Why we should use inputs registration for stage 0 instead of the
     multiplication:
     ****************************************************************
     If inputs come from far away or external sources:
     - Long routing delays from I/O pads
     - Cross-clock domain signals
     - Signals from other modules with long paths

     WITHOUT input registration:
     External → Long Wire Delay → Multiplier Setup Time → FF
              ↑________________↑
              This path might be too long for one clock cycle

     WITH input registration:
     External → Long Wire → FF → Short Wire → Multiplier → FF
              ↑__________↑     ↑_______________________↑
              Split into two manageable paths

     If vec_a and vec_b might arrive at different times:
     Stage 0 ensures they're captured together
     vec_a arrives at 1.2ns after clock
     vec_b arrives at 0.8ns after clock
     Stage 0 captures both, ensuring synchronized multiplication

     Possible reason for NOT starting with input registration:
     Since the multiplication itself is registered (happens inside always_ff),
     you already have input registration! Stage 0 is redundant.
     The above point in favor of registration should apply when we're
     using combinational circuitry for multiplication, or when we need
     a stage for input validation, or for clock domain crossing.
    */

    // Stage 1: Sum level 1
    logic [4-1:0][17-1:0] sum_level_1;
    logic                 valid_stage_1;
    logic last_stage_1, first_stage_1;
    logic j;  // iterator for sum_level_1

    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_1_sum_1
        if (~rst_n) begin
            sum_level_1   <= '0;
            valid_stage_1 <= 1'b0;
            last_stage_0  <= 1'b0;
            first_stage_1 <= 1'b0;
        end else if (valid_stage_0) begin
            for (j = 0; j < 4; j++) begin
                sum_level_1[i] <= products[j*2] + products[(j*2)+1];  // what value does this have when valid_stage_0 is 0?
            end
            valid_stage_1 <= 1'b1;
            last_stage_1  <= last_stage_0;
            first_stage_1 <= first_stage_0;
        end  //else begin
             // valid_stage_1 <= 1'b0;
             // last_stage_1  <= 1'b0;  // Should we do this, or preserve the previous state?
             // first_stage_1 <= 1'b0;  // Should we do this, or preserve the previous state?
        // end
    end

    // Stage 2: Sum level 2
    logic [2-1:0][18-1:0] sum_level_2;
    logic                 valid_stage_2;
    logic last_stage_2, first_stage_2;
    logic k;  // iterator for sum_level_2
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_2_sum_2
        if (~rst_n) begin
            sum_level_2   <= '0;
            valid_stage_2 <= 1'b0;
            last_stage_2  <= 1'b0;
            first_stage_2 <= 1'b0;
        end else if (valid_stage_1) begin
            for (k = 0; k < 2; k++) begin
                sum_level_2[k] <= sum_level_1[i*2] + sum_level_1[(i*2)+1];  // what happens to this when valid_state_1 is 0?
            end
            valid_stage_2 <= 1'b1;
            last_stage_2  <= last_stage_1;
            first_stage_2 <= first_stage_1;
        end  //else begin
             // valid_stage_2 <= 1'b0;
             // last_stage_2  <= 1'b0;  // Same objection as before
             // first_stage_2 <= 1'b0;  // Same objection as before
        // end
    end

    // Stage 3: final
    // logic valid_accum; // No need
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_3_sum_final
        if (~rst_n) begin
            dot_product <= '0;
            out_valid   <= 1'b0;
        end else if (valid_stage_2) begin
            if (first_stage_2) begin
                dot_product <= sum_level_2[0] + sum_level_2[1];
            end else begin
                dot_product <= dot_product + (sum_level_2[0] + sum_level_2[1]);
            end
            // valid_accum <= 1'b1; no need
            // if (last_stage_2) begin  // Should I just use: out_valid <= last_stage_2;
            //     out_valid <= 1'b1;
            // end else out_valid <= 1'b0;
            out_valid <= last_stage_2;
        end
    end

    assign in_ready = !out_valid || (out_valid && !out_ready);
endmodule
