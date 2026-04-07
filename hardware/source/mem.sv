/////////////////////////////////////////////////////////////////////////////////////////
// Module        : Memory (mem)
// Update at     : 19 Feb,2026
// Description   : A simple byte-addressable memory module with parameterizable address
//                 and data widths.
// Author        : Md Samir Hasan
//
////////////////////////////////////////////////////////////////////////////////////////

module mem #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic [  ADDR_WIDTH-1:0] addr_i,
    input  logic                    we_i,
    input  logic [  DATA_WIDTH-1:0] wdata_i,
    input  logic [DATA_WIDTH/8-1:0] wstrb_i,
    output logic [  DATA_WIDTH-1:0] rdata_o
);

  dual_port_mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) mem_inst (
      .clk_i(clk_i),
      .waddr_i(addr_i),
      .we_i(we_i),
      .wdata_i(wdata_i),
      .wstrb_i(wstrb_i),
      .raddr_i(addr_i),
      .rdata_o(rdata_o)
  );

endmodule