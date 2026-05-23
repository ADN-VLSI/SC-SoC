// Module: axi4l_mem_ctrlr
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

module axi4l_mem_ctrlr #(
    parameter type axi4l_req_t = defaults_pkg::axi4l_req_t,
    parameter type axi4l_resp_t = defaults_pkg::axi4l_resp_t,
    parameter int  ADDR_WIDTH  = 32,
    parameter int  DATA_WIDTH  = 64
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // AXIL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input  axi4l_req_t axi4l_req_i,
    output axi4l_resp_t axi4l_resp_o,

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

  (* unused = "true" *) logic wnsecure_unused;
  (* unused = "true" *) logic rnsecure_unused;

  axi4l_to_memif #(
      .axi4l_req_t (axi4l_req_t),
      .axi4l_resp_t(axi4l_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) u_axi4l_to_memif (
      .axi4l_req_i (axi4l_req_i),
      .axi4l_resp_o(axi4l_resp_o),
      .waddr_o     (waddr_o),
      .wnsecure_o  (wnsecure_unused),
      .wdata_o     (wdata_o),
      .wstrb_o     (wstrb_o),
      .wenable_o   (wenable_o),
      .werror_i    (1'b0),
      .raddr_o     (raddr_o),
      .rnsecure_o  (rnsecure_unused),
      .rdata_i     (rdata_i),
      .rerror_i    (1'b0)
  );

endmodule