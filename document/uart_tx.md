# UART Transmitter

## Overview

The `uart_tx` module handles the transmission of data over the UART interface. It manages the serialization of data bytes, adds start, stop, and parity bits as configured, and controls the timing of data output on the `tx_o` line. It accepts data via a valid/ready handshake interface, serializes it LSB-first, and drives the serial line according to the frame format programmed in `uart_reg`. The baud rate clock is supplied directly as `clk_i` from the `clk_div` module — the FSM advances one bit per clock edge.

---

## Functional Description

The transmitter operates as a finite state machine (FSM) that sequences through the UART frame states: idle, start bit, data bits, optional parity bit, and stop bit(s). On each rising edge of `clk_i` (baud clock), the FSM advances to the next bit position. A new frame begins when `data_valid_i` is asserted and the transmitter is idle (`data_ready_o = 1`). The data byte is loaded at frame start and shifted out LSB-first on each subsequent clock edge.

Key behaviours:

- Line idles HIGH (`tx_o = 1`) when no frame is in progress
- Start bit drives `tx_o = 0` for one baud period
- Data bits are transmitted LSB-first; bit count is controlled by `data_bits_i`
- Parity bit is inserted after data bits when `parity_en_i = 1`; type controlled by `parity_type_i`
- One or two stop bits drive `tx_o = 1` based on `extra_stop_i`
- `data_ready_o` is deasserted during frame transmission and reasserted on return to IDLE

---

## Parameters

None. The transmitter is fully controlled through input ports.

---

## Architecture

The `uart_tx` module consists of two main components:

1. **Shift register** — holds the current data byte and shifts it out LSB-first on each `clk_i` edge
2. **Frame FSM** — sequences through UART frame states, controls `tx_o`, manages the valid/ready handshake, and computes parity

The baud clock `clk_i` is the output of the shared `clk_div` module. One clock cycle = one baud period.

---

## Top I\O

<img src="./uart_tx_top.drawio.svg">

---

## Ports

| Port Name       | Direction | Width | Description                                                           |
| --------------- | --------- | ----- | ----------------------------------------------------------------------|
| `arst_ni`       | Input     | 1     | Asynchronous reset, active low                                        |
| `clk_i`         | Input     | 1     | Baud clock input — fed directly from `clk_div` output                 |
| `data_i`        | Input     | 8     | Data byte to be transmitted                                           |
| `data_valid_i`  | Input     | 1     | Asserted by upstream when `data_i` is valid and ready to send         |
| `data_ready_o`  | Output    | 1     | Asserted when transmitter is idle and can accept a new data byte      |
| `data_bits_i`   | Input     | 2     | Number of data bits per frame: 0=5 bits, 1=6 bits, 2=7 bits, 3=8 bits |
| `parity_en_i`   | Input     | 1     | Parity enable: 1 = insert parity bit, 0 = no parity                   |
| `parity_type_i` | Input     | 1     | Parity type: 0 = even, 1 = odd (valid only when parity_en_i=1)        |
| `extra_stop_i`  | Input     | 1     | Stop bits: 0 = one stop bit, 1 = two stop bits                        |
| `tx_o`          | Output    | 1     | UART serial transmit output (idle = HIGH)                             |

---

## Frame FSM

<img src="./uart_tx_fsm.drawio.svg">

---

| State    | `tx_o` | Description                                                         |
| -------- | ------ | ------------------------------------------------------------------- |
| `IDLE`   | 1      | Waiting for `data_valid_i`. `data_ready_o = 1`                      |
| `START`  | 0      | Start bit for one baud period. Loads byte into shift register       |
| `DATA`   | bit n  | Shifts out bits LSB-first. `bit_cnt` runs 0 → `(data_bits_i + 4)`   |
| `PARITY` | parity | Parity bit. Entered only when `parity_en_i = 1`                     |
| `STOP`   | 1      | First stop bit                                                      |
| `STOP2`  | 1      | Second stop bit. Entered only when `extra_stop_i = 1`               |

---

## Valid/Ready Handshake

`uart_tx` uses a standard valid/ready handshake for data input:

```
Upstream asserts data_valid_i = 1 with data_i stable
uart_tx  asserts data_ready_o = 1 when idle
Handshake completes when both are high on the same clk_i edge
uart_tx  deasserts data_ready_o for the duration of the frame
uart_tx  reasserts data_ready_o when it returns to IDLE
```

---

## Design Decisions
 
**Why is `clk_i` the baud clock?**
The `clk_div` output feeds directly as `clk_i`. One cycle = one baud period. No internal tick counter needed inside `uart_tx`.
 
**Why valid/ready handshake?**
Decouples `uart_tx` from the FIFO implementation. Any data source — CDC FIFO, sync FIFO — connects without changing the transmitter.
 
**Why add `data_bits_i` and `parity_type_i`?**
The SC-SoC `uart_reg` exposes configurable data bits (5–8) and parity type from `UART_CFG`. These ports allow `uart_tx` to be fully driven by `uart_reg` outputs without any hardcoded frame format.