module vec_dot_product_8_treeadd_comparator (
    input logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product_bhv_treeadd_explicit, dot_product_bhv_treeadd_packed, dot_product_bhv_treadd_unpacked, vec_dot_product_8_bhv_param
);
    vec_dot_product_8_bhv_treeadd_explicit (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_explicit)
    );
    vec_dot_product_8_bhv_treeadd_packed (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_packed)
    );
    vec_dot_product_8_bhv_treeadd_unpacked (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_unpacked)
    );
    vector_dot_product_8_bhv_treeadd_param (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_param)
    );
endmodule

// Using explicit tree-based adder
module vec_dot_product_8_bhv_treeadd_explicit (
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
    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            reg_compute_begin = 1'b0;
        end else if (compute) begin
            reg_compute_begin = 1'b1;
            reg_vec_a <= vec_a;
            reg_vec_b <= vec_b;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : proc_extract_multiply
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

// Same target, generate block, packed intermediary vectors
module vec_dot_product_8_bhv_treeadd_packed (
    input logic [8-1:0][8-1:0] vec_a, vec_b,
    input logic clk,
    input logic rst_n, // Active-low reset
    input logic compute, // Enable
    output logic [19-1:0] dot_product,
    output logic out_valid
);

    logic [15:0] products [8-1:0]; // Array of products
    logic [8-1:0][8-1:0] reg_vec_a, reg_vec_b;
    logic reg_compute_begin;

    always_ff @(posedge clk or negedge rst_n) begin
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
        for (i = 0; i < 8; i++) begin: proc_multiply
            assign products[i] = reg_vec_a[i*8 +: 8] * reg_vec_b[i*8 +: 8];
        end
    endgenerate

    logic [17*4-1:0] sum_level1;
    logic [18*2-1:0] sum_level2;
    logic [19-1:0] dot_product_int;

    // Tree-based addition using generate
    genvar j;
    generate
        for (j = 0; j < 4; j++) begin: proc_add_stage_1
            assign sum_level1[j*17 +: 17] = products[j*2] + products[j*2+1];
        end
    endgenerate

    genvar k;
    generate
        for (k = 0; k < 2; k++) begin: proc_add_state_2
            assign sum_level2[k*18 +: 18] = sum_level1[k*2*17 +: 17] + sum_level1[(k*2+1)*17 +: 17];
        end
    endgenerate

    assign dot_product_int = sum_level2[36-1:18] + sum_level2[18-1:0];

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

// Generate blocks for intermediary addition steps, unpacked arrays
module vec_dot_product_8_bhv_treeadd_unpacked (
    input  logic [63:0] vec_a, vec_b, // can use packed 2D here as well
    output logic [18:0] dot_product
);
    logic [15:0] products [8];
    logic [16:0] sum_l1 [4];
    logic [17:0] sum_l2 [2];

    genvar i, j, k;
    generate
        for (i = 0; i < 8; i++) begin : gen_mult
            assign products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8]; // if using packed 2D, just use [i]
        end

        for (j = 0; j < 4; j++) begin : gen_l1
            assign sum_l1[j] = products[2*j] + products[2*j+1];
        end

        for (k = 0; k < 2; k++) begin : gen_l2
            assign sum_l2[k] = sum_l1[2*k] + sum_l1[2*k+1];
        end
    endgenerate

    assign dot_product = sum_l2[0] + sum_l2[1];
endmodule

// Claude: Using systemverilog array sum function
// ################# Not compiling. Apparently needs IP########################
// module vec_dot_product_8_bhv_funadd (
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
