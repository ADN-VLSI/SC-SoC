// Module: axil_mem_ctrlr
//
// Description:
//   Purely combinational AXI4-Lite memory controller. It performs single-cycle
//   write and read transactions with no internal state:
//
//   Write path:
//     A write is accepted when all three write channels (AW, W, B) can complete
//     simultaneously (do_write). The AXI protection bits are used to decide
//     whether the access is permitted; unprivileged non-secure accesses
//     (aw_prot[1:0] == 2'b00) receive OKAY, all others receive SLVERR and
//     the memory write-enable is suppressed.
//
//   Read path:
//     A read address is accepted whenever the read-data channel is free
//     (ar_ready = r_ready). The memory is addressed combinationally, so read
//     data appears in the same cycle. The same protection check applies.
//
// Parameters:
//   ADDR_WIDTH - Width of the address bus (default: 32)
//   DATA_WIDTH - Width of the data bus (default: 32)

`include "package/defaults_pkg.sv"

module axil_mem_ctrlr #(
    parameter type axi4l_req_t = defaults_pkg::axi4l_req_t,
    parameter type axi4l_rsp_t = defaults_pkg::axi4l_rsp_t,
    parameter int  ADDR_WIDTH  = 32,
    parameter int  DATA_WIDTH  = 32
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // AXIL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input  axi4l_req_t axi4l_req_i,
    output axi4l_rsp_t axi4l_rsp_o,

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // MEMORY SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // Write interface
    output logic [  ADDR_WIDTH-1:0] waddr_o,
    output logic [  DATA_WIDTH-1:0] wdata_o,
    output logic [DATA_WIDTH/8-1:0] wstrb_o,
    output logic                    wenable_o,

    // Read interface
    output logic [ADDR_WIDTH-1:0] raddr_o,
    input  logic [DATA_WIDTH-1:0] rdata_i
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // do_write: asserted when a full write transaction can complete in a single
  // cycle — both address and data must be presented by the master (aw_valid &
  // w_valid) AND the master must be ready to accept the response (b_ready).
  logic do_write;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // COMBINATIONAL LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // --- Write path -----------------------------------------------------------

  // Gate write acceptance on all three write channels being simultaneously ready.
  always_comb do_write = axi4l_req_i.aw_valid & axi4l_req_i.w_valid & axi4l_req_i.b_ready;

  // Deassert AW/W ready until the response channel is also free, preventing
  // a situation where data is consumed but the response can't be sent.
  always_comb axi4l_rsp_o.aw_ready = do_write;
  always_comb axi4l_rsp_o.w_ready = do_write;

  // Drive BVALID alongside BREADY so the handshake completes in one cycle.
  always_comb axi4l_rsp_o.b_valid = do_write;

  // Access permission check: only unprivileged non-secure accesses
  // (aw_prot[1:0] == 2'b00) are allowed; anything else returns SLVERR (2'b11).
  always_comb begin
    axi4l_rsp_o.b.resp = 2'b11;  // default: SLVERR
    if (axi4l_req_i.aw.prot[1:0] == 2'b00) begin
      axi4l_rsp_o.b.resp = 2'b00;  // OKAY
    end
  end

  // Pass write address, data, and strobe directly to the memory.
  always_comb waddr_o = axi4l_req_i.aw.addr;
  always_comb wdata_o = axi4l_req_i.w.data;
  always_comb wstrb_o = axi4l_req_i.w.strb;

  // Only drive the memory write-enable when the transaction is valid AND the
  // response is OKAY — suppresses writes for rejected (SLVERR) accesses.
  always_comb wenable_o = do_write && (axi4l_rsp_o.b.resp == 2'b00);

  // --- Read path ------------------------------------------------------------

  // Accept a new read address only when the data channel is free, so the
  // combinationally produced read data can be forwarded to the master
  // in the same cycle without being overwritten.
  always_comb axi4l_rsp_o.ar_ready = axi4l_req_i.r_ready;

  // Drive the memory read address directly from the incoming AR channel.
  always_comb raddr_o = axi4l_req_i.ar.addr;

  // Access permission check: mirrors the write-side policy.
  // On a protected access, return SLVERR and zero data rather than
  // leaking memory contents.
  always_comb begin
    axi4l_rsp_o.r.resp = 2'b11;  // default: SLVERR
    axi4l_rsp_o.r.data = '0;  // default: zero (prevent data leak on rejected reads)
    if (axi4l_req_i.ar.prot[1:0] == 2'b00) begin
      axi4l_rsp_o.r.resp = 2'b00;  // OKAY
      axi4l_rsp_o.r.data = rdata_i;  // forward memory read data
    end
  end

  // Assert RVALID combinationally with ARVALID — relies on the downstream
  // memory presenting valid data within the same clock cycle.
  always_comb axi4l_rsp_o.r_valid = axi4l_req_i.ar_valid;

endmodule
