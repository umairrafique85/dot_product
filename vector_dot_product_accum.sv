// comparator module
module vec_dot_product_8_accum_comparator (
    input  logic [64-1:0] vec_a,
    vec_b,
    output logic [19-1:0] dot_product_bhv_oai,
    dot_product_bhv_cld,
    dot_product_param_bhv_oai,
    dot_product_bhv_addaccum_2dinput
);
    vec_dot_product_8_bhv_oai mdl_dot_prod_oai_1 (
        .vec_a      (vec_a),
        .vec_b      (vec_b),
        .dot_product(dot_product_bhv_oai)
    );
    vec_dot_product_8_bhv_cld mdl_dot_prod_cld_1 (
        .vec_a      (vec_a),
        .vec_b      (vec_b),
        .dot_product(dot_product_bhv_cld)
    );
    vec_dot_product_param_bhv_addaccum_oai #(
        .N(8)
    ) mdl_dot_prod_prm_oai_1 (
        .vec_a      (vec_a),
        .vec_b      (vec_b),
        .dot_product(dot_product_param_bhv_oai)
    );
    vec_dot_product_bhv_addaccum_2dinput #(
        .ELEMENT_WIDTH(8),
        .NUM_ELEMENTS (8)
    ) mdl_dot_prod_addaccum_1 (
        .vec_a      (vec_a),
        .vec_b      (vec_b),
        .dot_product(dot_product_bhv_addaccum_2dinput)
    );
endmodule


// OpenAi
// parallel h/w for multiplies, but adders waiting for previous stage in sequence.
module vec_dot_product_8_bhv_oai (
    input  logic [63:0] vec_a,
    vec_b,
    output logic [18:0] dot_product
);
    logic   [15:0] products[7:0];  // Array of 8 products
    integer        i;

    always_comb begin
        for (i = 0; i < 8; i++) begin
            products[i] = vec_a[i*8+:8] * vec_b[i*8+:8];
        end
    end

    assign dot_product = products[0] + products[1] + products[2] + products[3] + products[4] + products[5] + products[6] + products[7];
endmodule

// Claude
// parallel h/w for multiplies, but adders waiting for previous stage in sequence.
module vec_dot_product_8_bhv_cld (
    input  logic [64-1:0] vec_a,
    vec_b,
    output logic [19-1:0] dot_product
);
    logic [16-1:0] products[8-1:0];

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : proc_parallel_mult
            always_comb begin
                products[i] = vec_a[i*8+:8] * vec_b[i*8+:8];
            end
        end
    endgenerate

    assign dot_product = products[7] + products[6] + products[5] + products[4] + products[3] + products[2] + products[1] + products[0];

endmodule

// OpenAI
// Parameterized. using accumulator, created exact same sequential adder, not tree as OpenAI claimed it would
module vec_dot_product_param_bhv_addaccum_oai #(
    parameter N = 8
) (
    input  logic [            (N*8)-1:0] vec_a,
    input  logic [            (N*8)-1:0] vec_b,
    output logic [$clog2(N*256*256)-1:0] dot_product
);
    logic   [N*2-1:0] products[N-1:0];  // Array of N products
    integer           i;

    always_comb begin
        dot_product = '0;
        for (i = 0; i < N; i++) begin
            products[i] = vec_a[i*8+:8] * vec_b[i*8+:8];
            dot_product += products[i];
        end
    end

endmodule

// 2D input vector
module vec_dot_product_bhv_addaccum_2dinput #(
    parameter int NUM_ELEMENTS  = 8,
    parameter int ELEMENT_WIDTH = 8
) (
    input  logic [ELEMENT_WIDTH-1:0][                              NUM_ELEMENTS-1:0] vec_a,
    vec_b,
    output logic                    [$clog2(NUM_ELEMENTS*(2**ELEMENT_WIDTH)**2)-1:0] dot_product
);
    logic [ELEMENT_WIDTH*2-1:0] products[NUM_ELEMENTS-1:0];  // Array of N products
    genvar i;
    generate
        for (i = 0; i < NUM_ELEMENTS; i++) begin : gen_dot_product
            assign products[i] = vec_a[i] * vec_b[i];
        end
    endgenerate
    assign dot_product = products[7] + products[6] + products[5] + products[4] + products[3] + products[2] + products[1] + products[0];
endmodule

// Claude: PARAMETERIZED VERSION:
// using function for treeadder
// ############## DOES NOT CREATE TREEADDER LIKE CLAUDE CLAIMED ###############
module vector_dot_product_8_bhv_treeadd_param #(
    parameter int NUM_ELEMENTS  = 8,
    parameter int ELEMENT_WIDTH = 8,
    parameter int VECTOR_WIDTH  = NUM_ELEMENTS * ELEMENT_WIDTH
) (
    input  logic [ELEMENT_WIDTH-1:0][                                NUM_ELEMENTS-1:0] vec_a,
    vec_b,
    output logic                    [$clog2(NUM_ELEMENTS * (2**ELEMENT_WIDTH)**2)-1:0] dot_product
);
    // Calculate product width: element_width * 2
    localparam int PRODUCT_WIDTH = ELEMENT_WIDTH * 2;

    logic [ELEMENT_WIDTH-1:0] a_elements[NUM_ELEMENTS-1:0];
    logic [ELEMENT_WIDTH-1:0] b_elements[NUM_ELEMENTS-1:0];
    logic [PRODUCT_WIDTH-1:0] products  [NUM_ELEMENTS-1:0];

    // Extract elements and compute products
    genvar i;
    generate
        for (i = 0; i < NUM_ELEMENTS; i++) begin : gen_dot_product
            assign products[i] = vec_a[i] * vec_b[i];
        end
    endgenerate

    // Recursive tree summation function
    function automatic logic [$clog2(NUM_ELEMENTS * (2**ELEMENT_WIDTH)**2)-1:0] sum_products;
        input logic [PRODUCT_WIDTH-1:0] prods[NUM_ELEMENTS-1:0];
        logic [$clog2(NUM_ELEMENTS * (2**ELEMENT_WIDTH)**2)-1:0] result;
        begin
            result = 0;
            for (int j = 0; j < NUM_ELEMENTS; j++) begin
                result = result + prods[j];
            end
            sum_products = result;
        end
    endfunction

    assign dot_product = sum_products(products);
endmodule
