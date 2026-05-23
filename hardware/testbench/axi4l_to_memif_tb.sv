`include "axi/typedef.svh"

module axi4l_to_memif_tb;

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;

  `AXI_LITE_TYPEDEF_ALL(my, logic [ADDR_WIDTH-1:0], logic [DATA_WIDTH-1:0],
                        logic [DATA_WIDTH/8-1:0])

  my_req_t  req;
  my_resp_t resp;

  logic [  ADDR_WIDTH-1:0] waddr;
  logic                    wnsecure;
  logic [  DATA_WIDTH-1:0] wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic                    wenable;
  logic                    werror;

  logic [ADDR_WIDTH-1:0] raddr;
  logic                  rnsecure;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  rerror;

  int pass_count;
  int fail_count;

  axi4l_to_memif #(
      .axi4l_req_t (my_req_t),
      .axi4l_resp_t(my_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) dut (
      .axi4l_req_i (req),
      .axi4l_resp_o(resp),
      .waddr_o     (waddr),
      .wnsecure_o  (wnsecure),
      .wdata_o     (wdata),
      .wstrb_o     (wstrb),
      .wenable_o   (wenable),
      .werror_i    (werror),
      .raddr_o     (raddr),
      .rnsecure_o  (rnsecure),
      .rdata_i     (rdata),
      .rerror_i    (rerror)
  );

  task automatic check(input logic ok, input string msg);
    if (ok) begin
      pass_count++;
      $display("[PASS] %s", msg);
    end else begin
      fail_count++;
      $display("[FAIL] %s", msg);
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;

    req    = '0;
    rdata  = 32'hCAFE_BABE;
    werror = 1'b0;
    rerror = 1'b0;

    //--------------------------------------------------------------------------
    // Write path
    //--------------------------------------------------------------------------

    // Disallowed access (prot[1:0] != 2'b00) — SLVERR, write suppressed
    req.aw_valid = 1'b1;
    req.w_valid  = 1'b1;
    req.b_ready  = 1'b1;
    req.aw.addr  = 16'h0014;
    req.aw.prot  = 3'b010;
    req.w.data   = 32'h1234_5678;
    req.w.strb   = 4'b1111;
    #1;
    check(resp.aw_ready && resp.w_ready && resp.b_valid,
          "write handshakes complete in one cycle");
    check(waddr == 16'h0014 && wdata == 32'h1234_5678 && wstrb == 4'b1111,
          "write address/data/strobes are forwarded");
    check(wnsecure == 1'b1, "write non-secure attribute mirrors aw.prot[1]");
    check(resp.b.resp == 2'b11 && !wenable,
          "write with disallowed prot returns SLVERR and suppresses write-enable");

    // Allowed access (prot[1:0] == 2'b00) — OKAY, write-enable asserted
    req.aw.prot = 3'b000;
    #1;
    check(resp.b.resp == 2'b00 && wenable,
          "write with allowed prot returns OKAY and asserts write-enable");
    check(!wnsecure, "secure write clears non-secure flag");

    // Memory write error — SLVERR, write-enable still asserted
    werror = 1'b1;
    #1;
    check(resp.b.resp == 2'b11 && wenable,
          "memory write error propagates as SLVERR without suppressing write-enable");

    // Release write channels
    req.aw_valid = 1'b0;
    req.w_valid  = 1'b0;
    req.b_ready  = 1'b0;
    werror       = 1'b0;

    //--------------------------------------------------------------------------
    // Read path
    //--------------------------------------------------------------------------

    // Disallowed access — SLVERR, data zeroed
    req.ar_valid = 1'b1;
    req.r_ready  = 1'b1;
    req.ar.addr  = 16'h0020;
    req.ar.prot  = 3'b010;
    #1;
    check(resp.ar_ready && resp.r_valid,
          "read handshakes complete in one cycle");
    check(raddr == 16'h0020, "read address is forwarded");
    check(rnsecure == 1'b1, "read non-secure attribute mirrors ar.prot[1]");
    check(resp.r.resp == 2'b11 && resp.r.data == '0,
          "read with disallowed prot returns SLVERR and zeroes data");

    // Allowed access — OKAY, memory data forwarded
    req.ar.prot = 3'b000;
    #1;
    check(resp.r.resp == 2'b00 && resp.r.data == 32'hCAFE_BABE,
          "read with allowed prot returns OKAY and memory data");
    check(!rnsecure, "secure read clears non-secure flag");

    // Memory read error — SLVERR, data zeroed
    rerror = 1'b1;
    #1;
    check(resp.r.resp == 2'b11 && resp.r.data == '0,
          "memory read error propagates as SLVERR and zeroes data");

    // Back-pressure: r_ready deasserted → ar_ready must deassert
    req.r_ready = 1'b0;
    #1;
    check(!resp.ar_ready,
          "read address channel back-pressures when r_ready is low");

    $display("axi4l_to_memif_tb summary: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count != 0) begin
      $fatal(1, "axi4l_to_memif_tb failed");
    end
    $finish;
  end

endmodule
