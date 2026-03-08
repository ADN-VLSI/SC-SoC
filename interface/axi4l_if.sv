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

  axi4l_req_t axi4l_req;
  axi4l_rsp_t axi4l_rsp;

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
    axi4l_req <= '0;
  endtask
  
  task automatic rsp_reset();
    axi4l_rsp <= '0;
  endtask

  `define AXIL_METHODS(__CHAN__, __TX__, __RX__)                                                   \
    semaphore send_``__CHAN__``_sem = new(1);                                                      \
    task automatic send_``__CHAN__``(input axi4l_``__CHAN__``_chan_t ``__CHAN__``);                \
      send_``__CHAN__``_sem.get(1);                                                                \
      wait (is_edge_aligned);                                                                      \
      axi4l_``__TX__``.``__CHAN__``       <= ``__CHAN__``;                                         \
      axi4l_``__TX__``.``__CHAN__``_valid <= 1'b1;                                                 \
      do @(posedge clk_i);                                                                         \
      while (!axi4l_``__RX__``.``__CHAN__``_ready);                                                \
      axi4l_``__TX__``.``__CHAN__``_valid <= 1'b0;                                                 \
      send_``__CHAN__``_sem.put(1);                                                                \
    endtask                                                                                        \
                                                                                                   \
    semaphore recv_``__CHAN__``_sem = new(1);                                                      \
    task automatic recv_``__CHAN__``(output axi4l_``__CHAN__``_chan_t ``__CHAN__``);               \
      recv_``__CHAN__``_sem.get(1);                                                                \
      wait (is_edge_aligned);                                                                      \
      axi4l_``__RX__``.``__CHAN__``_ready <= 1'b1;                                                 \
      do @(posedge clk_i);                                                                         \
      while (!axi4l_``__TX__``.``__CHAN__``_valid);                                                \
      ``__CHAN__``       = axi4l_``__TX__``.``__CHAN__``;                                          \
      axi4l_``__RX__``.``__CHAN__``_ready <= 1'b0;                                                 \
      recv_``__CHAN__``_sem.put(1);                                                                \
    endtask                                                                                        \
                                                                                                   \
    task automatic look_``__CHAN__``(output axi4l_``__CHAN__``_chan_t ``__CHAN__``);               \
      do @(posedge clk_i);                                                                         \
      while (!(axi4l_``__TX__``.``__CHAN__``_valid & axi4l_``__RX__``.``__CHAN__``_ready));        \
      ``__CHAN__``       = axi4l_``__TX__``.``__CHAN__``;                                          \
    endtask                                                                                        \


  `AXIL_METHODS(aw, req, rsp)
  `AXIL_METHODS(w, req, rsp)
  `AXIL_METHODS(b, rsp, req)
  `AXIL_METHODS(ar, req, rsp)
  `AXIL_METHODS(r, rsp, req)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, axi4l_req.aw, axi4l_req.aw_valid, axi4l_rsp.aw_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, axi4l_req.w,  axi4l_req.w_valid,  axi4l_rsp.w_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, axi4l_rsp.b,  axi4l_rsp.b_valid,  axi4l_req.b_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, axi4l_req.ar, axi4l_req.ar_valid, axi4l_rsp.ar_ready)
  `VALID_READY_PROPERTY_CHECK(arst_ni, clk_i, axi4l_rsp.r,  axi4l_rsp.r_valid,  axi4l_req.r_ready)

  `undef VALID_READY_PROPERTY_CHECK

endinterface
