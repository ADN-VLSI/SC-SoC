module dual_edge_reg #(
    parameter WIDTH = 8
) (
    input  logic             arst_ni,
    input  logic             clk_i,
    input  logic             en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o
);

`ifdef SYNTHESIS

  logic [WIDTH-1:0] data_p, data_n;

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) data_p <= 0;
    else if (en_i) data_p <= data_i;
    else data_p <= data_n;
  end

  always_ff @(negedge clk_i or negedge arst_ni) begin
    if (!arst_ni) data_n <= 0;
    else if (en_i) data_n <= data_i;
    else data_n <= data_p;
  end
  always_comb data_o = clk_i ? data_p : data_n;

`else

  always @(clk_i or negedge arst_ni) begin
    if (!arst_ni) data_o <= 0;
    else if (en_i) data_o <= data_i;
  end

`endif

endmodule
