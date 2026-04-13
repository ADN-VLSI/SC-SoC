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

The UART subsystem is controlled through an **AXI4-Lite slave register interface**. Software configures UART operation through memory-mapped registers: `UART_CTRL`, `UART_CFG`, `UART_STAT`, `UART_TXD`, `UART_RXD`, and `UART_INT`.

The register interface drives UART configuration and exchanges data with TX/RX FIFOs. The FIFOs isolate software-side accesses from serial line timing and support safe transfer between different clock domains. The transmit path serializes outgoing bytes to `tx_o`, while the receive path deserializes incoming serial data from `rx_i`.

---

## 2. Scope and Design Intent

This UART subsystem is intended to provide a **memory-mapped UART peripheral** connected through an **AXI4-Lite slave interface**. Its scope includes the integration of the AXI4-Lite register interface, TX and RX CDC FIFOs, UART transmitter, UART receiver, and the prescaler/TX/RX clock-divider chain into one complete subsystem.

The design intent is to create a UART block that is:

- **Configurable**, through software-controlled registers for baud rate, prescaler, data bits, parity, and stop bits
- **Clock-domain safe**, by using CDC FIFOs on both transmit and receive paths
- **Buffered**, so software access is decoupled from UART serial timing
- **Modular**, with clearly separated register, FIFO, clocking, TX, and RX blocks
- **SoC-friendly**, so it can be directly integrated into an AXI4-Lite-based system

---

## 3. External Port Declarations

### 3.1 Module Parameters

| Parameter    | Default                               | Description                       |
|--------------|---------------------------------------|-----------------------------------|
| `FIFO_DEPTH` | `uart_subsystem_pkg::UART_FIFO_DEPTH` | Depth of both TX and RX CDC FIFOs |

### 3.2 Clock and Reset

| Port      | Direction | Width | Description                   |
|-----------|-----------|-------|-------------------------------|
| `clk_i`   | input     | 1     | System clock                  |
| `arst_ni` | input     | 1     | Asynchronous active-low reset |

### 3.3 AXI4-Lite Slave Interface

| Port             | Direction | Width | AXI Channel    | Description                      |
|------------------|-----------|-------|----------------|----------------------------------|
| `req_i.awaddr`   | input     | 32    | Write Address  | Write address                    |
| `req_i.awvalid`  | input     | 1     | Write Address  | Write address valid              |
| `resp_o.awready` | output    | 1     | Write Address  | Write address ready              |
| `req_i.wdata`    | input     | 32    | Write Data     | Write data                       |
| `req_i.wstrb`    | input     | 4     | Write Data     | Write byte strobes               |
| `req_i.wvalid`   | input     | 1     | Write Data     | Write data valid                 |
| `resp_o.wready`  | output    | 1     | Write Data     | Write data ready                 |
| `resp_o.bresp`   | output    | 2     | Write Response | Write response (`OKAY`/`SLVERR`) |
| `resp_o.bvalid`  | output    | 1     | Write Response | Write response valid             |
| `req_i.bready`   | input     | 1     | Write Response | Write response ready             |
| `req_i.araddr`   | input     | 32    | Read Address   | Read address                     |
| `req_i.arvalid`  | input     | 1     | Read Address   | Read address valid               |
| `resp_o.arready` | output    | 1     | Read Address   | Read address ready               |
| `resp_o.rdata`   | output    | 32    | Read Data      | Read data                        |
| `resp_o.rresp`   | output    | 2     | Read Data      | Read response (`OKAY`/`SLVERR`)  |
| `resp_o.rvalid`  | output    | 1     | Read Data      | Read data valid                  |
| `req_i.rready`   | input     | 1     | Read Data      | Read data ready                  |

> `req_i` and `resp_o` are packed structs of types `uart_pkg::uart_axil_req_t` and `uart_pkg::uart_axil_rsp_t` respectively. A transfer completes on a channel only when both `VALID` and `READY` are asserted simultaneously.

### 3.4 UART Serial Interface

| Port   | Direction | Width | Description               |
|--------|-----------|-------|---------------------------|
| `rx_i` | input     | 1     | UART serial receive line  |
| `tx_o` | output    | 1     | UART serial transmit line |

### 3.5 Interrupt

| Port       | Direction | Width | Description                                             |
|------------|-----------|-------|---------------------------------------------------------|
| `int_en_o` | output    | 1     | Active-high interrupt; OR of all enabled FIFO event sources |

