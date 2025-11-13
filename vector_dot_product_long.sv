// wrapper around atomic vector multiplier to accumulate
module vector_dot_product_long (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 compute,
    input logic in_last,
    input logic      [8-1:0][ 8-1:0] t_data,
    input logic     [8-1:0][ 8-1:0] weights,
    output logic                      out_valid,
    output logic        [32-1:0] dot_product
);
    logic compute_int;
    // to detect change in compute signal
    always_ff @(posedge clk or negedge rst_n) begin : proc_register_compute
        if (~rst_n) compute_int <= 1'b0;
        else compute_int <= compute;
    end

    typedef enum logic [2-1:0] {
        IDLE,
        ACCUM,
        LAST
    } state_t;
    state_t state;

    // *** WILL NEED A GAP BETWEEN 2 VECTORS SO THERE'S AT LEAST ONE
    // DEASSIRTION OF COMPUTE ***
    always_ff @(posedge clk or negedge rst_n) begin : proc_manage_state
        if (~rst_n) state <= IDLE;
        else begin
            unique case (state)
                IDLE:    if (compute & ~compute_int) state <= ACCUM;
                ACCUM:   if (~compute & compute_int) state <= LAST;
                LAST:    if (compute & ~compute_int) state <= ACCUM; else state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    logic [32-1:0] accumulator;
    logic          last_d;  // To send last signal to internal vector adder module
    logic          compute_d; // WHY THE FUCK DO I NEED THIS!?
    logic          last_q;

    assign compute_d = (state == ACCUM | state == LAST);
    assign last_d    = state == LAST;

    vector_dot_product_bhv_treeadd_explicit_8 vector_processor (
        .vec_a      (t_data),
        .vec_b      (weights),
        .clk        (clk),
        .rst_n      (rst_n),
        .compute    (compute_d),
        .in_last    (last_d),
        .dot_product(accumulator),
        .out_last   (last_q)
    );

    assign out_valid = last_q;
endmodule
