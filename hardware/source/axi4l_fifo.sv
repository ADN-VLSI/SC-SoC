`include "package/uart_pkg.sv"
// AXI4-Lite channel buffer — one fifo.sv per channel
// AW W AR : CPU pushes, register logic pops
// B  R    : register logic pushes, CPU pops (reversed)

module axi4l_fifo

  import uart_pkg::uart_axil_req_t;
  import uart_pkg::uart_axil_resp_t;

#(
    parameter type axi4l_req_t = uart_axil_req_t,
    parameter type axi4l_resp_t = uart_axil_resp_t,
    parameter int  ADDR_WIDTH  = 32,
    parameter int  DATA_WIDTH  = 32,
    parameter int  FIFO_SIZE   = 2
) (
    input  logic       clk_i,
    input  logic       arst_ni,
    input  axi4l_req_t slv_req_i,   // from CPU
    output axi4l_resp_t slv_resp_o,   // to   CPU
    output axi4l_req_t mst_req_o,   // to   register logic
    input  axi4l_resp_t mst_resp_i    // from register logic
);

  // AW FIFO — {prot[2:0], addr[31:0]} = ADDR_WIDTH+3 bits
  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (ADDR_WIDTH + 3),
      .ALLOW_FALLTHROUGH(0)
  ) u_aw_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({slv_req_i.aw.prot, slv_req_i.aw.addr}),
      .data_in_valid_i (slv_req_i.aw_valid),
      .data_in_ready_o (slv_resp_o.aw_ready),
      .data_out_o      ({mst_req_o.aw.prot, mst_req_o.aw.addr}),
      .data_out_valid_o(mst_req_o.aw_valid),
      .data_out_ready_i(mst_resp_i.aw_ready),
      .count_o         ()
  );

  // W FIFO — {strb[3:0], data[31:0]} = DATA_WIDTH+4 bits
  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (DATA_WIDTH + 4),
      .ALLOW_FALLTHROUGH(0)
  ) u_w_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({slv_req_i.w.strb, slv_req_i.w.data}),
      .data_in_valid_i (slv_req_i.w_valid),
      .data_in_ready_o (slv_resp_o.w_ready),
      .data_out_o      ({mst_req_o.w.strb, mst_req_o.w.data}),
      .data_out_valid_o(mst_req_o.w_valid),
      .data_out_ready_i(mst_resp_i.w_ready),
      .count_o         ()
  );

  // B FIFO — {resp[1:0]} = 2 bits  [REVERSED: logic→CPU]
  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (2),
      .ALLOW_FALLTHROUGH(0)
  ) u_b_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (mst_resp_i.b.resp),
      .data_in_valid_i (mst_resp_i.b_valid),
      .data_in_ready_o (mst_req_o.b_ready),
      .data_out_o      (slv_resp_o.b.resp),
      .data_out_valid_o(slv_resp_o.b_valid),
      .data_out_ready_i(slv_req_i.b_ready),
      .count_o         ()
  );

  // AR FIFO — {prot[2:0], addr[31:0]} = ADDR_WIDTH+3 bits
  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (ADDR_WIDTH + 3),
      .ALLOW_FALLTHROUGH(0)
  ) u_ar_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({slv_req_i.ar.prot, slv_req_i.ar.addr}),
      .data_in_valid_i (slv_req_i.ar_valid),
      .data_in_ready_o (slv_resp_o.ar_ready),
      .data_out_o      ({mst_req_o.ar.prot, mst_req_o.ar.addr}),
      .data_out_valid_o(mst_req_o.ar_valid),
      .data_out_ready_i(mst_resp_i.ar_ready),
      .count_o         ()
  );

  // R FIFO — {resp[1:0], data[31:0]} = DATA_WIDTH+2 bits  [REVERSED: logic→CPU]
  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (DATA_WIDTH + 2),
      .ALLOW_FALLTHROUGH(0)
  ) u_r_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({mst_resp_i.r.resp, mst_resp_i.r.data}),
      .data_in_valid_i (mst_resp_i.r_valid),
      .data_in_ready_o (mst_req_o.r_ready),
      .data_out_o      ({slv_resp_o.r.resp, slv_resp_o.r.data}),
      .data_out_valid_o(slv_resp_o.r_valid),
      .data_out_ready_i(slv_req_i.r_ready),
      .count_o         ()
  );

endmodule