////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Clock Divider
//
//    Description : This module divides the input clock frequency by a configurable factor.
//                  The division factor is set by the div_i input. The module supports
//                  asynchronous active-low reset and generates a divided clock output.
//                  See details at document/clk_div.md
//
//    Author      : Motasim Faiyaz
//
//    Date        : February 19, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////

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

logic [DIV_WIDTH-1:0] count;
logic toggle;
logic d_next;

// Counter
always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni)
        count <= 0;
    else if (count == div_i - 1)
        count <= 0;
    else
        count <= count + 1;
end

// Generate toggle pulse
assign toggle = (count == div_i - 1);

// Toggle output data
always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni)
        d_next <= 0;
    else if (toggle)
        d_next <= ~d_next;
end

// Dual edge output
dual_edge_ff u_dual_edge (
    .clk      (clk_i),
    .enable   (toggle),
    .d        (d_next),
    .arst_ni  (arst_ni),
    .q        (clk_o)
);

    
endmodule
