`ifndef __GUARD_APB_IF_SV__
`define __GUARD_APB_IF_SV__

`include "package/sc_soc_pkg.sv"

interface apb_if #(
  parameter int ADDR_WIDTH = sc_soc_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = sc_soc_pkg::DATA_WIDTH
)(
  input logic clk_i,
  input logic arst_ni
);
  import sc_soc_pkg::*;

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  /////////////////////////////////////////////////////////////////////////////
  // Signals
  /////////////////////////////////////////////////////////////////////////////

  apb_req_t  req;
  apb_resp_t resp;

  /////////////////////////////////////////////////////////////////////////////
  // Tasks
  //
  // Names: apb_read / apb_write
  //   (the testbench calls these names — do NOT use .read()/.write())
  //
  // Both tasks follow the APB3 protocol:
  //   SETUP  phase : psel=1, penable=0  — held for one clk_i cycle
  //   ACCESS phase : psel=1, penable=1  — held until pready=1
  /////////////////////////////////////////////////////////////////////////////

  // -------------------------------------------------------------------------
  // apb_read
  //   paddr  — byte address to read
  //   pdata  — data returned by slave
  //   slverr — asserted if slave signalled an error (pslverr)
  // -------------------------------------------------------------------------
  task automatic apb_read(
    input  logic [ADDR_WIDTH-1:0] paddr,
    output logic [DATA_WIDTH-1:0] pdata,
    output logic                  slverr
  );
    // SETUP phase
    req.paddr   <= paddr;
    req.pwrite  <= 1'b0;
    req.psel    <= 1'b1;
    req.penable <= 1'b0;
    req.pwdata  <= '0;
    req.pstrb   <= '0;
    @(posedge clk_i);

    // ACCESS phase
    req.penable <= 1'b1;
    do begin
      @(posedge clk_i);
    end while (resp.pready == 1'b0);

    // Capture outputs while pready is still high
    pdata  = resp.prdata;
    slverr = resp.pslverr;

    // Return bus to idle
    req.psel    <= 1'b0;
    req.penable <= 1'b0;
    req.pwrite  <= 1'b0;
  endtask

  // -------------------------------------------------------------------------
  // apb_write
  //   paddr  — byte address to write
  //   pdata  — data to write
  //   pwstrb — byte strobes (1 bit per byte)
  //   slverr — asserted if slave signalled an error (pslverr)
  // -------------------------------------------------------------------------
  task automatic apb_write(
    input  logic [ADDR_WIDTH-1:0]  paddr,
    input  logic [DATA_WIDTH-1:0]  pdata,
    input  logic [STRB_WIDTH-1:0]  pwstrb,
    output logic                   slverr
  );
    // SETUP phase
    req.paddr   <= paddr;
    req.pwdata  <= pdata;
    req.pstrb   <= pwstrb;
    req.pwrite  <= 1'b1;
    req.psel    <= 1'b1;
    req.penable <= 1'b0;
    @(posedge clk_i);

    // ACCESS phase
    req.penable <= 1'b1;
    do begin
      @(posedge clk_i);
    end while (resp.pready == 1'b0);

    // Capture error flag
    slverr = resp.pslverr;

    // Return bus to idle
    req.psel    <= 1'b0;
    req.penable <= 1'b0;
    req.pwrite  <= 1'b0;
  endtask

endinterface

`endif // __GUARD_APB_IF_SV__