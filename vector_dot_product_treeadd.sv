module vector_dot_product_8_treeadd_comparator_8 (
    input  logic [64-1:0] vec_a,
    input  logic [64-1:0] vec_b,
    input  logic          clk,
    input  logic          compute,
    input  logic          rst_n,
    output logic [19-1:0] dot_product_bhv_treeadd_explicit,
    output logic [19-1:0] dot_product_bhv_treeadd_packed,
    output logic [19-1:0] dot_product_bhv_treadd_unpacked,            //dot_product_bhv_treeadd_param,
    output logic [19-1:0] dot_product_bhv_treeadd_pipelined,
    output logic [19-1:0] dot_product_bhv_treeadd_pipelined_combMul,
    output logic          out_valid
);
    vector_dot_product_bhv_treeadd_explicit_8(
        .clk(clk), .compute(compute), .rst_n(rst_n), .vec_a(vec_a), .vec_b(vec_b), .out_valid(out_valid), .dot_product(dot_product_bhv_treeadd_explicit)
    ); vector_dot_product_bhv_treeadd_packed_8(
        .clk(clk), .compute(compute), .rst_n(rst_n), .vec_a(vec_a), .vec_b(vec_b), .out_valid(out_valid), .dot_product(dot_product_bhv_treeadd_packed)
    ); vector_dot_product_bhv_treeadd_unpacked_8(
        .clk(clk), .compute(compute), .rst_n(rst_n), .vec_a(vec_a), .vec_b(vec_b), .out_valid(out_valid), .dot_product(dot_product_bhv_treeadd_unpacked)
    ); vector_dot_product_bhv_treeadd_pipelined_8(
        .clk(clk), .compute(compute), .rst_n(rst_n), .vec_a(vec_a), .vec_b(vec_b), .out_valid(out_valid), .dot_product(dot_product_bhv_treeadd_pipelined)
    ); vector_dot_product_bhv_treeadd_pipelined_combMult_8(
        .clk(clk),
        .compute(compute),
        .rst_n(rst_n),
        .vec_a(vec_a),
        .vec_b(vec_b),
        .out_valid(out_valid),
        .dot_product(dot_product_bhv_treeadd_pipelined_combMul)
    );
    // vector_dot_product_bhv_treeadd_param_8 (
    //     .vec_a(vec_a),
    //     .vec_b(vec_b),
    //     .dot_product(dot_product_bhv_treeadd_param)
    // );
endmodule

// Using explicit tree-based adder
module vector_dot_product_bhv_treeadd_explicit_8 (
    input  logic [8-1:0][ 8-1:0] vec_a,
    input  logic [8-1:0][ 8-1:0] vec_b,
    input  logic                 clk,
    input  logic                 rst_n,        // Active-low reset
    input  logic                 compute,      // Enable
    input  logic                 in_last,      // boolean to propagate last
    output logic        [19-1:0] dot_product,
    output logic                 out_valid,
    output logic                 out_last
);

    // Register vectors on first clock edge and mark start of compute
    logic [16-1:0]        products          [8];
    logic [ 8-1:0][8-1:0] reg_vec_a;
    logic [ 8-1:0][8-1:0] reg_vec_b;
    logic                 reg_compute_begin;
    logic                 last_stage_0;

    always_ff @(posedge clk or negedge rst_n) begin : proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            reg_vec_a         <= '0;
            reg_vec_b         <= '0;
            last_stage_0      <= 1'b0;
        end else if (compute) begin
            reg_compute_begin <= 1'b1;
            reg_vec_a         <= vec_a;
            reg_vec_b         <= vec_b;
            last_stage_0      <= in_last;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_extract_multiply
            assign products[i] = reg_vec_a[i] * reg_vec_b[i];
        end
    endgenerate

    // Tree-based
    logic [17-1:0] sum_level1      [4];
    logic [18-1:0] sum_level2      [2];
    logic [19-1:0] dot_product_int;

    assign sum_level1[0]   = products[0] + products[1];
    assign sum_level1[1]   = products[2] + products[3];
    assign sum_level1[2]   = products[4] + products[5];
    assign sum_level1[3]   = products[6] + products[7];

    assign sum_level2[0]   = sum_level1[0] + sum_level1[1];
    assign sum_level2[1]   = sum_level1[2] + sum_level1[3];

    assign dot_product_int = sum_level2[0] + sum_level2[1];

    always_ff @(posedge clk or negedge rst_n) begin : proc_out
        if (!rst_n) begin
            dot_product <= '0;
            valid       <= 1'b0;
            out_last    <= 1'b0;
        end else if (reg_compute_begin) begin  // Assert valid on the second clock edge after compute
            dot_product <= dot_product_int;
            valid       <= 1'b1;
            out_last    <= last_stage_0;
        end
    end
