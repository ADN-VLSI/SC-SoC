`ifndef __GUARD_VIP_VALID_READY_SVH__
`define __GUARD_VIP_VALID_READY_SVH__ 0

  `define VALID_READY_METHODS(__ARST_N__, __CLK__, __SIGNAL_T__, __SIGNAL__, __VALID__, __READY__) \


  `define VALID_READY_PROPERTY_CHECK(__ARST_N__, __CLK__, __SIGNAL__, __VALID__, __READY__)        \
    assert property (@(posedge ``__CLK__``)                                                        \
      disable iff (!``__ARST_N__``)                                                                \
      (``__VALID__`` & !``__READY__``)                                                             \
      |=> $stable(``__SIGNAL__``))                                                                 \
    else                                                                                           \
      $error(`"A valid ``__SIGNAL__`` changed while ``__READY__`` was deasserted`");               \
                                                                                                   \
    assert property (@(posedge ``__CLK__``)                                                        \
      disable iff (!``__ARST_N__``)                                                                \
      ($past(``__VALID__``) && !``__VALID__``)                                                     \
      |=> $past(``__READY__``, 2))                                                                 \
    else                                                                                           \
      $error(`"The ``__VALID__`` deasserted without ``__READY__`` `");                             \



`endif
