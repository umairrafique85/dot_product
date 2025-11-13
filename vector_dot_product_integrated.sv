// single module for vector multiplication and accumulation.
module vector_dot_product_fixed_treeadd (
    // input interfaces
    input logic clk,
    input logic rst_n,
    input logic in_valid, // analogous to enable / compute
    input logic in_last,
    output logic in_ready,
    input logic [8-1:0][8-1:0] t_data,
    input logic [8-1:0][8-1:0] weights,
    // output interfaces
    output logic out_valid,
    output logic [32-1:0] dot_product
);
    // Stage 0: Multiply
    logic 
endmodule