### 3.6 Top-Level Module Declaration

```systemverilog
module uart_subsystem #(
    parameter int FIFO_DEPTH = uart_subsystem_pkg::UART_FIFO_DEPTH
)(
    input  logic                       clk_i,
    input  logic                       arst_ni,

    input  uart_pkg::uart_axil_req_t   req_i,
    output uart_pkg::uart_axil_rsp_t   resp_o,

    input  logic                       rx_i,
    output logic                       tx_o,
    output logic                       int_en_o
);
```

---

## 4. Functional Data Paths

### 4.1 Transmit Path

| Step | Description                                                        |
|------|--------------------------------------------------------------------|
| 1    | Software writes a byte to `UART_TXD`                              |
| 2    | Register interface asserts `tx_data_o[7:0]` and `tx_data_valid_o` |
| 3    | TX CDC FIFO stores the byte in the system clock domain (`clk_i`)  |
| 4    | TX CDC FIFO transfers the byte into the TX baud clock domain       |
| 5    | UART transmitter consumes the byte via valid/ready handshake       |
| 6    | UART transmitter serializes the byte to `tx_o`                    |

### 4.2 Receive Path

| Step | Description                                                             |
|------|-------------------------------------------------------------------------|
| 1    | Serial data enters through `rx_i`                                       |
| 2    | UART receiver samples and reconstructs the frame                        |
| 3    | RX CDC FIFO stores the received byte in the `rx_clk` domain             |
| 4    | RX CDC FIFO transfers the byte into the system clock domain (`clk_i`)   |
| 5    | Register interface receives `rx_data_i[7:0]` and `rx_data_valid_i`     |
| 6    | Software reads the byte from `UART_RXD`                                 |
| 7    | Register interface asserts `rx_data_ready_o` to consume the FIFO entry  |

---

## 5. Internal Architecture

### 5.1 Sub-Module Instances

| Instance          | Module             | Description                                                  |
|-------------------|--------------------|--------------------------------------------------------------|
| `u_axi4l_regif`   | `axi4l_uart_regif` | AXI4-Lite register interface                                 |
| `u_prescaler_div` | `clk_div`          | Prescaler: divides `clk_i` by `uart_cfg.psclr` (4-bit div)  |
| `u_rx_clk_div`    | `clk_div`          | RX clock: divides `prescale_clk` by `clk_div >> 3` (12-bit) |
| `u_tx_clk_div`    | `clk_div`          | TX clock: divides `rx_clk` by fixed 4 (4-bit div)           |
| `u_tx_cdc_fifo`   | `cdc_fifo`         | TX CDC FIFO — crosses data from `clk_i` to `tx_clk`         |
| `u_uart_tx`       | `uart_tx`          | UART transmitter, clocked by `tx_clk`                        |
| `u_uart_rx`       | `uart_rx`          | UART receiver, clocked by `rx_clk`                           |
| `u_rx_cdc_fifo`   | `cdc_fifo`         | RX CDC FIFO — crosses data from `rx_clk` to `clk_i`         |

### 5.2 Clock Domain Chain

```
clk_i  →  [u_prescaler_div ÷ psclr]  →  prescale_clk
                                               ↓
                                  [u_rx_clk_div ÷ (clk_div >> 3)]  →  rx_clk
                                                                            ↓
                                                                   [u_tx_clk_div ÷ 4]  →  tx_clk
```

The RX clock oversamples at 8× the baud rate (the `>> 3` shift). The TX clock divides `rx_clk` by a fixed 4 to yield the baud-rate clock for transmission.

---

## 6. AXI4-Lite Register Interface (`axi4l_uart_regif`)

### 6.1 Purpose

Converts AXI4-Lite reads and writes into control, configuration, and data movement inside the UART subsystem. It is the only bus-facing slave in this subsystem.

### 6.2 UART Control Outputs

