# AXI4-Lite UART Subsystem Documentation

========================================
## Author: Dhruba Jyoti Barua
========================================


## 1. Overview

This document describes an **AXI4-Lite UART peripheral subsystem** built without any internal memory block. The subsystem is implemented as a **register-mapped peripheral slave**. Software accesses control, status, transmit, receive, arbitration, and interrupt registers through the AXI4-Lite interface, while UART data moves through dedicated streaming datapaths and CDC FIFOs.

The subsystem contains the following blocks:

1. AXI4-Lite Interface
2. UART Register Interface
3. CDC FIFO for Transmitter
4. CDC FIFO for Receiver
5. Clock Divider
6. UART Transmitter
7. UART Receiver

---

## 2. Scope and Design Intent

The design is intended to connect a processor or bus master on an **AXI4-Lite bus** to a UART serial interface.

The subsystem does **not** use a memory slave or RAM for data storage. Instead:

- configuration and control are handled through registers
- transmit data is written into a TX path
- received data is read back from an RX path
- transmitter and receiver are decoupled from the AXI clock domain using separate CDC FIFOs

This matches the AXI4-Lite use case of a **simple control register-style peripheral**. AXI4-Lite supports only single-beat transactions, uses full-width bus accesses, and does not support exclusive accesses. 

---

## 3. AXI4-Lite Interface

## 3.1 Purpose

The AXI4-Lite interface provides the processor-visible register access path into the UART subsystem.

## 3.2 AXI4-Lite Behavior

For this subsystem, AXI4-Lite is used as a lightweight control interface with the following properties:

- single transfer per read or write transaction
- no bursts
- full-width register access model
- non-modifiable, non-bufferable transaction semantics
- no exclusive access support :contentReference[oaicite:3]{index=3}

## 3.3 AXI Signals Used

The provided register interface already contains the required AXI4-Lite channels:

### Write address channel
- `awaddr_i`
- `awvalid_i`
- `awready_o`

### Write data channel
- `wdata_i`
- `wstrb_i`
- `wvalid_i`
- `wready_o`

### Write response channel
- `bresp_o`
- `bvalid_o`
- `bready_i`

### Read address channel
- `araddr_i`
- `arvalid_i`
- `arready_o`

### Read data channel
- `rdata_o`
- `rresp_o`
- `rvalid_o`
- `rready_i`

## 3.4 Functional Role

The AXI4-Lite interface itself does not implement UART serialization or buffering. Its job is to transport software read/write accesses into the **UART register interface**, which then controls the rest of the subsystem.

---

## 4. UART Register Interface

## 4.1 Purpose

The UART register interface is the central control and status block of the subsystem. It maps AXI4-Lite accesses to UART control, configuration, transmit, receive, arbitration, and interrupt behavior.

## 4.2 Register-Controlled Outputs

The provided register interface drives the following outputs:

- `uart_tx_en_o`
- `uart_rx_en_o`
- `uart_clk_div_o`
- `uart_psclr_o`
- `uart_db_o`
- `uart_pen_o`
- `uart_ptp_o`
- `uart_sb_o`
- `uart_int_en_o` 

These outputs configure the downstream UART logic.

## 4.3 TX and RX Data Handshake Signals

The register interface also exposes datapath-related signals:

### TX side
- `tx_data_o`
- `tx_data_valid_o`

### RX side
- `rx_data_i`
- `rx_data_valid_i`
- `rx_pop_o` 

This allows the register block to serve as the software-facing endpoint of both the transmit and receive paths.

---

## 5. Register Map Summary

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 6. Register Descriptions

See [UART Register Map and Bit Fields](./uart_reg.md).

---

## 7. CDC FIFO for Transmitter

## 7.1 Purpose

The TX CDC FIFO safely transfers transmit bytes from the AXI/register clock domain into the UART transmit domain.

## 7.2 Why It Is Needed

The software-facing AXI side and the UART serial engine may operate at different rates or even different clock domains. A CDC FIFO is used to:

- safely cross clock domains
- absorb software-side burstiness
- decouple bus timing from serial transmission timing

## 7.3 TX Data Path Operation

The intended flow is:

1. software writes a byte to `UART_TXD`
2. the register interface drives `tx_data_o[7:0]`
3. the register interface asserts `tx_data_valid_o`
4. the TX CDC FIFO captures the byte
5. the UART transmitter reads bytes from the FIFO when ready

## 7.4 TX Status Contribution

The TX CDC FIFO should provide the live values used by `UART_STAT`:

- TX data count
- TX FIFO empty
- TX FIFO full 

---

## 8. CDC FIFO for Receiver

## 8.1 Purpose

The RX CDC FIFO safely transfers received bytes from the UART receive domain into the AXI/register domain.

## 8.2 Why It Is Needed

The UART receiver operates according to serial timing, while software reads data according to bus timing. The RX CDC FIFO:

- safely crosses domains
- prevents loss of incoming bytes
- buffers back-to-back received frames

## 8.3 RX Data Path Operation

