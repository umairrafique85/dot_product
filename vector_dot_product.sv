// comparator module
module vec_dot_product_8_accum_comparator (
    input logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product_bhv_oai, dot_product_bhv_cld, dot_product_param_bhv_oai
);
    vec_dot_product_8_bhv_oai mdl_dot_prod_oai_1 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_oai)
    );
    vec_dot_product_8_bhv_cld mdl_dot_prod_cld_1 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_cld)
    );
    vec_dot_product_param_bhv_addaccum_oai #(.N(8)) mdl_dot_prod_prm_oai_1 (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_param_bhv_oai)
    );
endmodule

module vec_dot_product_8_treeadd_comparator (
    input logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product_bhv_treeadd_cld, dot_product_bhv_treeadd_packed, dot_product_bhv_treadd_unpacked
);
    vec_dot_product_8_bhv_treeadd_cld (
        .vec_a(vec_a),
        .vec_b(vec_b),
        .dot_product(dot_product_bhv_treeadd_cld)
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
endmodule

// OpenAi
// parallel h/w for multiplies, but adders waiting for previous stage in sequence.
module vec_dot_product_8_bhv_oai (
    input  logic [63:0] vec_a, vec_b,
    output logic [18:0] dot_product
);
    logic [15:0] products [7:0];   // Array of 8 products
    integer i;

    always_comb begin
        for (i = 0; i < 8; i++) begin
            products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8];
        end
    end

    assign dot_product = products[0] + products[1] + products[2] + products[3] +
                          products[4] + products[5] + products[6] + products[7];
endmodule

// Claude
// parallel h/w for multiplies, but adders waiting for previous stage in sequence.
module vec_dot_product_8_bhv_cld (
    input logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product
);
    logic [16-1:0] products [8-1:0];

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin: proc_parallel_mult
            always_comb begin
                products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8];
            end
        end
    endgenerate

    assign dot_product = products[7] + products[6] + products[5] + products[4] +
                        products[3] + products[2] + products[1] + products[0];

endmodule

// OpenAI
// Parameterized. using accumulator, created exact same sequential adder, not tree as OpenAI claimed it would
module vec_dot_product_param_bhv_addaccum_oai #(
    parameter N = 8
) (
    input logic [(N*8)-1:0] vec_a,
    input logic [(N*8)-1:0] vec_b,
    output logic [$clog2(N*256*256)-1:0] dot_product
);
    logic [15:0] products [N-1:0]; // Array of N products
    integer i;

    always_comb begin
        dot_product = '0;
        for (i = 0; i < N; i++) begin
            products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8];
            dot_product += products[i];
        end
    end

endmodule

// Claude
// Using explicit tree-based adder
module vec_dot_product_8_bhv_treeadd_cld (
    input  logic [64-1:0] vec_a, vec_b,
    output logic [19-1:0] dot_product
);
    // Break vectors into individual bytes for clarity
    logic [7:0] a_bytes [7:0];
    logic [7:0] b_bytes [7:0];
    logic [15:0] products [7:0];

    // Extract bytes explicitly
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : proc_extract_multiply
            assign a_bytes[i] = vec_a[i*8 +: 8];
            assign b_bytes[i] = vec_b[i*8 +: 8];
            assign products[i] = a_bytes[i] * b_bytes[i];
        end
    endgenerate

    // Tree-based addition for better timing
    logic [16:0] sum_level1 [3:0];
    logic [17:0] sum_level2 [1:0];

    assign sum_level1[0] = products[0] + products[1];
    assign sum_level1[1] = products[2] + products[3];
    assign sum_level1[2] = products[4] + products[5];
    assign sum_level1[3] = products[6] + products[7];

    assign sum_level2[0] = sum_level1[0] + sum_level1[1];
    assign sum_level2[1] = sum_level1[2] + sum_level1[3];

    assign dot_product = sum_level2[0] + sum_level2[1];
endmodule

// Same target, without intermediary unpacked vectors
module vec_dot_product_8_bhv_treeadd_packed (
    input logic [64-1:0] vec_a, vec_b,
    output [19-1:0] dot_product
);

    logic [15:0] products [8-1:0]; // Array of products

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin: proc_multiply
            assign products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8];
        end
    endgenerate
    
    logic [17*4-1:0] sum_level1;
    logic [18*2-1:0] sum_level2;

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

    assign dot_product = sum_level2[36-1:18] + sum_level2[18-1:0];
endmodule

// Using generate blocks for intermediary addition steps, with unpacked arrays
module vec_dot_product_8_bhv_treeadd_unpacked (
    input  logic [63:0] vec_a, vec_b,
    output logic [18:0] dot_product
);
    logic [15:0] products [8];
    logic [16:0] sum_l1 [4];
    logic [17:0] sum_l2 [2];
    
    genvar i, j, k;
    generate
        for (i = 0; i < 8; i++) begin : gen_mult
            assign products[i] = vec_a[i*8 +: 8] * vec_b[i*8 +: 8];
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