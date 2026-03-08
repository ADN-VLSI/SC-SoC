`ifndef __GUARD_VIP_VALID_READY_SVH__
`define __GUARD_VIP_VALID_READY_SVH__ 0

  `define VALID_READY_METHODS(__NAME__, __ARST_N__, __CLK__, __SIGNAL_T__, __SIGNAL__, __VALID__, __READY__, __EDGE__) \
                                                                                                                       \
    semaphore send_``__NAME__``_sem = new(1);                                                                          \
    task automatic send_``__NAME__``(input ``__SIGNAL_T__`` bus);                                                      \
      send_``__NAME__``_sem.get(1);                                                                                    \
      wait (``__EDGE__`` || !``__ARST_N__``);                                                                          \
      ``__SIGNAL__`` <= bus;                                                                                           \
      ``__VALID__`` <= ``__ARST_N__``;                                                                                 \
      if (``__ARST_N__``) do @(posedge ``__CLK__`` or negedge ``__ARST_N__``);                                         \
      while (!``__READY__`` && ``__ARST_N__``);                                                                        \
      ``__VALID__`` <= 1'b0;                                                                                           \
      send_``__NAME__``_sem.put(1);                                                                                    \
    endtask                                                                                                            \
                                                                                                                       \
    semaphore recv_``__NAME__``_sem = new(1);                                                                          \
    task automatic recv_``__NAME__``(output ``__SIGNAL_T__`` bus);                                                     \
      recv_``__NAME__``_sem.get(1);                                                                                    \
      wait (``__EDGE__`` || !``__ARST_N__``);                                                                          \
      ``__READY__`` <= ``__ARST_N__``;                                                                                 \
      if (``__ARST_N__``) do @(posedge ``__CLK__`` or negedge ``__ARST_N__``);                                         \
      while (!``__VALID__`` && ``__ARST_N__``);                                                                        \
      bus = ``__SIGNAL__``;                                                                                            \
      ``__READY__`` <= 1'b0;                                                                                           \
      recv_``__NAME__``_sem.put(1);                                                                                    \
    endtask                                                                                                            \
                                                                                                                       \
    task automatic look_``__NAME__``(output ``__SIGNAL_T__`` bus);                                                     \
      if (``__ARST_N__``) do @(posedge ``__CLK__`` or negedge ``__ARST_N__``);                                         \
      while (!(``__VALID__`` & ``__READY__``) && ``__ARST_N__``);                                                      \
      bus = ``__SIGNAL__``;                                                                                            \
    endtask                                                                                                            \


  `define VALID_READY_PROPERTY_CHECK(__ARST_N__, __CLK__, __SIGNAL__, __VALID__, __READY__)                            \
                                                                                                                       \
    assert property (@(posedge ``__CLK__``)                                                                            \
      disable iff (!``__ARST_N__``)                                                                                    \
      (``__VALID__`` & !``__READY__``)                                                                                 \
      |=> $stable(``__SIGNAL__``))                                                                                     \
    else                                                                                                               \
      $error(`"A valid ``__SIGNAL__`` changed while ``__READY__`` was deasserted`");                                   \
                                                                                                                       \
    assert property (@(posedge ``__CLK__``)                                                                            \
      disable iff (!``__ARST_N__``)                                                                                    \
      ($past(``__VALID__``) && !``__VALID__``)                                                                         \
      |=> $past(``__READY__``, 2))                                                                                     \
    else                                                                                                               \
      $error(`"The ``__VALID__`` deasserted without ``__READY__`` `");                                                 \



`endif
