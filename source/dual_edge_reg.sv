module dual_edge_reg #(
    parameter WIDTH = 8
) (
    input  logic             arst_ni,
    input  logic             clk_i,
    input  logic             en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o
);

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

  assign data_o = clk_i ? data_p : data_n;  // TODO ALWAYS_COMB

endmodule
