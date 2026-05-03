`ifndef __GUARD_APB_IF_SV__
`define __GUARD_APB_IF_SV__

`include "package/sc_soc_pkg.sv"

interface apb_if #(
    parameter int ADDR_WIDTH = sc_soc_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = sc_soc_pkg::DATA_WIDTH
) (
    input logic clk_i,
    input logic arst_ni
);

  import sc_soc_pkg::*;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `APB_TYPEDEF_ALL(apb, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[STRB_WIDTH-1:0])

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  apb_req_t  req;
  apb_resp_t resp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // post-clock edge alignment for clean driving
  bit is_edge_aligned;
  always @(posedge clk_i) begin
    is_edge_aligned = '1;
    #1;
    is_edge_aligned = '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // RESET TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic req_reset();
    req <= '0;
  endtask

  task automatic resp_reset();
    resp <= '0;
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE TASK
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic write(
      input  logic [ADDR_WIDTH-1:0] addr,
      input  logic [DATA_WIDTH-1:0] data,
      input  logic [STRB_WIDTH-1:0] strb = '1,
      output logic                  slverr
  );
    // Wait for edge alignment — same pattern as axi4l_if
    wait (is_edge_aligned || !arst_ni);

    if (!arst_ni) begin
      req <= '0;
      slverr = '0;
      return;
    end

    // SETUP phase — drive address, data, write signal
    req.psel    <= 1'b1;
    req.penable <= 1'b0;
    req.pwrite  <= 1'b1;
    req.paddr   <= addr;
    req.pwdata  <= data;
    req.pstrb   <= strb;

    // ACCESS phase — assert penable one cycle later
    @(posedge clk_i);
    req.penable <= 1'b1;

    // Wait for PREADY — slave may hold off with pready=0
    do @(posedge clk_i); while (!resp.pready && arst_ni);

    // Capture response
    slverr = resp.pslverr;

    // Return to IDLE — deassert everything
    req <= '0;

  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // READ TASK
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic read(
      input  logic [ADDR_WIDTH-1:0] addr,
      output logic [DATA_WIDTH-1:0] data,
      output logic                  slverr
  );
    // Wait for edge alignment
    wait (is_edge_aligned || !arst_ni);

    if (!arst_ni) begin
      req    <= '0;
      data   =  '0;
      slverr =  '0;
      return;
    end

    // SETUP phase — drive address, deassert write
    req.psel    <= 1'b1;
    req.penable <= 1'b0;
    req.pwrite  <= 1'b0;
    req.paddr   <= addr;
    req.pwdata  <= '0;
    req.pstrb   <= '0;

    // ACCESS phase
    @(posedge clk_i);
    req.penable <= 1'b1;

    // Wait for PREADY
    do @(posedge clk_i); while (!resp.pready && arst_ni);

    // Capture read data and response
    data   = resp.prdata;
    slverr = resp.pslverr;

    // Return to IDLE
    req <= '0;

  endtask


endinterface

`endif