endmodule

// Same target, generate block, packed vectors for initial vector registers, unpacked vector for products
// packed intermediary sums
module vector_dot_product_bhv_treeadd_packed_8 (
    input  logic [8-1:0][ 8-1:0] vec_a,
    input  logic [8-1:0][ 8-1:0] vec_b,
    input  logic                 clk,
    input  logic                 rst_n,        // Active-low reset
    input  logic                 in_last,
    input  logic                 compute,      // Enable
    output logic        [19-1:0] dot_product,
    output logic                 out_valid,
    output logic                 out_last
);

    // stage_0: Register start
    logic [16-1:0]        products          [8];
    logic [ 8-1:0][8-1:0] reg_vec_a;
    logic [ 8-1:0][8-1:0] reg_vec_b;
    logic                 reg_compute_begin;
    logic                 last_stg_0;

    always_ff @(posedge clk or negedge rst_n) begin : proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            reg_vec_a         <= '0;
            reg_vec_b         <= '0;
            last_stg_0        <= 1'b0;
        end else begin
            reg_compute_begin <= 1'b1;
            reg_vec_a         <= vec_a;
            reg_vec_b         <= vec_b;
            last_stg_0        <= in_last;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_multiply
            assign products[i] = reg_vec_a[i] * reg_vec_b[i];
        end
    endgenerate

    logic [ 4-1:0][17-1:0] sum_level1;
    logic [ 2-1:0][18-1:0] sum_level2;
    logic [19-1:0]         dot_product_int;

    // Tree-based addition using generate
    genvar j;
    generate
        for (j = 0; j < 4; j++) begin : gen_add_stage_1
            assign sum_level1[j] = products[(j*2)+1] + products[(j*2)+1];
        end
    endgenerate

    genvar k;
    generate
        for (k = 0; k < 2; k++) begin : gen_add_state_2
            assign sum_level2[k] = sum_level1[(k*2)] + sum_level1[(k*2)+1];
        end
    endgenerate

    assign dot_product_int = sum_level2[0] + sum_level2[1];

    // Stage_1: Register output
    // #########################################################
    // ENSURE COMPLETION OF ABOVE COMBINATIONAL OPERATION BEFORE
    // NEXT RISING EDGE
    // #########################################################
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            out_valid   <= 1'b0;
            dot_product <= '0;
            out_last    <= 1'b0;
        end else if (reg_compute_begin) begin
            dot_product <= dot_product_int;
            out_valid   <= 1'b1;
            out_last    <= last_stg_0;
        end
    end
endmodule

// Generate block, unpacked vectors for initial registers, products, and intermediary sums
module vector_dot_product_bhv_treeadd_unpacked_8 (
    input  logic [8-1:0][ 8-1:0] vec_a,
    input  logic [8-1:0][ 8-1:0] vec_b,
    input  logic                 clk,
    input  logic                 compute,
    input  logic                 rst_n,
    input  logic                 in_last,
    output logic        [19-1:0] dot_product,
    output logic                 out_valid,
    output logic                 out_last
);

    // Stage_0: Register inputs
    logic         reg_compute_begin;
    int           i;
    logic [8-1:0] reg_vec_a         [8];
    logic [8-1:0] reg_vec_b         [8];
    logic         last_stg_0;

    always_ff @(posedge clk or negedge rst_n) begin : proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            for (i = 0; i < 8; i++) begin
                reg_vec_a[i] <= '0;
                reg_vec_b[i] <= '0;
            end
            last_stg_0 <= 1'b0;
        end else if (compute) begin
            for (i = 0; i < 8; i++) begin
                reg_vec_a[i] <= vec_a[i];
                reg_vec_b[i] <= vec_b[i];
            end
            reg_compute_begin <= 1'b1;
            last_stg_0        <= in_last;
        end
    end

    logic [16-1:0] products       [8];
    logic [17-1:0] sum_l1         [4];
    logic [18-1:0] sum_l2         [2];
    logic [19-1:0] dot_product_in;

    genvar i, j, k;
    generate
        for (i = 0; i < 8; i++) begin : gen_mult
            assign products[i] = reg_vec_a[i] * reg_vec_b[i];  // if using packed 2D, just use [i]
        end

        for (j = 0; j < 4; j++) begin : gen_sum_l1
            assign sum_l1[j] = products[2*j] + products[2*j+1];
        end

        for (k = 0; k < 2; k++) begin : gen_sum_l2
            assign sum_l2[k] = sum_l1[2*k] + sum_l1[2*k+1];
        end
    endgenerate

    assign dot_product_int = sum_l2[0] + sum_l2[1];

    // Register outputs
    // #########################################################
    // ENSURE COMPLETION OF ABOVE COMBINATIONAL OPERATION BEFORE
    // NEXT RISING EDGE
    // #########################################################
    always_ff @(posedge clk or negedge rst_n) begin : proc_output
        if (~rst_n) begin
            dot_product <= '0;
            out_valid   <= 1'b0;
            out_last    <= 1'b0;
        end else if (reg_compute_begin) begin
            dot_product <= dot_product_int;
            out_valid   <= 1'b0;
            out_last    <= last_stg_0;
        end
    end