| Signal                  | Width  | Description                                         |
|-------------------------|--------|-----------------------------------------------------|
| `uart_ctrl_o`           | struct | Control register fields (tx_en, rx_en, tx_fifo_flush, rx_fifo_flush)|
| `uart_cfg_o`            | struct | Configuration register fields                       |
| `uart_int_en_o`         | struct | Interrupt enable bits                               |
| `tx_data_o`             | 8      | TX byte forwarded to TX FIFO                        |
| `tx_data_valid_o`       | 1      | TX data valid handshake                             |
| `tx_data_ready_i`       | 1      | TX FIFO not-full feedback to register interface     |
| `rx_data_i`             | 8      | RX byte from RX FIFO                               |
| `rx_data_valid_i`       | 1      | RX data available flag                              |
| `rx_data_ready_o`       | 1      | RX FIFO pop/consume control                        |
| `tx_data_cnt_i`         | count  | TX FIFO fill level reported in `UART_STAT`          |
| `rx_data_cnt_i`         | count  | RX FIFO fill level reported in `UART_STAT`          |

---

## 7. TX CDC FIFO (`u_tx_cdc_fifo`)

Transfers outgoing data from `clk_i` into `tx_clk`. Uses Gray-code-safe synchronization internally.

### 7.1 Configuration

| Parameter    | Value        |
|--------------|--------------|
| `DATA_WIDTH` | 8            |
| `FIFO_DEPTH` | `FIFO_DEPTH` |
| Write clock  | `clk_i`      |
| Read clock   | `tx_clk`     |
| Reset        | `arst_ni & ~uart_ctrl.tx_fifo_flush` |

### 7.2 Signal Connections

| FIFO Port    | Connected To                    | Direction |
|--------------|---------------------------------|-----------|
| `wr_clk_i`   | `clk_i`                         | →         |
| `wr_data_i`  | `tx_data_from_regif.data`       | →         |
| `wr_valid_i` | `tx_data_valid_from_regif`      | →         |
| `wr_ready_o` | `tx_data_ready_to_regif`        | ←         |
| `wr_count_o` | `tx_fifo_wr_count`              | ←         |
| `rd_clk_i`   | `tx_clk`                        | →         |
| `rd_ready_i` | `tx_fifo_rd_ready`              | →         |
| `rd_valid_o` | `tx_fifo_rd_valid`              | ←         |
| `rd_data_o`  | `tx_fifo_rd_data`               | ←         |
| `rd_count_o` | `tx_fifo_rd_count`              | ←         |

```
tx_fifo_rd_ready = tx_data_ready_from_uart & uart_ctrl.tx_en
```

---

## 8. UART Transmitter (`u_uart_tx`)

Serializes bytes from the TX FIFO into UART frames and drives `tx_o`. Clocked by `tx_clk`.

### 8.1 Port Connections

| Port            | Connected To                         |
|-----------------|--------------------------------------|
| `clk_i`         | `tx_clk`                             |
| `arst_ni`       | `arst_ni & ~uart_ctrl.tx_fifo_flush` |
| `data_i`        | `tx_fifo_rd_data`                    |
| `data_valid_i`  | `tx_fifo_rd_valid & uart_ctrl.tx_en` |
| `data_bits_i`   | `uart_cfg.db`                        |
| `parity_en_i`   | `uart_cfg.pen`                       |
| `parity_type_i` | `uart_cfg.ptp`                       |
| `extra_stop_i`  | `uart_cfg.sb`                        |
| `tx_o`          | `tx_o` (top-level output)            |
| `data_ready_o`  | `tx_data_ready_from_uart`            |

---

## 9. UART Receiver (`u_uart_rx`)

Samples `rx_i`, reconstructs frames, optionally checks parity, and outputs a valid byte with a data-valid pulse. Clocked by `rx_clk`.

### 9.1 Responsibilities

- Detect start bit
- Sample and reconstruct 5/6/7/8-bit data frames
- Optionally check parity
- Verify stop bit(s)
- Generate received byte output and `data_valid_o` pulse

### 9.2 Port Connections

| Port             | Connected To                            |
|------------------|-----------------------------------------|
| `clk_i`          | `rx_clk`                                |
| `arst_ni`        | `arst_ni & ~uart_ctrl.rx_fifo_flush`    |
| `rx_i`           | `rx_i \| ~uart_ctrl.rx_en`              |
| `data_bits_i`    | `uart_cfg.db`                           |
| `parity_en_i`    | `uart_cfg.pen`                          |
| `parity_type_i`  | `uart_cfg.ptp`                          |
| `data_o`         | `rx_data_from_uart`                     |
| `data_valid_o`   | `rx_data_valid_from_uart`               |
| `parity_error_o` | `rx_parity_error`                       |

