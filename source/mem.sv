module mem #(
    // Address width (number of bits for addressing)
    parameter int ADDR_WIDTH = 16,
    // Data width (number of bits for data)
    parameter int DATA_WIDTH = 32
) (
    // Clock input
    input logic clk_i,

    // Address input
    input logic [ADDR_WIDTH-1:0] addr_i,

    // Write enable input
    input logic                    we_i,
    // Write data input
    input logic [  DATA_WIDTH-1:0] wdata_i,
    // Write strobe input (indicates which bytes to write)
    input logic [DATA_WIDTH/8-1:0] wstrb_i,

    // Read data output
    output logic [DATA_WIDTH-1:0] rdata_o
);

endmodule
