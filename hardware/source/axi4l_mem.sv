// Module: axi4l_mem
//
// Description:
//   AXI4-Lite slave memory peripheral. Each AXI-Lite channel (AW, W, B, AR, R)
//   is decoupled from the internal logic via a small FIFO, providing registered
//   outputs on every port and isolating the master from back-pressure. An
//   axi4l_mem_ctrlr instance arbitrates read/write requests and drives a
//   dual_port_mem instance that holds the actual data.
//
// Parameters:
//   ADDR_WIDTH - Width of the AXI address bus (default: 32)
//   DATA_WIDTH - Width of the AXI data bus; must be a multiple of 8 (default: 32)

`include "package/defaults_pkg.sv"

`define BIG_MEM_SIMULATION 0

module axi4l_mem #(
    parameter type axi4l_req_t  = defaults_pkg::axi4l_req_t,
    parameter type axi4l_resp_t = defaults_pkg::axi4l_resp_t,
    parameter int  ADDR_WIDTH   = 32,
    parameter int  DATA_WIDTH   = 64
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // GLOBAL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input logic arst_ni,
    input logic clk_i,

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // AXIL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input  axi4l_req_t  axi4l_req_i,
    output axi4l_resp_t axi4l_resp_o

);

`ifdef BIG_MEM_SIMULATION

  `include "axi/typedef.svh"

  `AXI_LITE_TYPEDEF_ALL(axil, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])

  localparam int AXSIZE = $clog2(DATA_WIDTH / 8);

  logic [7:0] mem[2][longint];

  axil_aw_chan_t aw_q[$];
  axil_w_chan_t w_q[$];
  axil_b_chan_t b_q[$];
  axil_ar_chan_t ar_q[$];
  axil_r_chan_t r_q[$];

  always @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      aw_q.delete();
      w_q.delete();
      b_q.delete();
      ar_q.delete();
      r_q.delete();
    end else begin
      if (axi4l_req_i.aw_valid) begin
        aw_q.push_back(axi4l_req_i.aw);
      end
      if (axi4l_req_i.w_valid) begin
        w_q.push_back(axi4l_req_i.w);
      end
      if (axi4l_req_i.b_ready) begin
        b_q.delete(0);
      end
      if (axi4l_req_i.ar_valid) begin
        ar_q.push_back(axi4l_req_i.ar);
      end
      if (axi4l_req_i.r_ready) begin
        r_q.delete(0);
      end
      if (aw_q.size() && w_q.size()) begin
        bit [  ADDR_WIDTH-1:0]      addr;
        bit [DATA_WIDTH/8-1:0][7:0] data;
        bit [DATA_WIDTH/8-1:0]      strb;
        addr = aw_q[0].addr;
        data = w_q[0].data;
        strb = w_q[0].strb;
        for (int i = 0; i < AXSIZE; i++) addr[i] = 0;
        foreach (strb[i]) if (strb[i]) mem[aw_q[0].prot[1]][addr+i] = data[i];
        aw_q.delete(0);
        w_q.delete(0);
        b_q.push_back('0);
      end
      if (ar_q.size()) begin
        bit [  ADDR_WIDTH-1:0]      addr;
        bit [DATA_WIDTH/8-1:0][7:0] data;
        addr = ar_q[0].addr;
        for (int i = 0; i < AXSIZE; i++) addr[i] = 0;
        for (int i = 0; i < DATA_WIDTH / 8; i++) data[i] = mem[ar_q[0].prot[1]][addr+i];
        r_q.push_back({data, 2'b00});
        ar_q.delete(0);
      end
    end
    axi4l_resp_o.aw_ready <= arst_ni;
    axi4l_resp_o.w_ready  <= arst_ni;
    axi4l_resp_o.b        <= b_q.size() ? b_q[0] : '0;
    axi4l_resp_o.b_valid  <= b_q.size() ? '1 : '0;
    axi4l_resp_o.ar_ready <= arst_ni;
    axi4l_resp_o.r        <= r_q.size() ? r_q[0] : '0;
    axi4l_resp_o.r_valid  <= r_q.size() ? '1 : '0;
  end

`else

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // AXI Signals
  axi4l_req_t                     axi4l_req;
  axi4l_resp_t                    axi4l_rsp;

  // Write interface
  logic        [  ADDR_WIDTH-1:0] mem_waddr;
  logic        [  DATA_WIDTH-1:0] mem_wdata;
  logic        [DATA_WIDTH/8-1:0] mem_wstrb;
  logic                           mem_wenable;

  // Read interface
  logic        [  ADDR_WIDTH-1:0] mem_raddr;
  logic        [  DATA_WIDTH-1:0] mem_rdata;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULE INSTANTIATIONS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // AW channel FIFO: buffers incoming write-address beats ({addr, prot}).
  // Depth-2 provides registered outputs and absorbs one cycle of back-pressure.
  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (ADDR_WIDTH + 3),  // addr + 3-bit prot
      .ALLOW_FALLTHROUGH(0)                // registered (no combinational path)
  ) aw_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (axi4l_req_i.aw),
      .data_in_valid_i (axi4l_req_i.aw_valid),
      .data_in_ready_o (axi4l_resp_o.aw_ready),
      .data_out_o      (axi4l_req.aw),
      .data_out_valid_o(axi4l_req.aw_valid),
      .data_out_ready_i(axi4l_rsp.aw_ready),
      .count_o         ()
  );

  // W channel FIFO: buffers incoming write-data beats ({data, strobe}).
  // Strobe width is DATA_WIDTH/8 (one bit per byte lane).
  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (DATA_WIDTH + DATA_WIDTH / 8),  // data + byte-enable strobes
      .ALLOW_FALLTHROUGH(0)
  ) w_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (axi4l_req_i.w),
      .data_in_valid_i (axi4l_req_i.w_valid),
      .data_in_ready_o (axi4l_resp_o.w_ready),
      .data_out_o      (axi4l_req.w),
      .data_out_valid_o(axi4l_req.w_valid),
      .data_out_ready_i(axi4l_rsp.w_ready),
      .count_o         ()
  );

  // B channel FIFO: buffers outgoing write-response beats (2-bit resp).
  // Decouples the controller from master back-pressure on the response channel.
  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (2),  // 2-bit BRESP
      .ALLOW_FALLTHROUGH(0)
  ) b_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (axi4l_rsp.b),
      .data_in_valid_i (axi4l_rsp.b_valid),
      .data_in_ready_o (axi4l_req.b_ready),
      .data_out_o      (axi4l_resp_o.b),
      .data_out_valid_o(axi4l_resp_o.b_valid),
      .data_out_ready_i(axi4l_req_i.b_ready),
      .count_o         ()
  );

  // AR channel FIFO: buffers incoming read-address beats ({addr, prot}).
  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (ADDR_WIDTH + 3),  // addr + 3-bit prot
      .ALLOW_FALLTHROUGH(0)
  ) ar_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (axi4l_req_i.ar),
      .data_in_valid_i (axi4l_req_i.ar_valid),
      .data_in_ready_o (axi4l_resp_o.ar_ready),
      .data_out_o      (axi4l_req.ar),
      .data_out_valid_o(axi4l_req.ar_valid),
      .data_out_ready_i(axi4l_rsp.ar_ready),
      .count_o         ()
  );

  // R channel FIFO: buffers outgoing read-data beats ({data, resp}).
  // Holds the response until the master is ready to accept it.
  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (DATA_WIDTH + 2),  // data + 2-bit RRESP
      .ALLOW_FALLTHROUGH(0)
  ) r_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (axi4l_rsp.r),
      .data_in_valid_i (axi4l_rsp.r_valid),
      .data_in_ready_o (axi4l_req.r_ready),
      .data_out_o      (axi4l_resp_o.r),
      .data_out_valid_o(axi4l_resp_o.r_valid),
      .data_out_ready_i(axi4l_req_i.r_ready),
      .count_o         ()
  );

  // AXI-Lite memory controller: arbitrates between write and read requests,
  // drives the dual-port memory interface, and generates AXI responses.
  axi4l_mem_ctrlr #(
      .axi4l_req_t (axi4l_req_t),
      .axi4l_resp_t(axi4l_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) ctrlr_inst (
      // AXIL signals
      .axi4l_req_i(axi4l_req),
      .axi4l_resp_o(axi4l_rsp),
      .waddr_o   (mem_waddr),
      .wdata_o   (mem_wdata),
      .wstrb_o   (mem_wstrb),
      .wenable_o (mem_wenable),
      .raddr_o   (mem_raddr),
      .rdata_i   (mem_rdata)
  );

  // Dual-port memory: separate write and read ports allow simultaneous
  // access without structural hazards.
  dual_port_mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) mem_inst (
      .clk_i  (clk_i),
      .waddr_i(mem_waddr),
      .we_i   (mem_wenable),
      .wdata_i(mem_wdata),
      .wstrb_i(mem_wstrb),
      .raddr_i(mem_raddr),
      .rdata_o(mem_rdata)
  );

`endif

endmodule
