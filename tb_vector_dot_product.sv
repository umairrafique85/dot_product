`timescale 1ns/1ps

module tb_vec_dot_product_param;
    parameter N = 8; // number of n-bit elements
    parameter SCALAR_WIDTH = 8; // width of each element
    parameter DOT_WIDTH = $clog2(N * ((1 << SCALAR_WIDTH) - 1) * ((1 << SCALAR_WIDTH) - 1) + 1); 

    logic [(N * SCALAR_WIDTH) - 1:0] tb_vec_a, tb_vec_b; // Q:chatGPT did this in separate lines, why?
    logic [DOT_WIDTH - 1:0] returned_dot_product;

    logic [SCALAR_WIDTH - 1:0] vec_a_arr, vec_b_arr [N - 1:0]; // what's it for? Also why not single line?

    vec_dot_product_param #(.N(N)) dut (
        .vec_a(tb_vec_a),
        .vec_b(tb_vec_b),
        .dot_product(returned_dot_product)
    );

    // File Handling
    integer int_file, int_lineno = 0, int_status, int_expected, passed = 0, failed = 0;
    string str_line;

    initial begin
        int_file = $fopen("C:/Users/umair/learning/ai_by_hand/dot_product/test_vectors_dot_product_8bit.txt", "r");
        if (int_file) $display("File opened successfully. File handler: %d", int_file);
        else $display("Failed to open file. File handler: %d", int_file);
    end
    /*
    $display("Commencing tests...");
    while (!$feof(int_file)) begin
        int_parsed = $fscanf("[%d %d %d %d %d %d %d %d %d %d] [%d %d %d %d %d %d %d %d %d %d] %d\n",
            );
    end */
endmodule
