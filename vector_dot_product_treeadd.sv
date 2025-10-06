module vector_dot_product_8_treeadd_comparator_8 (
    input logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product_bhv_treeadd_explicit, dot_product_bhv_treeadd_packed, dot_product_bhv_treadd_unpacked
);
    vector_dot_product_bhv_treeadd_explicit_8 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_explicit)
    );
    vector_dot_product_bhv_treeadd_packed_8 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_packed)
    );
    vector_dot_product_bhv_treeadd_unpacked_8 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_unpacked)
    );
    vector_dot_product_bhv_treeadd_param_8 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_param)
    );
endmodule

// Using explicit tree-based adder
module vector_dot_product_bhv_treeadd_explicit_8 (
    input logic [8-1:0][8-1:0] vec_a, vec_b,
    input logic clk,
    input logic rst_n, // Active-low reset
    input logic compute, // Enable
    output logic [19-1:0] dot_product,
    output logic out_valid
);
    // Break vectors into individual bytes for clarity
    logic [16-1:0] products [8];
    logic [8-1:0][8-1:0] reg_vec_a, reg_vec_b;
    logic reg_compute_begin;

    // Register vectors on first clock edge and mark start of compute
    always_ff @(posedge clk or negedge rst_n) begin: proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            reg_vec_a <= '0;
            reg_vec_b <= '0;
        end else if (compute) begin
            reg_compute_begin <= 1'b1;
            reg_vec_a <= vec_a;
            reg_vec_b <= vec_b;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_extract_multiply
            assign products[i] = reg_vec_a[i] * reg_vec_b[i];
        end
    endgenerate

    // Tree-based
    logic [17-1:0] sum_level1 [4];
    logic [18-1:0] sum_level2 [2];
    logic [19-1:0] dot_product_int;

    assign sum_level1[0] = products[0] + products[1];
    assign sum_level1[1] = products[2] + products[3];
    assign sum_level1[2] = products[4] + products[5];
    assign sum_level1[3] = products[6] + products[7];

    assign sum_level2[0] = sum_level1[0] + sum_level1[1];
    assign sum_level2[1] = sum_level1[2] + sum_level1[3];

    assign dot_product_int = sum_level2[0] + sum_level2[1];

    always_ff @(posedge clk or negedge rst_n) begin: proc_out
        if (!rst_n) begin
            dot_product <= '0;
            valid <= 1'b0;
        end else if (reg_compute_begin) begin // Assert valid on the second clock edge after compute
            dot_product <= dot_product_int;
            valid <= 1'b1;
        end
    end
endmodule

// Same target, generate block, packed vectors for initial vector registers, unpacked vector for products
// packed intermediary sums
module vector_dot_product_bhv_treeadd_packed_8 (
    input logic [8-1:0][8-1:0] vec_a, vec_b,
    input logic clk,
    input logic rst_n, // Active-low reset
    input logic compute, // Enable
    output logic [19-1:0] dot_product,
    output logic out_valid
);

    logic [16-1:0] products [8]; // Array of products
    logic [8-1:0][8-1:0] reg_vec_a, reg_vec_b;
    logic reg_compute_begin;

    always_ff @(posedge clk or negedge rst_n) begin: proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            reg_vec_a <= '0;
            reg_vec_b <= '0;
        end else begin
            reg_compute_begin <= 1'b1;
            reg_vec_a <= vec_a;
            reg_vec_b <= vec_b;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin: gen_multiply
            assign products[i] = reg_vec_a[i] * reg_vec_b[i];
        end
    endgenerate

    logic [17-1:0][4-1:0] sum_level1;
    logic [18-1:0][2-1:0] sum_level2;
    logic [19-1:0] dot_product_int;

    // Tree-based addition using generate
    genvar j;
    generate
        for (j = 0; j < 4; j++) begin: gen_add_stage_1
            assign sum_level1[j] = products[(j*2)+1] + products[(j*2)+1];
        end
    endgenerate

    genvar k;
    generate
        for (k = 0; k < 2; k++) begin: gen_add_state_2
            assign sum_level2[k] = sum_level1[(k*2)] + sum_level1[(k*2)+1];
        end
    endgenerate

    assign dot_product_int = sum_level2[0] + sum_level2[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            out_valid <= 1'b0;
            dot_product <= '0;
        end else if (reg_compute_begin) begin
            dot_product <= dot_product_int;
            out_valid <= 1'b1;
        end
    end
endmodule

// Generate block, unpacked vectors for initial registers, products, and intermediary sums
module vector_dot_product_bhv_treeadd_unpacked_8 (
    input logic [8-1:0][8-1:0] vec_a, vec_b,
    input logic clk,
    input logic compute,
    input logic rst_n,
    output logic [19-1:0] dot_product,
    output logic out_valid
);
    logic reg_compute_begin;
    int i;
    logic [8-1:0] reg_vec_a, reg_vec_b [8];

    always_ff @(posedge clk or negedge rst_n) begin: proc_reg_compute_start
        if (~rst_n) begin
            reg_compute_begin <= 1'b0;
            for (i = 0; i < 8; i++) begin
                reg_vec_a[i] <= '0;
                reg_vec_b[i] <= '0;
            end
        end else if (compute) begin
            for (i = 0; i < 8; i++) begin
                reg_vec_a[i] <= vec_a[i];
                reg_vec_b[i] <= vec_b[i];
            end
            reg_compute_begin <= 1'b1;
        end
    end

    logic [16-1:0] products [8];
    logic [17-1:0] sum_l1 [4];
    logic [18-1:0] sum_l2 [2];
    logic [19-1:0] dot_product_in;

    genvar i, j, k;
    generate
        for (i = 0; i < 8; i++) begin : gen_mult
            assign products[i] = reg_vec_a[i] * reg_vec_b[i]; // if using packed 2D, just use [i]
        end

        for (j = 0; j < 4; j++) begin : gen_sum_l1
            assign sum_l1[j] = products[2*j] + products[2*j+1];
        end

        for (k = 0; k < 2; k++) begin : gen_sum_l2
            assign sum_l2[k] = sum_l1[2*k] + sum_l1[2*k+1];
        end
    endgenerate

    assign dot_product_int = sum_l2[0] + sum_l2[1];

    always_ff @(posedge clk or negedge rst_n) begin: proc_output
        if (~rst_n) begin
            dot_product <= '0;
            out_valid <= 1'b0;
        end else if (reg_compute_begin) begin
            dot_product <= dot_product_int;
            out_valid <= 1'b0;
        end
    end
endmodule

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
