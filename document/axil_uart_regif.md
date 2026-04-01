# AXI‑Lite UART Register Interface Documentation

## Author
- Name: Sheikh Shuparna Haque
- Email: sheikhshuparna3108@gmail.com
- Name: Motasim Faiyaz
- Email: motasimfaiyaz@gmail.com
- Date: 2026-04-01
- Version: 1.0

## Overview
The AXI‑Lite UART register interface provides memory‑mapped control and status registers for the UART peripheral.  
Software uses these registers to configure baud rate and frame format, monitor FIFO status, enqueue transmit/receive requests, and manage interrupts.  
The interface is accessed via AXI‑Lite read and write transactions.

Registers are categorized as:
- **RW (Read/Write):** Software can read and update values.
- **RO (Read‑Only):** Updated only by hardware; software can read but not modify.
- **WO (Write‑Only):** Software writes values; reading is not meaningful.

---
![AXI4-Lite UART RTL Diagram](axi4l_uart_regif.svg)

## Register Interface Block Diagram

The block diagram above shows the AXI‑Lite register interface and the UART peripheral functional blocks it connects.

## I/O Ports

RTL module: `module axil_uart_regif #(
    parameter ADDR_WIDTH = 6,   // 64 bytes = 16 registers
    parameter DATA_WIDTH = 32
)


## Clock and Reset
| Signal Name | Direction     | Width  | Description          |
|-------------|---------------|--------|----------------------|
| `clk_i`       | `input`     | 1      | System clock         |
| `rst_ni`      | `input`     | 1      | Active-low reset     |

## AXI-Lite Slave Interface
| Signal Name | Direction | Width          | Description             |
|-------------|-----------|----------------|-------------------------|
| `awaddr_i`    | input     | `ADDR_WIDTH` | Write address           |
| `awvalid_i`   | input     | 1            | Write address valid     |
| `awready_o`   | output    | 1            | Write address ready     |
| `wdata_i`     | input     | `DATA_WIDTH` | Write data              |
| `wstrb_i`     | input     | 4            | Write strobe            |
| `wvalid_i`    | input     | 1            | Write data valid        |
| `wready_o`    | output    | 1            | Write data ready        |
| `bresp_o`     | output    | 2            | Write response          |
| `bvalid_o`    | output    | 1            | Write response valid    |
| `bready_i`    | input     | 1            | Write response ready    |
| `araddr_i`    | input     | `ADDR_WIDTH` | Read address            |
| `arvalid_i`   | input     | 1            | Read address valid      |
| `arready_o`   | output    | 1            | Read address ready      |
| `rdata_o`     | output    | `DATA_WIDTH` | Read data               |
| `rresp_o`     | output    | 2            | Read response           |
| `rvalid_o`    | output    | 1            | Read data valid         |
| `rready_i`    | input     | 1            | Read data ready         |

## UART Core Control Outputs
| Signal Name       | Direction | Width  | Description        |
|-------------------|-----------|--------|--------------------|
| `uart_tx_en_o`    | output    | 1      | UART TX enable     |
| `uart_rx_en_o`    | output    | 1      | UART RX enable     |
| `uart_clk_div_o`  | output    | 12     | UART clock divider |
| `uart_psclr_o`    | output    | 4      | Prescaler          |
| `uart_db_o`       | output    | 2      | Data bits          |
| `uart_pen_o`      | output    | 1      | Parity enable      |
| `uart_ptp_o`      | output    | 1      | Parity type        |
| `uart_sb_o`       | output    | 1      | Stop bit           |

## TX/RX Data Paths
| Signal Name          | Direction | Width  | Description                |
|----------------------|-----------|--------|----------------------------|
| `tx_data_o`          | output    | 8      | TX data                    |
| `tx_data_valid_o`    | output    | 1      | TX data valid              |
| `tx_fifo_full_i`     | input     | 1      | TX FIFO full               |
| `rx_data_i`          | input     | 8      | RX data                    |
| `rx_data_valid_i`    | input     | 1      | RX data valid              |
| `rx_fifo_empty_i`    | input     | 1      | RX FIFO empty              |
| `rx_pop_o`           | output    | 1      | Pop pulse to read UART_RXD |       

## Interrupts
| Signal Name     | Direction | Width  | Description              |
|-----------------|-----------|--------|--------------------------|
| `uart_int_en_o` | output    | 4      | UART interrupt enable    |


This I/O summary matches the RTL module ports and shows how the AXI-Lite register interface connects to UART control, data FIFOs, and IRQ signals.

### 1. AXI‑Lite interface device roles

- AXI‑Lite master: CPU or bus fabric initiates read/write register transactions.
- AXI‑Lite slave register interface: translates incoming AXI address/data/control into internal register loads and status reads.
- Address decoder: selects one of the `UART_*` registers based on the low address bits.
- Responders: `AWREADY`, `WREADY`, `BVALID`, `ARREADY`, `RVALID` signals manage handshake timing.

### 2. Register groups exposed to system software

- Control: `UART_CTRL`, `UART_CFG` for enabling TX/RX, setting parity, stop bits, and baudrate divisor.
- Data: `UART_TXD` for write-only transmit payload; `UART_RXD` for read-only receive payload.
- Status: `UART_STAT`, `UART_ISR` (or `UART_INT`) for FIFO levels and error flags.
- FIFO management: `UART_TXFL`, `UART_RXFL` for occupancy counts and watermark behavior.
- Interrupt mask/status: `UART_INT` enables and `UART_INT_STATUS` reports events.

### 3. UART data path and device blocks

- `baudrate_gen`: computes bit timing from clock source and `UART_CFG` divisor.
- `tx_fsm` / `rx_fsm`: state machines that shift data bytes in/out using line serial timing.
- `uart_tx_fifo` / `uart_rx_fifo`: elastic buffers decoupling host register access from physical send/receive rate.
- `parity/stop` unit: inserts/checks parity and stop bits from config.

### 4. Interrupt and error reporting

- Event sources: `tx_fifo_full`, `tx_fifo_empty`, `rx_fifo_full`, `rx_fifo_empty`, overrun, framing error, parity error.
- Interrupt aggregator: forms bitfield in `UART_INT_STATUS` and optionally an interrupt output pin to the top-level interrupt controller when `UART_INT` mask bits are set.
- Clear semantics: reading/writing status registers clears sticky flags as documented.

### 5. Signal/flow summary

- Software writes `UART_TXD` → `uart_tx_fifo` enqueue → `tx_fsm` shift out bytes via `txd` line.
- Incoming serial `rxd` → `rx_fsm` deserializes → `uart_rx_fifo` enqueue → software reads `UART_RXD`.
- `UART_STAT` reflects FIFO fullness and RX/TX holding conditions, and it is updated in hardware independent of AXI transactions.

The interface decouples software control from UART physical line timing, enabling microcontroller firmware to configure UART mode and service data through memory-mapped read/write commands while avoiding bit-level timing complexity.

- - -
## Register Map

For Full register Map See Document  [OPEN uart_reg.md](uart_reg.md)

---

## Register Details

For Full register Details See Document [OPEN uart_reg.md](uart_reg.md)

---

## Reset Behavior
- On reset, RW registers load their documented defaults.  
- FIFOs are cleared (`tx_empty = 1`, `rx_empty = 1`).  
- Interrupts are disabled (`UART_INT = 0x00000000`).  

---

## Arbitration Mechanism
- **TXR/RXR:** enqueue master IDs into request FIFOs.  
- **TXGP/RXGP:** non‑consuming peek at current grant.  
- **TXG/RXG:** consuming read that advances the grant FIFO.  
- Ensures fair multi‑master access to TX and RX paths.  

---

## Interrupt Setting
- Hardware events (FIFO empty/full, parity error) are ANDed with `UART_INT` bits.  
- If enabled, the UART raises an interrupt line.  
- Software ISR reads `UART_STAT` to identify the source and clears the condition by servicing FIFO or error.  

---

## Software Usage Example
1. Configure baud rate and frame format via `UART_CFG`.  
2. Enable TX/RX via `UART_CTRL`.  
3. Write data to `UART_TXD` to transmit.  
4. Read data from `UART_RXD` when available.  
5. Use `UART_STAT` to monitor FIFO state.  
6. Enable interrupts in `UART_INT` for event‑driven operation.  

---

## AXI‑Lite Interface Notes
- **Write transactions:** update RW and WO registers.  
- **Read transactions:** return RW and RO register values.  
- **Address decoding:** offsets are byte‑aligned (0x000, 0x004, etc.).  
- **Data width:** 32‑bit registers, with unused bits reserved.  

---

## Reserved Bits
- Must be written as `0`.  
- Should be ignored on read.  
- Reserved for future expansion.  

---



