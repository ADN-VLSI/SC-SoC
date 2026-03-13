`include "package/defaults_pkg.sv"
`include "vip/valid_ready.svh"

interface axi4l_if #(
    parameter type req_t = defaults_pkg::axi4l_req_t,
    parameter type rsp_t = defaults_pkg::axi4l_rsp_t
) (
    // GLOBAL SIGNALS
    input logic arst_ni,
    input logic clk_i
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  req_t dummy;

  localparam int ADDR_WIDTH = $bits(dummy.aw.addr);
  localparam int DATA_WIDTH = $bits(dummy.w.data);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(axi4l, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_req_t req;
  axi4l_rsp_t rsp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  bit is_edge_aligned;

  always @(posedge clk_i) begin
    is_edge_aligned = '1;
    #1;
    is_edge_aligned = '0;
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic req_reset();
    req <= '0;
  endtask
  
  task automatic rsp_reset();
    rsp <= '0;
  endtask

  `VALID_READY_METHODS(aw, arst_ni, clk_i, axi4l_aw_chan_t, req.aw, req.aw_valid, rsp.aw_ready, is_edge_aligned)
  `VALID_READY_METHODS(w,  arst_ni, clk_i, axi4l_w_chan_t,  req.w,  req.w_valid,  rsp.w_ready,  is_edge_aligned)
  `VALID_READY_METHODS(b,  arst_ni, clk_i, axi4l_b_chan_t,  rsp.b,  rsp.b_valid,  req.b_ready,  is_edge_aligned)
  `VALID_READY_METHODS(ar, arst_ni, clk_i, axi4l_ar_chan_t, req.ar, req.ar_valid, rsp.ar_ready, is_edge_aligned)
  `VALID_READY_METHODS(r,  arst_ni, clk_i, axi4l_r_chan_t,  rsp.r,  rsp.r_valid,  req.r_ready,  is_edge_aligned)

  // send_aw send_w send_b send_ar send_r
  // recv_aw recv_w send_b send_ar send_r
  // look_aw look_w send_b send_ar send_r

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, req.aw, req.aw_valid, rsp.aw_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, req.w,  req.w_valid,  rsp.w_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, rsp.b,  rsp.b_valid,  req.b_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, req.ar, req.ar_valid, rsp.ar_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, rsp.r,  rsp.r_valid,  req.r_ready)

  `undef VALID_READY_PROPERTY_CHECK

endinterface
