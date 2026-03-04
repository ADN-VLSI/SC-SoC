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

module axil_mem_ctrlr #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // AXIL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // Write address channel
    input  logic [ADDR_WIDTH-1:0] aw_addr_i,
    input  logic [           2:0] aw_prot_i,
    input  logic                  aw_valid_i,
    output logic                  aw_ready_o,

    // Write data channel
    input  logic [  DATA_WIDTH-1:0] w_data_i,
    input  logic [DATA_WIDTH/8-1:0] w_strb_i,
    input  logic                    w_valid_i,
    output logic                    w_ready_o,

    // Write response channel
    output logic [1:0] b_resp_o,
    output logic       b_valid_o,
    input  logic       b_ready_i,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0] ar_addr_i,
    input  logic [           2:0] ar_prot_i,
    input  logic                  ar_valid_i,
    output logic                  ar_ready_o,

    // Read data channel
    output logic [DATA_WIDTH-1:0] r_data_o,
    output logic [           1:0] r_resp_o,
    output logic                  r_valid_o,
    input  logic                  r_ready_i,

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
  always_comb do_write = aw_valid_i & w_valid_i & b_ready_i;

  // Deassert AW/W ready until the response channel is also free, preventing
  // a situation where data is consumed but the response can't be sent.
  always_comb aw_ready_o = do_write;
  always_comb w_ready_o  = do_write;

  // Drive BVALID alongside BREADY so the handshake completes in one cycle.
  always_comb b_valid_o = do_write;

  // Access permission check: only unprivileged non-secure accesses
  // (aw_prot[1:0] == 2'b00) are allowed; anything else returns SLVERR (2'b11).
  always_comb begin
    b_resp_o = 2'b11;  // default: SLVERR
    if (aw_prot_i[1:0] == 2'b00) begin
      b_resp_o = 2'b00;  // OKAY
    end
  end

  // Pass write address, data, and strobe directly to the memory.
  always_comb waddr_o = aw_addr_i;
  always_comb wdata_o = w_data_i;
  always_comb wstrb_o = w_strb_i;

  // Only drive the memory write-enable when the transaction is valid AND the
  // response is OKAY — suppresses writes for rejected (SLVERR) accesses.
  always_comb wenable_o = do_write && (b_resp_o == 2'b00);

  // --- Read path ------------------------------------------------------------

  // Accept a new read address only when the data channel is free, so the
  // combinationally produced read data can be forwarded to the master
  // in the same cycle without being overwritten.
  always_comb ar_ready_o = r_ready_i;

  // Drive the memory read address directly from the incoming AR channel.
  always_comb raddr_o = ar_addr_i;

  // Access permission check: mirrors the write-side policy.
  // On a protected access, return SLVERR and zero data rather than
  // leaking memory contents.
  always_comb begin
    r_resp_o = 2'b11;  // default: SLVERR
    r_data_o = '0;     // default: zero (prevent data leak on rejected reads)
    if (ar_prot_i[1:0] == 2'b00) begin
      r_resp_o = 2'b00;   // OKAY
      r_data_o = rdata_i; // forward memory read data
    end
  end

  // Assert RVALID combinationally with ARVALID — relies on the downstream
  // memory presenting valid data within the same clock cycle.
  always_comb r_valid_o = ar_valid_i;

endmodule
