module clk_div #(
    // width of the clock divider input
    parameter int DIV_WIDTH = 4
) (
    // active low asynchronous reset
    input logic                 arst_ni,
    // input clock
    input logic                 clk_i,
    // input clock divider
    input logic [DIV_WIDTH-1:0] div_i,

    // output clock
    output logic clk_o
);

endmodule
