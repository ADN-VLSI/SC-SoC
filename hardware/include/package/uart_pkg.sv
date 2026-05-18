`ifndef UART_PKG_SV
`define UART_PKG_SV
`include "axi/typedef.svh"

package uart_pkg;

  // Register offsets
  parameter int UART_CTRL_OFFSET   = 'h00;
  parameter int UART_CFG_OFFSET    = 'h04;
  parameter int UART_STAT_OFFSET   = 'h08;
  parameter int UART_TXR_OFFSET    = 'h10;
  parameter int UART_TXGP_OFFSET   = 'h14;
  parameter int UART_TXG_OFFSET    = 'h18;
  parameter int UART_TXD_OFFSET    = 'h1C;
  parameter int UART_RXR_OFFSET    = 'h20;
  parameter int UART_RXGP_OFFSET   = 'h24;
  parameter int UART_RXG_OFFSET    = 'h28;
  parameter int UART_RXD_OFFSET    = 'h2C;
  parameter int UART_INT_EN_OFFSET = 'h30;

  // AXI4-Lite types: ADDR=6 DATA=32
  `AXI_LITE_TYPEDEF_ALL(uart_axil, logic[5:0], logic[31:0], logic[3:0])

  // UART_CTRL — offset 0x00 | RW | reset 0x00000000
  // [31:5] reserved | [4] rx_en | [3] tx_en | [2] rx_fifo_flush | [1] tx_fifo_flush | [0] uart_rst
  typedef struct packed {
    logic [26:0] reserved;
    logic        rx_en;
    logic        tx_en;
    logic        rx_fifo_flush;
    logic        tx_fifo_flush;
    logic        uart_rst;
  } uart_ctrl_reg_t;

  // UART_CFG — offset 0x04 | RW | reset 0x0003405B
  // [31:21] reserved | [20] sb | [19] ptp | [18] pen | [17:16] db | [15:12] psclr | [11:0] clk_div
  typedef struct packed {
    logic [10:0] reserved;
    logic        sb;
    logic        ptp;
    logic        pen;
    logic [ 1:0] db;
    logic [ 3:0] psclr;
    logic [11:0] clk_div;
  } uart_cfg_reg_t;

  // UART_STAT — offset 0x08 | RO | reset 0x00500000
  // [31:24] reserved | [23] rx_full | [22] rx_empty | [21] tx_full | [20] tx_empty | [19:10] rx_cnt | [9:0] tx_cnt
  typedef struct packed {
    logic [ 7:0] reserved;
    logic        rx_full;
    logic        rx_empty;
    logic        tx_full;
    logic        tx_empty;
    logic [ 9:0] rx_cnt;
    logic [ 9:0] tx_cnt;
  } uart_stat_reg_t;

  // UART_INT_EN — offset 0x30 | RW | reset 0x00000000
  // [31:4] reserved | [3] rx_full_en | [2] rx_empty_en | [1] tx_full_en | [0] tx_empty_en
  typedef struct packed {
    logic [27:0] reserved;
    logic        rx_full_en;
    logic        rx_empty_en;
    logic        tx_full_en;
    logic        tx_empty_en;
  } uart_int_reg_t;

  // Helper types
  typedef struct packed { logic [7:0] id;    } uart_id_t;
  typedef struct packed { logic [7:0] data;  } uart_data_t;
  typedef struct packed { logic [9:0] count; } uart_count_t;

endpackage
`endif
