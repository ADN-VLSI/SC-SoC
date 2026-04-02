# AXI4-Lite UART Subsystem Documentation

## Author: Dhruba Jyoti Barua

This document defines a **UART subsystem** connected to an **AXI4-Lite bus interface** with the following components:

1. AXI4-Lite UART register interface  
2. Two CDC FIFOs  
   - TX CDC FIFO  
   - RX CDC FIFO  
3. UART transmitter  
4. UART receiver  
5. Three clock dividers  
   - Prescaler divider  
   - Transmitter clock divider  
   - Receiver clock divider  

The subsystem is intended to provide a memory-mapped UART peripheral with buffered transmit/receive paths, programmable UART frame format, and safe clock-domain crossing between the bus side and UART logic side. The AXI4/AXI4-Lite protocol basis comes from the AMBA AXI specification, where AXI4-Lite is defined as the simpler control-register subset of AXI4. :contentReference[oaicite:0]{index=0}

---

## 1. Subsystem Overview

The UART subsystem is controlled through an **AXI4-Lite slave register interface**. Software configures UART operation through memory-mapped registers such as:

- `UART_CTRL`
- `UART_CFG`
- `UART_STAT`
- `UART_TXD`
- `UART_RXD`
- `UART_INT`

The register interface drives UART configuration and exchanges data with TX/RX FIFOs. The FIFOs isolate software-side accesses from serial line timing and also support safe transfer between different clock domains. The transmit path serializes outgoing bytes to `tx_o`, while the receive path deserializes incoming serial data from `rx_i`. :contentReference[oaicite:1]{index=1} :contentReference[oaicite:2]{index=2}

---

---

## 2. Scope and Design Intent

This UART subsystem is intended to provide a **memory-mapped UART peripheral** connected through an **AXI4-Lite slave interface**. Its scope includes the integration of the AXI4-Lite register interface, TX and RX CDC FIFOs, UART transmitter, UART receiver, and the prescaler/TX/RX clock-divider chain into one complete subsystem.

The design intent is to create a UART block that is:

- **Configurable**, through software-controlled registers for baud rate, prescaler, data bits, parity, and stop bits
- **Clock-domain safe**, by using CDC FIFOs on both transmit and receive paths
- **Buffered**, so software access is decoupled from UART serial timing
- **Modular**, with clearly separated register, FIFO, clocking, TX, and RX blocks
- **SoC-friendly**, so it can be directly integrated into an AXI4-Lite-based system

In operation, software writes transmit data through the register interface, and the subsystem forwards it through the TX FIFO to the UART transmitter. Received serial data follows the reverse path through the UART receiver and RX FIFO back to the register interface. The subsystem also provides status, control, and interrupt support for reliable software interaction.
---

## 3. Functional Data Paths

## 3.1 Transmit Path

Transmit data moves through the subsystem as follows:

1. Software writes a byte to `UART_TXD`
2. AXI-Lite register interface generates:
-tx_data_o[7:0]
-tx_data_valid_o
3. TX CDC FIFO stores the byte in the system clock domain
4. TX CDC FIFO transfers the byte into the TX baud clock domain
5. UART transmitter consumes the byte through valid/ready handshake
6. UART transmitter serializes the byte to tx_o

This matches the intended register-to-FIFO-to-transmitter structure documented by the UART register interface and UART TX module docs.

## 3.2 Receive Path 

Receive data moves through the subsystem as follows:

1. Serial data enters through rx_i
2. UART receiver samples and reconstructs the frame
3. RX CDC FIFO stores the received byte in the RX clock domain
4. RX CDC FIFO transfers the byte into the AXI/system clock domain
5. AXI-Lite register interface receives:
    - rx_data_i[7:0]
    - rx_data_valid_i
6.Software reads the byte from UART_RXD
7. Register interface asserts rx_pop_o to consume the FIFO entry

This matches the RX-side datapath described by the register interface and register map doc

---

## 4. AXI4-Lite UART Register Interface

## 4.1 Purpose

The AXI-Lite UART register interface is the bus-facing slave module. It converts AXI-Lite reads and writes into control, configuration, and data movement inside the UART subsystem. Its documented interface includes AXI-Lite slave ports, UART configuration outputs, TX/RX FIFO datapath ports, and interrupt outputs. 

