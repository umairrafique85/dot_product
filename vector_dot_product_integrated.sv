// single module for vector multiplication and accumulation.
module vector_dot_product_fixed_treeadd (
    // input interfaces
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 in_valid,    // analogous to enable / compute
    input  logic                 in_last,
    input  logic                 in_first,
    output logic                 in_ready,    // Not used at the moment. Need to probably use it for back-pressure
    input  logic [8-1:0][ 8-1:0] t_data,
    input  logic [8-1:0][ 8-1:0] weights,
    // output interfaces
    output logic                 out_valid,
    output logic        [32-1:0] dot_product
);
    // Stage 0: Multiply
    logic [16-1:0] products      [8];
    logic          valid_stage_0;
    logic last_stage_0, first_stage_0;
    int i;  // iterator for products array

    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_0
        if (~rst_n) begin
            valid_stage_0 <= 1'b0;
            for (i = 0; i < 8; i++) begin
                products[i] <= '0;
            end
            last_stage_0  <= 1'b0;
            first_stage_0 <= 1'b0;
        end else if (in_valid & in_ready) begin
            for (i = 0; i < 8; i++) begin
                products[i] <= vec_a[i] * vec_b[i];  // t_data[i] * weights[i] REVIEW: Reason for not registering inputs at first pulse
            end
            valid_stage_0 <= 1'b1;
            last_stage_0  <= in_last;
            first_stage_0 <= in_first;
        end else begin
            valid_stage_0 <= 1'b0;
            last_stage_0  <= 1'b0;  // Shouldn't we just leave this at last state?
            first_stage_0 <= 1'b0;  // Shouldn't we just leave this at last state?
        end
    end

    // Stage 1: Sum level 1
    logic [4-1:0][17-1:0] sum_level_1;
    logic                 valid_stage_1;
    logic last_stage_1, first_stage_1;
    logic j;  // iterator for sum_level_1
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_1
        if (~rst_n) begin
            sum_level_1   <= '0;
            valid_stage_1 <= 1'b0;
            last_stage_0  <= 1'b0;
            first_stage_1 <= 1'b0;
        end else if (valid_stage_0) begin
            for (j = 0; j < 4; j++) begin
                sum_level_1[i] <= products[j*2] + products[(j*2)+1];
            end
            valid_stage_1 <= 1'b1;
            last_stage_1  <= last_stage_0;
            first_stage_1 <= first_stage_0;
        end else begin
            valid_stage_1 <= 1'b0;
            last_stage_1  <= 1'b0;  // Should we do this, or preserve the previous state?
            first_stage_1 <= 1'b0;  // Should we do this, or preserve the previous state?
        end
    end

    // Stage 2: Sum level 2
    logic [2-1:0][18-1:0] sum_level_2;
    logic                 valid_stage_2;
    logic last_stage_2, first_stage_2;
    logic k;  // iterator for sum_level_2
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_2
        if (~rst_n) begin
            sum_level_2   <= '0;
            valid_stage_2 <= 1'b0;
            last_stage_2  <= 1'b0;
            first_stage_2 <= 1'b0;
        end else if (valid_stage_1) begin
            for (k = 0; k < 2; k++) begin
                sum_level_2[k] <= sum_level_1[i*2] + sum_level_1[(i*2)+1];
            end
            valid_stage_2 <= 1'b1;
            last_stage_2  <= last_stage_1;
            first_stage_2 <= first_stage_1;
        end else begin
            valid_stage_2 <= 1'b0;
            last_stage_2  <= 1'b0;  // Same objection as before
            first_stage_2 <= 1'b0;  // Same objection as before
        end
    end

    // Stage 3: final
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_3_final
        if (~rst_n) begin
            dot_product <= '0;
            out_valid   <= 1'b0;
        end else if (valid_stage_2) begin
            if (first_stage_2) begin
                dot_product <= sum_level_2[0] + sum_level_2[1];
            end else begin
                dot_product <= dot_product + (sum_level_2[0] + sum_level_2[1]);
            end
            if (last_stage_2) begin
                out_valid <= 1'b1;
            end else out_valid <= 1'b0;
        end
    end
endmodule
