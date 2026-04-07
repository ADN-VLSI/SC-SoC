`ifndef UART_SUBSYSTEM_PKG_SV
`define UART_SUBSYSTEM_PKG_SV

package uart_subsystem_pkg;

  parameter int UART_FIFO_DEPTH = 16;
  parameter int UART_FIFO_COUNT_W = $clog2(UART_FIFO_DEPTH) + 1;

endpackage

`endif