## 4.2 AXI4-Lite Slave Signals

`awaddr_i`, `awvalid_i`, `awready_o`
`wdata_i`, `wstrb_i`, `wvalid_i`, `wready_o`
`bresp_o`, `bvalid_o`, `bready_i`
`araddr_i`, `arvalid_i`, `arready_o`
`rdata_o`, `rresp_o`, `rvalid_o`, `rready_i`

These match the AXI handshake mechanism where each channel transfers data only when both VALID and READY are asserted.

## 4.3 UART Control Outputs

The register interface drives the UART core through these outputs:

`uart_tx_en_o`
`uart_rx_en_o`
`uart_clk_div_o[11:0]`
`uart_psclr_o[3:0]`
`uart_db_o[1:0]`
`uart_pen_o`
`uart_ptp_o`
`uart_sb_o`
`uart_int_en_o[3:0]`

These outputs come directly from the register interface documentation and map to the UART configuration register fields.

## 4.4 TX CDC FIFO

The TX CDC FIFO transfers outgoing data from the AXI/system clock domain into the transmitter baud clock domain. The FIFO documentation defines a dual-clock structure with:

- write clock : `wr_clk`
- read clock  : `rd_clk`
- write-side valid/ready handshake
- read-side valid/ready handshake
- occupancy counters
- full/empty detection

Important FIFO interface signals:

- `wr_clk`
- `wr_data`
- `wr_valid`
- `wr_ready`
- `wr_count`
- `rd_clk`
- `rd_ready`
- `rd_valid`
- `rd_data`
- `rd_count`

The FIFO is explicitly documented as supporting asynchronous clock crossing and using Gray-code-safe synchronization internally.

### TX FIFO Role in This Subsystem
-Write side clock domain: clk_i (AXI/system clock)
-Read side clock domain: tx_baud_clk
-Input source: AXI-Lite register interface
-Output destination: UART transmitter
### TX FIFO Connection Summary
- `tx_data_o` -> `tx_fifo.wr_data`
- `tx_data_valid_o` -> `tx_fifo.wr_valid`
- `tx_fifo.wr_ready` -> used to derive FIFO-not-full condition
- `tx_fifo.rd_data` -> `uart_tx.data_i`
- `tx_fifo.rd_valid` -> `uart_tx.data_valid_i`
**Important Ready Polarity Note**
The CDC FIFO documentation states that read ready is active-low:
- `rd_ready` = 0 means ready
The UART transmitter uses a normal active-high ready signal:
- `data_ready_o` = 1 means ready
Therefore, a polarity adaptation is required:
- tx_fifo.rd_ready` = `~uart_tx`.`data_ready_o`

This is a necessary glue connection between the FIFO and UART TX.

---

## 4.5 RX CDC FIFO

The RX CDC FIFO transfers received bytes from the UART receiver clock domain back into the AXI/system clock domain. It uses the same FIFO architecture and port behavior as the TX FIFO.

#### RX FIFO Role in This Subsystem

- **Write side clock domain:** `rx_clk` or `rx_sample_clk`
- **Read side clock domain:** `clk_i`
- **Input source:** UART receiver
- **Output destination:** AXI-Lite register interface

### RX FIFO Connection Summary

- `uart_rx.data_o` -> `rx_fifo.wr_data`
- `uart_rx.data_valid_o` -> `rx_fifo.wr_valid`
- `rx_fifo.rd_data` -> `rx_data_i`
- `rx_fifo.rd_valid` -> `rx_data_valid_i`
- `rx_fifo` empty status -> `rx_fifo_empty_i`

### RX FIFO Pop Control

The register interface provides:

- `rx_pop_o`

This is the pop pulse used when software reads `UART_RXD`. Since FIFO read-ready is active-low, the connection should be:

```
rx_fifo.rd_ready = ~rx_pop_o;