endmodule

// Pipelined, packed vectors for initial registers, unpacked for products, packed intermediary sums
// combinational multiply
module vector_dot_product_bhv_treeadd_pipelined_combMult_8 (
    input  logic [8-1:0][ 8-1:0] vec_a,
    input  logic [8-1:0][ 8-1:0] vec_b,
    input  logic                 clk,
    input  logic                 rst_n,        // Active-low reset
    input  logic                 compute,      // Enable
    input  logic                 in_last,
    output logic        [19-1:0] dot_product,
    output logic                 out_valid,
    output logic                 out_last
);

    // Stage_0: Register inputs
    logic [ 8-1:0][8-1:0] reg_vec_a;
    logic [ 8-1:0][8-1:0] reg_vec_b;
    logic                 valid_stage_0;
    logic [16-1:0]        products      [8];
    logic                 last_stg_0;
    int                   i;

    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_0
        if (~rst_n) begin
            valid_stage_0 <= 1'b0;
            for (i = 0; i < 8; i++) begin  // Maybe I don't need the loop, and direct assignment would work since it's a packed array
                reg_vec_a     <= '0;
                reg_vec_b     <= '0;
                valid_stage_0 <= 1'b0;
            end
            last_stg_0 <= 1'b0;
        end else if (compute) begin
            reg_vec_a     <= vec_a;
            rev_vec_b     <= vec_b;
            valid_stage_0 <= compute;
            last_stg_0    <= in_last;
        end
    end

    // Combinational multiply
    // ##########################################
    // ENSURE COMPLETION BEFORE NEXT RISING EDGE!
    // ##########################################
    // Move to next stage in always_ff if not meeting timing
    genvar g_i;
    generate
        for (g_i = 0; g_i < 8; g_i++) begin : gen_multiply
            assign products[g_i] = reg_vec_a[g_i] * reg_vec_b[g_i];
        end
    endgenerate

    // Stage_1: Sum level 1. Depends on the combinational multiply completing
    // before the next clock edge after input registry
    logic [4-1:0][17-1:0] sum_level1;
    logic                 valid_stage_1;
    logic                 last_stg_1;
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_1
        if (~rst_n) begin
            sum_level1    <= '0;
            valid_stage_1 <= 1'b0;
            last_stg_1    <= 1'b0;
        end else if (valid_stage_0) begin
            for (i = 0; i < 4; i++) begin
                sum_level1[i] <= products[(i*2)] + products[(i*2)+1];
            end
            valid_stage_1 <= valid_stage_0;
            last_stg_1    <= last_stg_0;
        end
    end

    // Stage_2: Adder 1
    logic [2-1:0][18-1:0] sum_level2;
    logic                 valid_stage_2;
    logic                 last_stg_2;
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_2
        if (~rst_n) begin
            sum_level2    <= '0;
            valid_stage_2 <= 1'b0;
            last_stg_2    <= 1'b0;
        end else if (valid_stage_1) begin
            for (i = 0; i < 2; i++) begin
                sum_level2[i] <= sum_level1[(i*2)] + sum_level1[(i*2)+1];
            end
            valid_stage_2 <= valid_stage_1;
            last_stg_2    <= last_stg_1;
        end
    end

    // #############################################
    // THE ABOVE IMPLIES THAT AN ADDER TAKES THE SAME TIME AS A MULTIPLIER
    // If the combinational multiplier can finish before the next clock edge,
    // we can probably do sum_level1 and sum_level2 in a single stage.

    // Stage_final: Register output
    always_ff @(posedge clk or negedge rst_n) begin : proc_final
        if (~rst_n) begin
            dot_product <= '0;
            out_valid   <= 1'b0;
            out_last    <= 1'b0;
        end else if (valid_stage_2) begin
            dot_product <= sum_level2[0] + sum_level2[1];
            out_valid   <= valid_stage_2;
            out_last    <= last_stg_2;
        end
    end
