# Single Core System on Chip (SC-SoC)

## Architecture Overview

![alt text](arch.svg)

## Input/Output Ports

| Port Name    | Type      | Direction | Description                                  |
| ------------ | --------- | --------- | -------------------------------------------- |
| xtal_in      | logic     | input     | 16MHz Crystal oscillator input               |
| glob_arst_ni | logic     | input     | Active low asynchronous reset                |
| apb_arst_ni  | logic     | input     | Active low asynchronous reset for APB domain |
| apb_clk_i    | logic     | input     | APB clock input                              |
| apb_req_i    | apb_req_t | input     | APB request input                            |
| apb_rsp_o    | apb_rsp_t | output    | APB response output                          |
| uart_tx_o    | logic     | output    | UART transmit output                         |
| uart_rx_i    | logic     | input     | UART receive input                           |