```

---

## 4.6 UART Transmitter

The UART transmitter serializes bytes into UART frames and drives the output line `tx_o`.

### UART TX Ports

- `arst_ni`
- `clk_i`
- `data_i[7:0]`
- `data_valid_i`
- `data_ready_o`
- `data_bits_i[1:0]`
- `parity_en_i`
- `parity_type_i`
- `extra_stop_i`
- `tx_o`

### TX Configuration Mapping

- `uart_db_o` -> `uart_tx.data_bits_i`
- `uart_pen_o` -> `uart_tx.parity_en_i`
- `uart_ptp_o` -> `uart_tx.parity_type_i`
- `uart_sb_o` -> `uart_tx.extra_stop_i`

### TX FIFO to UART TX

- `tx_fifo.rd_data` -> `uart_tx.data_i`
- `tx_fifo.rd_valid` -> `uart_tx.data_valid_i`
- `~uart_tx.data_ready_o` -> `tx_fifo.rd_ready`
- `tx_baud_clk` -> `tx_fifo.rd_clk`
- `tx_baud_clk` -> `uart_tx.clk_i`
- `rst_ni` -> `uart_tx.arst_ni`

### Important Note

The CDC FIFO uses active-low `rd_ready`, while `uart_tx.data_ready_o` is active-high.  
Therefore:

```
tx_fifo.rd_ready = ~uart_tx.data_ready_o;

```

---

## 4.7 UART Receiver

The UART receiver performs the reverse operation of the transmitter.

### UART RX Responsibilities

- detect start bit
- sample incoming serial data from `rx_i`
- reconstruct 5/6/7/8-bit data frames
- optionally check parity
- verify stop bit(s)
- generate received byte output
- generate data-valid pulse for RX FIFO write

### Recommended UART RX Interface

``text
- `input  arst_ni`
- `input  clk_i`
- `input  rx_i`
- `input  [1:0] data_bits_i`
- `input  parity_en_i`
- `input  parity_type_i`
- `input  extra_stop_i`
- `output [7:0] data_o`
- `output data_valid_o`
- `input  data_ready_i`
- `output parity_err_o`
- `output frame_err_o`

**RX Configuration Mapping**

- `uart_db_o -> uart_rx.data_bits_i`
- `uart_pen_o -> uart_rx.parity_en_i`
- `uart_ptp_o -> uart_rx.parity_type_i`
- `uart_sb_o -> uart_rx.extra_stop_i`

**If receiver backpressure is supported:**

rx_fifo.wr_ready -> uart_rx.data_ready_i

---

## 4.8 Clock Divider Chain

**The requested three divider blocks**:
- Prescaler divider
- TX divider
- RX divider
**Divider Roles**
- Prescaler divider
- Reduces the main system clock to a lower timing base for UART
**TX divider**
- Generates the transmitter baud clock used by uart_tx
**RX divider**
- Generates the receiver timing clock

---

## 5. Block Diagram

![UART Subsystem Top View](./uart_subsystem_topview.svg)

---

## 6. Register Map Summary

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 7. Register Descriptions

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 8. Detailed Interconnection

### 8.1 Register Interface to TX FIFO

- `axil_uart_regif.tx_data_o`        -> `tx_fifo.wr_data`
- `axil_uart_regif.tx_data_valid_o`  -> `tx_fifo.wr_valid`
- `tx_fifo.wr_ready` / `full logic`    -> `axil_uart_regif.tx_fifo_full_i`
-`clk_i`                           ->`tx_fifo.clk`
- `rst_ni`                         ->`tx_fifo.arst_ni`


### 8.2 TX FIFO TO UART TX

- `tx_fifo.rd_data`          -> `uart_tx.data_i`
- `tx_fifo.rd_valid`         -> `uart_tx.data_valid_i`
- `~uart_tx.data_ready_o`    -> `tx_fifo.rd_ready`
- `tx_baud_clk`              -> `tx_fifo.rd_clk`
- `tx_baud_clk`              -> `uart_tx.clk_i`
- `rst_ni `                  -> `uart_tx.arst_ni`

### 8.3 Register Interface to Clock Dividers

- uart_psclr_o     -> prescaler divider control
- uart_clk_div_o   -> tx divider control
- uart_clk_div_o   -> rx divider control

### 8.4 Register Interface to UART TX/RX Config

- `uart_db_o`   -> `uart_tx.data_bits_i`, `uart_rx.data_bits_i`
- `uart_pen_o`  -> `uart_tx.parity_en_i`, `uart_rx.parity_en_i`
- `uart_ptp_o`  -> `uart_tx.parity_type_i`, `uart_rx.parity_type_i`
- `uart_sb_o`   -> `uart_tx.extra_stop_i`, `uart_rx.extra_stop_i`

### 8.5 UART RX to RX FIFO

- `uart_rx.data_o`        -> `rx_fifo.wr_data`
- `uart_rx.data_valid_o`  -> `rx_fifo.wr_valid`
- `rx_clk/sample_clk `    -> `rx_fifo.wr_clk`
- `rx_clk/sample_clk`     -> `uart_rx.clk_i`
- `rst_ni`                -> `uart_rx.arst_ni`

**If receiver backpressure is supported:**

- `rx_fifo.wr_ready` -> `uart_rx.data_ready_i`

### 8.6 RX FIFO to Register Interface

- `rx_fifo.rd_data`           -> `axil_uart_regif.rx_data_i`
- `rx_fifo.rd_valid`          -> `axil_uart_regif.rx_data_valid_i`
- `rx_fifo empty logic`       -> `axil_uart_regif.rx_fifo_empty_i`
- `~axil_uart_regif.rx_pop_o` -> `rx_fifo.rd_ready`
- `clk_i`                     -> `rx_fifo.rd_clk`
- `rst_ni`                    -> `rx_fifo.arst_ni`

## 9. Interrupt Logic

**A minimal interrupt output can be generated as**:

```
irq_tx_empty = uart_int_en_o[0] & tx_fifo_empty
irq_tx_full  = uart_int_en_o[1] & tx_fifo_full
irq_rx_empty = uart_int_en_o[2] & rx_fifo_empty
irq_rx_full  = uart_int_en_o[3] & rx_fifo_full

