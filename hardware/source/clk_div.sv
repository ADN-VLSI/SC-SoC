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

  logic [DIV_WIDTH-1:0] div;
  logic [DIV_WIDTH-1:0] cnt;
  logic [DIV_WIDTH-1:0] cnt_next;
  logic                 clk_o_next;
  logic                 clk_r_en;

  always_comb begin : counter_logic
    div = (div_i == 0) ? 1 : div_i;  // Handle zero division case
    cnt_next = (cnt == div - 1) ? 0 : cnt + 1;  // Counter logic for division
  end

  always_comb begin : equals_0
    clk_r_en = (cnt == 0);
  end

  always_comb clk_o_next = ~clk_o;

  dual_edge_reg #(
      .WIDTH(DIV_WIDTH)
  ) cnt_r (
      .arst_ni(arst_ni),
      .clk_i  (clk_i),
      .en_i   (1'b1),
      .data_i (cnt_next),
      .data_o (cnt)

  );

  dual_edge_reg #(
      .WIDTH(1)
  ) clk_r (
      .arst_ni(arst_ni),
      .clk_i  (clk_i),
      .en_i   (clk_r_en),
      .data_i (clk_o_next),
      .data_o (clk_o)
  );

endmodule




