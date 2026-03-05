`include "axi4l/typedef.svh"

interface axil_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    // GLOBAL SIGNALS
    input logic arst_ni,
    input logic clk_i
);

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
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `define AXIL_METHODS(__CHAN__, __TX__, __RX__)                                                   \
    semaphore send_``__CHAN__``_sem = new(1);                                                      \
    task automatic send_``__CHAN__``(input axi4l_``__CHAN__``_chan_t ``__CHAN__``);                \
      send_``__CHAN__``_sem.get(1);                                                                \
      // TODO FIX EDGE ALIGN ISSUE                                                                 \
      @(posedge clk_i);                                                                            \
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
      // TODO FIX EDGE ALIGN ISSUE                                                                 \
      @(posedge clk_i);                                                                            \
      axi4l_``__RX__``.``__CHAN__``_ready <= 1'b1;                                                 \
      do @(posedge clk_i);                                                                         \
      while (!axi4l_``__TX__``.``__CHAN__``_valid);                                                \
      ``__CHAN__``       = axi4l_``__TX__``.``__CHAN__``;                                          \
      axi4l_``__RX__``.``__CHAN__``_ready <= 1'b0;                                                 \
      send_``__CHAN__``_sem.put(1);                                                                \
    endtask                                                                                        \
                                                                                                   \
    task automatic look_``__CHAN__``(output axi4l_``__CHAN__``_chan_t ``__CHAN__``);               \
      do @(posedge clk_i);                                                                         \
      while (!(axi4l_``__TX__``.``__CHAN__``_valid & axi4l_``__TX__``.``__CHAN__``_ready));        \
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

  `define VALID_READY_PROPERTY_CHECK(__VALID__, __READY__,__SIGNAL__)                 \
    assert property (@(posedge clk_i)                                                 \
      disable iff (!arst_ni)                                                          \
      (``__VALID__`` & !``__READY__``)                                                \
      |=> $stable(``__SIGNAL__``))                                                    \
    else                                                                              \
      $error(`"A valid ``__SIGNAL__`` changed while ``__READY__`` was deasserted`");  \
                                                                                      \
    assert property (@(posedge clk_i)                                                 \
      disable iff (!arst_ni)                                                          \
      ($past(``__VALID__``) && !``__VALID__``)                                        \
      |=> $past(``__READY__``, 2))                                                    \
    else                                                                              \
      $error(`"The ``__VALID__`` deasserted without ``__READY__`` `");                \


  `VALID_READY_PROPERTY_CHECK(axi4l_req.aw_valid, axi4l_rsp.aw_ready, axi4l_req.aw)
  `VALID_READY_PROPERTY_CHECK(axi4l_req.w_valid, axi4l_rsp.w_ready, axi4l_req.w)
  `VALID_READY_PROPERTY_CHECK(axi4l_rsp.b_valid, axi4l_req.b_ready, axi4l_rsp.b)
  `VALID_READY_PROPERTY_CHECK(axi4l_req.ar_valid, axi4l_rsp.ar_ready, axi4l_req.ar)
  `VALID_READY_PROPERTY_CHECK(axi4l_rsp.r_valid, axi4l_req.r_ready, axi4l_rsp.r)

  `undef VALID_READY_PROPERTY_CHECK

endinterface
