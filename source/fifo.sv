module fifo #(
    // Width of the data bus
    parameter int DATA_WIDTH = 8,
    // Cealing of log2(FIFO_DEPTH)
    parameter int FIFO_SIZE  = 4
    // FIFO_DEPTH = 2 ** FIFO_SIZE
    // FIFO_DEPTH is the number of entries that can be stored in the FIFO
) (
    // Asynchronous reset, active low
    input logic arst_ni,
    // Synchronous clock input
    input logic clk_i,

    // Data input bus
    input  logic [DATA_WIDTH-1:0] data_i,
    // Indicates that the data on the input bus is valid
    input  logic                  data_i_valid_i,
    // Indicates that the FIFO is ready to accept data on the input bus
    output logic                  data_i_ready_o,

    // Data output bus
    output logic [DATA_WIDTH-1:0] data_o,
    // Indicates that the data on the output bus is valid
    output logic                  data_o_valid_o,
    // Indicates that the receiver is ready to accept data on the output bus
    input  logic                  data_o_ready_i
);

endmodule