> When `rx_en` is deasserted, `rx_i` is forced high (idle line), disabling the receiver without requiring a reset.

---

## 10. RX CDC FIFO (`u_rx_cdc_fifo`)

Transfers received bytes from `rx_clk` into `clk_i`. Uses the same dual-clock CDC architecture as the TX FIFO.

### 10.1 Configuration

| Parameter    | Value                                |
|--------------|--------------------------------------|
| `DATA_WIDTH` | 8                                    |
| `FIFO_DEPTH` | `FIFO_DEPTH`                         |
| Write clock  | `rx_clk`                             |
| Read clock   | `clk_i`                              |
| Reset        | `arst_ni & ~uart_ctrl.rx_fifo_flush` |

### 10.2 Signal Connections

| FIFO Port    | Connected To                    | Direction |
|--------------|---------------------------------|-----------|
| `wr_clk_i`   | `rx_clk`                        | →         |
| `wr_data_i`  | `rx_data_from_uart`             | →         |
| `wr_valid_i` | `rx_data_valid_from_uart`       | →         |
| `wr_ready_o` | *(unconnected)*                 | —         |
| `wr_count_o` | `rx_fifo_wr_count`              | ←         |
| `rd_clk_i`   | `clk_i`                         | →         |
| `rd_ready_i` | `rx_fifo_rd_ready`              | →         |
| `rd_valid_o` | `rx_fifo_rd_valid`              | ←         |
| `rd_data_o`  | `rx_fifo_rd_data`               | ←         |
| `rd_count_o` | `rx_fifo_rd_count`              | ←         |

```
rx_fifo_rd_ready = rx_data_ready_from_regif
```

---

## 11. Interrupt Logic

Four interrupt sources are ORed to form `int_en_o`. Each source is individually maskable via `UART_INT`.

| Signal         | Condition                          | Enable Bit    |
|----------------|------------------------------------|---------------|
| `tx_empty_irq` | `tx_fifo_wr_count == 0`           | `tx_empty_en` |
| `tx_full_irq`  | `tx_fifo_wr_count == FIFO_DEPTH`  | `tx_full_en`  |
| `rx_empty_irq` | `rx_fifo_rd_count == 0`           | `rx_empty_en` |
| `rx_full_irq`  | `rx_fifo_wr_count == FIFO_DEPTH`  | `rx_full_en`  |

```
int_en_o = tx_empty_irq | tx_full_irq | rx_empty_irq | rx_full_irq
```

> TX fill level uses the write-side count (`tx_fifo_wr_count`). RX empty uses the read-side count (`rx_fifo_rd_count`); RX full uses the write-side count (`rx_fifo_wr_count`).

---

## 12. Control Behavior

| Control Bit  | Effect                                                              |
|--------------|---------------------------------------------------------------------|
| `tx_en`      | Gates TX FIFO read-ready and `data_valid_i` to the transmitter     |
| `rx_en`      | When deasserted, forces `rx_i` high (idle), disabling the receiver |
| `tx_fifo_flush`   | Asserts reset on TX CDC FIFO and `uart_tx` simultaneously          |
| `rx_fifo_flush`   | Asserts reset on RX CDC FIFO and `uart_rx` simultaneously          |

---

## 13. Block Diagram

![UART Subsystem Top View](./uart_subsystem_topview.svg)

---

## 14. Register Map Summary

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 15. Register Descriptions

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 16. Detailed Interconnection Summary

### 16.1 Register Interface → TX FIFO

| Source                     | Destination                |
|----------------------------|----------------------------|
| `tx_data_from_regif.data`  | `u_tx_cdc_fifo.wr_data_i`  |
| `tx_data_valid_from_regif` | `u_tx_cdc_fifo.wr_valid_i` |
| `u_tx_cdc_fifo.wr_ready_o` | `tx_data_ready_to_regif`   |
| `clk_i`                    | `u_tx_cdc_fifo.wr_clk_i`   |

### 16.2 TX FIFO → UART TX

| Source                          | Destination                                   |
|---------------------------------|-----------------------------------------------|
| `tx_fifo_rd_data`               | `u_uart_tx.data_i`                            |
| `tx_fifo_rd_valid & tx_en`      | `u_uart_tx.data_valid_i`                      |
| `u_uart_tx.data_ready_o & tx_en`| `tx_fifo_rd_ready`                            |
| `tx_clk`                        | `u_tx_cdc_fifo.rd_clk_i`, `u_uart_tx.clk_i`  |

