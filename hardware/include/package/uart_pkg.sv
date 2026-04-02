// Package: uart_pkg
//
// Packed struct type definitions and register offsets for the
// AXI4-Lite UART peripheral in SC-SoC.
// Follows S1 reference design pattern.

`include "axi4l/typedef.svh"

package uart_pkg;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // REGISTER OFFSETS
  //////////////////////////////////////////////////////////////////////////////////////////////////

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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4-LITE INTERFACE TYPE DEFINITIONS
  // ADDR=32, DATA=32 matching SC-SoC defaults
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(uart_axil, 32, 32)
  // Generates:
  //   uart_axil_aw_chan_t  — {addr[31:0], prot[2:0]}
  //   uart_axil_w_chan_t   — {data[31:0], strb[3:0]}
  //   uart_axil_b_chan_t   — {resp[1:0]}
  //   uart_axil_ar_chan_t  — {addr[31:0], prot[2:0]}
  //   uart_axil_r_chan_t   — {data[31:0], resp[1:0]}
  //   uart_axil_req_t      — packed struct of all request channels
  //   uart_axil_rsp_t      — packed struct of all response channels

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_CTRL — Control Register (offset 0x000, RW, reset 0x00000000)
  //
  //  bit 4 : rx_en         — RX enable
  //  bit 3 : tx_en         — TX enable
  //  bit 2 : rx_fifo_flush — flush RX FIFO
  //  bit 1 : tx_fifo_flush — flush TX FIFO
  //  bit 0 : uart_rst      — software reset
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [26:0] reserved;          // bits 31:5 — reserved, always 0
    logic        rx_en;             // bit 4
    logic        tx_en;             // bit 3
    logic        rx_fifo_flush;     // bit 2
    logic        tx_fifo_flush;     // bit 1
    logic        uart_rst;          // bit 0
  } uart_ctrl_reg_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_CFG — Configuration Register (offset 0x004, RW, reset 0x0003405B)
  //
  //  bits 31:21 : reserved
  //  bit  20    : sb      — stop bits (0=1stop, 1=2stop)
  //  bit  19    : ptp     — parity type (0=even, 1=odd)
  //  bit  18    : pen     — parity enable
  //  bits 17:16 : db      — data bits (0=5, 1=6, 2=7, 3=8)
  //  bits 15:12 : psclr   — prescaler
  //  bits 11:0  : clk_div — clock divider
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [10:0] reserved;  // bits 31:21
    logic        sb;        // bit 20
    logic        ptp;       // bit 19
    logic        pen;       // bit 18
    logic [1:0]  db;        // bits 17:16
    logic [3:0]  psclr;     // bits 15:12
    logic [11:0] clk_div;   // bits 11:0
  } uart_cfg_reg_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_STAT — Status Register (offset 0x008, RO, reset 0x00500000)
  //
  //  bits 31:24 : reserved
  //  bit  23    : rx_full  — RX FIFO full
  //  bit  22    : rx_empty — RX FIFO empty
  //  bit  21    : tx_full  — TX FIFO full
  //  bit  20    : tx_empty — TX FIFO empty
  //  bits 19:10 : rx_cnt   — RX FIFO count
  //  bits  9:0  : tx_cnt   — TX FIFO count
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [ 7:0] reserved; // bits 31:24
    logic        rx_full;  // bit 23
    logic        rx_empty; // bit 22
    logic        tx_full;  // bit 21
    logic        tx_empty; // bit 20
    logic [ 9:0] rx_cnt;   // bits 19:10
    logic [ 9:0] tx_cnt;   // bits 9:0
  } uart_stat_reg_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_INT_EN — Interrupt Enable Register (offset 0x030, RW, reset 0x00000000)
  //
  //  bits 31:4 : reserved
  //  bit  3    : rx_full_en  — RX FIFO full interrupt enable
  //  bit  2    : rx_empty_en — RX FIFO empty interrupt enable
  //  bit  1    : tx_full_en  — TX FIFO full interrupt enable
  //  bit  0    : tx_empty_en — TX FIFO empty interrupt enable
  //////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [27:0] reserved;    // bits 31:4
    logic        rx_full_en;  // bit 3
    logic        rx_empty_en; // bit 2
    logic        tx_full_en;  // bit 1
    logic        tx_empty_en; // bit 0
  } uart_int_reg_t;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // HELPER TYPES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // 8-bit master ID for TX/RX arbitration queues
  typedef struct packed {
    logic [7:0] id;
  } uart_id_t;

  // 8-bit data byte
  typedef struct packed {
    logic [7:0] data;
  } uart_data_t;

  // 10-bit FIFO count
  typedef struct packed {
    logic [9:0] count;
  } uart_count_t;

endpackage