irq_o = irq_tx_empty | irq_tx_full | irq_rx_empty | irq_rx_full
```
---

## 10. AXI4-Lite Compliance Notes

The subsystem register interface must obey AXI4-Lite protocol rules:

- write address and write data use separate handshake channels
- read address and read data use separate handshake channels
- transfer occurs only when both `VALID` and `READY` are asserted
- write response must be returned after accepting write transaction information
- read response must be returned only after a valid read address handshake
- `WSTRB` controls which bytes of the 32-bit write data are valid

---

## 11. Reset Behavior

**On reset**:

- UART control registers return to documented defaults
- FIFOs are cleared
- TX becomes idle
- RX state machine resets
- Interrupts are disabled
- AXI response-valid outputs are driven inactive during reset

---

## 12. Recommended Top-Level Port List
```systemverilog
module axi4l_uart_subsystem #(
    parameter int ADDR_WIDTH = 6,
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 16
)(
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // AXI4-Lite slave interface
    input  logic [ADDR_WIDTH-1:0]   awaddr_i,
    input  logic                    awvalid_i,
    output logic                    awready_o,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    input  logic [DATA_WIDTH/8-1:0] wstrb_i,
    input  logic                    wvalid_i,
    output logic                    wready_o,
    output logic [1:0]              bresp_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,

    input  logic [ADDR_WIDTH-1:0]   araddr_i,
    input  logic                    arvalid_i,
    output logic                    arready_o,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    output logic [1:0]              rresp_o,
    output logic                    rvalid_o,
    input  logic                    rready_i,

    // UART serial pins
    input  logic                    rx_i,
    output logic                    tx_o,

    // Interrupt
    output logic                    irq_o
);
```
---

### 13. Recommended Internal Instances

- `u_axil_uart_regif`
- `u_prescaler_div`
- `u_tx_clk_div`
- `u_rx_clk_div`
- `u_tx_cdc_fifo`
- `u_rx_cdc_fifo`
- `u_uart_tx`
- `u_uart_rx`

---

## 14. Final Subsystem Summary

**This UART subsystem should be connected as follows**:

-The AXI4-Lite register interface is the only bus-facing slave
-The TX CDC FIFO bridges `clk_i` to `tx_baud_clk`
-The RX CDC FIFO bridges `rx_clk` to `clk_i`
-The UART transmitter reads from TX CDC FIFO and drives `tx_o`
-The UART receiver samples `rx_i` and writes into RX CDC FIFO
-The prescaler divider creates a lower-rate timing base
-The TX divider generates the transmitter baud clock
-The RX divider generates the receiver timing clock
-UART configuration fields from `UART_CFG` drive both TX and RX formatting
-FIFO status feeds `UART_STAT`
- Interrupt enables from UART_INT combine with FIFO status to generate `irq_o`

---