endmodule

// Pipelined, unpacked products, packed intermediary sums
module vector_dot_product_bhv_treeadd_pipelined_8 (
    input  logic [8-1:0][ 8-1:0] vec_a,
    input  logic [8-1:0][ 8-1:0] vec_b,
    input  logic                 clk,
    input  logic                 rst_n,        // Active-low reset
    input  logic                 compute,      // Enable
    input  logic                 in_last,      // to propage last
    output logic        [19-1:0] dot_product,
    output logic                 out_valid,
    output logic                 out_last
);

    // Stage_0: Multiply
    logic          valid_stage_0;
    logic [16-1:0] products      [8];
    logic          last_stg_0;
    int            i;

    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_0
        if (~rst_n) begin
            valid_stage_0 <= 1'b0;
            for (i = 0; i < 8; i++) begin
                products[i]   <= '0;
                valid_stage_0 <= 1'b0;
            end
            last_stg_0 <= 1'b0;
        end else if (compute) begin
            for (i = 0; i < 8; i++) begin
                products[i] <= vec_a[i] * vec_b[i];
            end
            valid_stage_0 <= compute;
            last_stg_0    <= in_last;
        end else begin
            valid_stage_0 <= 1'b0;
            last_stg_0    <= 1'b0;
        end
    end

    // Stage_1: Sum level 1
    logic [4-1:0][17-1:0] sum_level1;
    logic                 valid_stage_1;
    logic                 last_stg_1;
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_1
        if (~rst_n) begin
            sum_level_1   <= '0;
            valid_stage_1 <= 1'b0;
            last_stg_1    <= 1'b0;
        end else if (valid_stage_0) begin
            for (i = 0; i < 4; i++) begin
                sum_level1[i] <= products[(i*2)] + products[(i*2)+1];
            end
            valid_stage_1 <= valid_stage_0;
            last_stg_1    <= last_stg_0;
        end else begin
            valid_stage_1 <= 1'b0;
            last_stg_1    <= 1'b0;
        end
    end

    // Stage_2: Sum level 2
    logic [2-1:0][18-1:0] sum_level2;
    logic                 valid_stage_2;
    logic                 last_stg_2;
    always_ff @(posedge clk or negedge rst_n) begin : proc_stage_2
        if (~rst_n) begin
            sum_level2    <= '0;
            valid_stage_2 <= 1'b0;
            last_stg_2    <= 1'b0;
        end else if (valid_stage_1) begin
            for (i = 0; i < 2; i++) begin
                sum_level2[i] <= sum_level1[(i*2)] + sum_level1[(i*2)+1];
            end
            valid_stage_2 <= valid_stage_1;
            last_stg_2    <= last_stg_1;
        end else begin
            valid_stage_2 <= 1'b0;
            last_stg_2    <= 1'b0;
        end
    end

    // #############################################
    // THE ABOVE IMPLIES THAT AN ADDER TAKES THE SAME TIME AS A MULTIPLIER
    // If the combinational multiplier can finish before the next clock edge,
    // we can probably do sum_level1 and sum_level2 in a single stage.

    // Stage_final: Register output
    always_ff @(posedge clk or negedge rst_n) begin : proc_final
        if (~rst_n) begin
            dot_product <= '0;
            out_valid   <= 1'b0;
            out_last    <= 1'b0;
        end else if (valid_stage_2) begin
            dot_product <= sum_level2[0] + sum_level2[1];
            out_valid   <= valid_stage_2;
            out_last    <= last_stg_2;
        end else begin
            out_valid <= 1'b0;
            out_last  <= 1'b0;
        end
    end
endmodule

// Generate block, unpacked vectors for initial registers, products, and intermediary sums
// Claude: Using systemverilog array sum function
// ################# Not compiling. Apparently needs IP########################
// module vector_dot_product_8_bhv_funadd (
//     input  logic [8-1:0][8-1:0] vec_a, vec_b,  // 2D packed array
//     output logic [19-1:0]     dot_product
// );
//     // Using SystemVerilog reduction
//     logic [15:0] products [8];

//     always_comb begin
//         for (int i = 0; i < 8; i++) begin
//             products[i] = vec_a[i] * vec_b[i];
//         end

//         // Could use array reduction functions
//         dot_product = products.sum();  // SystemVerilog array method
//     end
// endmodule