### 16.3 Register Interface → Clock Dividers

| Source                   | Destination              |
|--------------------------|--------------------------|
| `uart_cfg.psclr`         | `u_prescaler_div.div_i`  |
| `uart_cfg.clk_div >> 3`  | `u_rx_clk_div.div_i`     |
| *(fixed `'d4`)*          | `u_tx_clk_div.div_i`     |

### 16.4 Register Interface → UART TX/RX Configuration

| Source        | TX Destination            | RX Destination            |
|---------------|---------------------------|---------------------------|
| `uart_cfg.db` | `u_uart_tx.data_bits_i`   | `u_uart_rx.data_bits_i`   |
| `uart_cfg.pen`| `u_uart_tx.parity_en_i`   | `u_uart_rx.parity_en_i`   |
| `uart_cfg.ptp`| `u_uart_tx.parity_type_i` | `u_uart_rx.parity_type_i` |
| `uart_cfg.sb` | `u_uart_tx.extra_stop_i`  | *(not connected)*         |

### 16.5 UART RX → RX FIFO

| Source                    | Destination                                  |
|---------------------------|----------------------------------------------|
| `rx_data_from_uart`       | `u_rx_cdc_fifo.wr_data_i`                    |
| `rx_data_valid_from_uart` | `u_rx_cdc_fifo.wr_valid_i`                   |
| `rx_clk`                  | `u_rx_cdc_fifo.wr_clk_i`, `u_uart_rx.clk_i` |

### 16.6 RX FIFO → Register Interface

| Source                     | Destination                   |
|----------------------------|-------------------------------|
| `rx_fifo_rd_data`          | `rx_data_to_regif.data`       |
| `rx_fifo_rd_valid`         | `rx_data_valid_to_regif`      |
| `rx_data_ready_from_regif` | `rx_fifo_rd_ready`            |
| `clk_i`                    | `u_rx_cdc_fifo.rd_clk_i`     |

---

## 17. AXI4-Lite Compliance Notes

- Write address and write data channels use separate independent handshakes
- Read address and read data channels use separate independent handshakes
- A transfer completes only when both `VALID` and `READY` are asserted
- Write response (`BRESP`) must be returned after accepting a write transaction
- Read response (`RRESP`) must be returned only after a valid read address handshake
- `WSTRB` controls which bytes of the 32-bit write data are active

---

## 18. Reset Behavior

On assertion of `arst_ni = 0`:

- UART control registers return to documented reset defaults
- TX and RX FIFOs are cleared
- UART TX goes idle (`tx_o` held high)
- UART RX state machine resets
- Interrupts are disabled
- AXI response-valid outputs are driven inactive

`tx_fifo_flush` and `rx_fifo_flush` bits can independently reset the TX and RX paths without a full system reset.

---

## 19. Dependencies
| Package / Module     | Description                                                    |
|----------------------|----------------------------------------------------------------|
| `uart_pkg`           | AXI-Lite bus struct types and UART data type definitions       |
| `uart_subsystem_pkg` | Subsystem-level parameters (e.g. `UART_FIFO_DEPTH`)           |
| `axi4l_uart_regif`   | AXI4-Lite register interface                                   |
| `clk_div`            | Parameterizable clock divider                                  |
| `cdc_fifo`           | Dual-clock CDC FIFO with Gray-code synchronization             |
| `uart_tx`            | UART transmitter                                               |
| `uart_rx`            | UART receiver                                                  |

---

## 20. Final Subsystem Summary

**This UART subsystem should be connected as follows**:

-The AXI4-Lite register interface is the only bus-facing slave
-The TX CDC FIFO bridges `clk_i` to `tx_clk`
-The RX CDC FIFO bridges `rx_clk` to `clk_i`
-The UART transmitter reads from TX CDC FIFO and drives `tx_o`
-The UART receiver samples `rx_i` and writes into RX CDC FIFO
-The prescaler divider creates a lower-rate timing base
-The TX divider generates the transmitter baud clock
-The RX divider generates the receiver timing clock
-UART configuration fields from `UART_CFG` drive both TX and RX formatting
-FIFO status feeds `UART_STAT`
- Interrupt enables from `UART_INT` combine with FIFO status to generate `int_en_o`

---