# UART Subsystem for AXI4-Lite

## 1. Scope

This document defines a UART subsystem connected to an AXI4-Lite bus. The subsystem contains these blocks:

- AXI4-Lite Slave
- Register Interface
- CDC FIFO
- UART Transmitter
- UART Receiver

The design supports bus-side register access and UART-side serial transmit/receive operation.

---

## 2. Top-Level Architecture

![UART Subsystem Block Diagram](./uart_subsytem_topview.svg)

## 3. Block Description

### 3.1 AXI4-Lite Slave

Bus-facing protocol block.

Functions:
- accepts AXI4-Lite read/write transactions
- generates AXI responses
- converts bus transactions into internal register accesses

### 3.2 Register Interface

Programmer-visible control/status layer.

Functions:
- stores UART control and configuration fields
- returns status on reads
- generates internal control signals
- interfaces between AXI logic and UART data path

### 3.3 CDC FIFO

Clock-domain crossing buffer between AXI/register side and UART side.

Functions:
- transfers data safely across clock domains
- decouples bus timing from UART timing
- provides FIFO flow control as required

Implementation can use:
- one CDC FIFO block
- separate TX and RX CDC FIFOs

### 3.4 UART Transmitter

Serial transmit engine.

Functions:
- consumes transmit data from CDC FIFO path
- generates UART frame
- drives `uart_tx_o`

Typical framing:
- start bit
- data bits
- optional parity
- stop bit(s)

### 3.5 UART Receiver

Serial receive engine.

Functions:
- samples `uart_rx_i`
- reconstructs UART frame
- delivers receive data into CDC FIFO / register path

---

## 4. Data Flow

### 4.1 TX Path

1. AXI write transaction reaches AXI4-Lite Slave
2. Register Interface decodes control/data write
3. TX data is written into CDC FIFO
4. UART Transmitter reads data in UART clock domain
5. UART Transmitter serializes and drives `uart_tx_o`

### 4.2 RX Path

1. UART Receiver samples `uart_rx_i`
2. Received data is pushed into CDC FIFO
3. Register Interface exposes receive data/status
4. AXI4-Lite Slave returns data on AXI read transaction

---

## 5. Clocking

### Single-clock option
All blocks use `ACLK_i`.

### Multi-clock option
- AXI side uses `ACLK_i`
- UART side uses `uart_clk_i`
- CDC FIFO handles domain crossing

Suggested resets:
- `ARESETn_i` for AXI domain
- `uart_rst_n_i` for UART domain

---

## 6. Interface Naming

Naming convention:
- inputs end with `_i`
- outputs end with `_o`

Examples:
- `ACLK_i`
- `ARESETn_i`
- `uart_tx_o`
- `uart_rx_i`
- `S_AXI_AWADDR_i`
- `S_AXI_AWREADY_o`

---

## 7. Example Top-Level Ports

```text
module uart_axi4lite_subsystem (
    input  logic        ACLK_i,
    input  logic        ARESETn_i,

    input  logic [31:0] S_AXI_AWADDR_i,
    input  logic [2:0]  S_AXI_AWPROT_i,
    input  logic        S_AXI_AWVALID_i,
    output logic        S_AXI_AWREADY_o,

    input  logic [31:0] S_AXI_WDATA_i,
    input  logic [3:0]  S_AXI_WSTRB_i,
    input  logic        S_AXI_WVALID_i,
    output logic        S_AXI_WREADY_o,

    output logic [1:0]  S_AXI_BRESP_o,
    output logic        S_AXI_BVALID_o,
    input  logic        S_AXI_BREADY_i,

    input  logic [31:0] S_AXI_ARADDR_i,
    input  logic [2:0]  S_AXI_ARPROT_i,
    input  logic        S_AXI_ARVALID_i,
    output logic        S_AXI_ARREADY_o,

    output logic [31:0] S_AXI_RDATA_o,
    output logic [1:0]  S_AXI_RRESP_o,
    output logic        S_AXI_RVALID_o,
    input  logic        S_AXI_RREADY_i,

    input  logic        uart_clk_i,
    input  logic        uart_rst_n_i,

    output logic        uart_tx_o,
    input  logic        uart_rx_i
);
```

---

## 8. AXI4-Lite Notes

The UART subsystem is a control-register style peripheral, so AXI4-Lite is appropriate.

Required bus behavior:
- single-beat read/write transactions
- VALID/READY handshake compliance
- protocol-correct read/write responses

Recommended response policy:
- valid access: `OKAY`
- unsupported access: `SLVERR`
- unmapped address: `DECERR` or `SLVERR`

---

## 9. Suggested RTL Hierarchy

```text
uart_axi4lite_subsystem
├── axi4lite_slave
├── uart_register_interface
├── uart_cdc_fifo
├── uart_transmitter
└── uart_receiver
```

Possible expanded version:

```text
uart_axi4lite_subsystem
├── axi4lite_slave
├── uart_register_interface
├── uart_tx_cdc_fifo
├── uart_rx_cdc_fifo
├── uart_transmitter
└── uart_receiver
```

---

## 10. Verification Focus

- AXI4-Lite read/write handshake
- register read/write behavior
- reset behavior
- CDC FIFO correctness
- TX data flow
- RX data flow
- UART TX frame generation
- UART RX frame capture
- clock-domain crossing robustness

---

## 11. Summary

The subsystem is organized as:

- AXI4-Lite Slave
- Register Interface
- CDC FIFO
- UART Transmitter
- UART Receiver

This is a compact and implementation-friendly architecture for an AXI4-Lite UART peripheral.