The intended flow is:

1. the UART receiver reconstructs a valid byte
2. the byte is pushed into the RX CDC FIFO
3. the register interface sees RX data through `rx_data_i`
4. software reads `UART_RXD`
5. the register interface asserts

## 8.4 RX Status Contribution

The RX CDC FIFO should provide the live values used by `UART_STAT`:

- RX data count
- RX FIFO empty
- RX FIFO full 

---

## 9. Clock Divider

## 9.1 Purpose

The clock divider generates the baud timing basis used by the UART transmitter and UART receiver.

## 9.2 Configuration Inputs

Clocking configuration comes from `UART_CFG`:

- `Clock Divider` in bits `[11:0]`
- `Prescaler` in bits `[15:12]` :contentReference[oaicite:21]{index=21}

These are already exported by the register interface as:

- `uart_clk_div_o`
- `uart_psclr_o` :contentReference[oaicite:22]{index=22}

## 9.3 Functional Role

The divider should generate a baud tick or sampling enable used by:

- the UART transmitter to step through frame bits
- the UART receiver to sample the incoming serial line

The exact divider formula depends on the RTL implementation, but logically it is derived from the system clock, divider field, and prescaler field.

---

## 10. UART Transmitter

## 10.1 Purpose

The UART transmitter converts parallel bytes into serial UART frames.

## 10.2 Inputs

The transmitter uses:

- transmit enable
- baud timing tick from the clock divider
- TX data from the TX CDC FIFO
- frame format controls from `UART_CFG`

These include:

- data bits
- parity enable
- parity type
- stop bits 

## 10.3 Operation

For each byte, the transmitter generally emits:

1. one start bit
2. configured number of data bits
3. optional parity bit
4. one or two stop bits

## 10.4 Relationship to TX FIFO

The transmitter should consume a byte only when:

- TX is enabled
- the transmitter is idle or ready
- the TX FIFO is not empty

This allows the FIFO to absorb software timing differences while the transmitter drains bytes at the configured baud rate.

---

## 11. UART Receiver

## 11.1 Purpose

The UART receiver samples the serial RX line and reconstructs UART frames into bytes.

## 11.2 Inputs

The receiver uses:

- receive enable
- baud or oversampling timing from the clock divider
- frame format settings from `UART_CFG`
- serial RX input

## 11.3 Operation

The receiver typically performs:

- start-bit detection
- mid-bit or oversampled data sampling
- serial-to-parallel conversion
- optional parity checking
- stop-bit validation

When a valid frame is received, the byte is pushed into the RX CDC FIFO.

## 11.4 Relationship to RX FIFO

The RX FIFO buffers valid received bytes until software reads them through `UART_RXD`. This prevents immediate software servicing from being required on every received byte.

---

## 12. Top-Level Functional Connectivity

The functional interaction between blocks is as follows:

- the **AXI4-Lite interface** accepts bus read/write transactions
- the **UART register interface** decodes those accesses into register operations
- writes to transmit registers generate TX-side data valid events
- reads from receive registers consume RX-side buffered bytes
- the **TX CDC FIFO** buffers outgoing bytes before serialization
- the **RX CDC FIFO** buffers incoming bytes after deserialization
- the **clock divider** provides baud timing for both TX and RX engines
- the **UART transmitter** drives the serial output
- the **UART receiver** samples the serial input

---

## 13. Register-to-Block Mapping

## 13.1 Control Mapping

- `UART_CTRL[3]` maps to `uart_tx_en_o`
- `UART_CTRL[4]` maps to `uart_rx_en_o` 

## 13.2 Clock and Frame Configuration Mapping

- `UART_CFG[11:0]` maps to `uart_clk_div_o`
- `UART_CFG[15:12]` maps to `uart_psclr_o`
- `UART_CFG[17:16]` maps to `uart_db_o`
- `UART_CFG[18]` maps to `uart_pen_o`
- `UART_CFG[19]` maps to `uart_ptp_o`
- `UART_CFG[20]` maps to `uart_sb_o` 

## 13.3 TX Path Mapping

- software writes `UART_TXD`
- register interface outputs `tx_data_o`
- register interface asserts `tx_data_valid_o`
- TX FIFO captures the byte
- transmitter consumes the byte when ready

## 13.4 RX Path Mapping

- receiver produces received bytes
- RX FIFO buffers them
- register interface reads them through `rx_data_i`
- `rx_pop_o` removes one entry when `UART_RXD` is read 

## 13.5 Interrupt Mapping

`UART_INT[3:0]` enables interrupts for:

- TX FIFO empty
- TX FIFO full
- RX FIFO empty
- RX FIFO full :contentReference

---

## 14. Conclusion

This subsystem is a **register-based AXI4-Lite UART peripheral** with no internal memory block.

Its architecture separates:

- **control plane**: AXI4-Lite interface + UART register interface
- **data plane**: TX path and RX path through separate CDC FIFOs
- **timing plane**: clock divider feeding UART TX and UART RX

