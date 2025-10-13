module vector_dot_product_long (
    input  logic                 clk,
    input  logic                 compute,
    input  logic                 rst_n,
    input        [8-1:0][ 8-1:0] t_data,
    input        [8-1:0][ 8-1:0] weights,
    output                       out_valid,
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

    always_ff @(posedge clk or negedge rst_n) begin : proc_manage_state
        if (~rst_n) state <= IDLE;
        else begin
            unique case (state)
                IDLE:    if (compute & ~compute_int) state <= ACCUM;
                ACCUM:   if (~compute & compute_int) state <= LAST;
                LAST:    if (compute & ~compute_int) state <= ACCUM;
 else state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    logic [32-1:0] accumulator;


endmodule
