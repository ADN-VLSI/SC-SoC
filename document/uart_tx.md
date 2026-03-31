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

## Top I\O

<img src="./uart_tx_top.drawio.svg">

## Ports

| Port Name       | Direction | Width | Description                                                      |
| --------------- | --------- | ----- | ---------------------------------------------------------------- |
| `arst_ni`       | Input     | 1     | Asynchronous reset, active low                                   |
| `clk_i`         | Input     | 1     | Baud clock input — fed directly from `clk_div` output            |
| `data_i`        | Input     | 8     | Data byte to be transmitted                                      |
| `data_valid_i`  | Input     | 1     | Asserted by upstream when `data_i` is valid and ready to send    |
| `data_ready_o`  | Output    | 1     | Asserted when transmitter is idle and can accept a new data byte |
| `data_bits_i`   | Input     | 2     | Number of data bits per frame: 0=5, 1=6, 2=7, 3=8               |
| `parity_en_i`   | Input     | 1     | Parity enable: 1 = insert parity bit, 0 = no parity             |
| `parity_type_i` | Input     | 1     | Parity type: 0 = even, 1 = odd (valid only when parity_en_i=1)  |
| `extra_stop_i`  | Input     | 1     | Stop bits: 0 = one stop bit, 1 = two stop bits                   |
| `tx_o`          | Output    | 1     | UART serial transmit output (idle = HIGH)                        |

---

## Architecture

The `uart_tx` module consists of two main components:

1. **Shift register** — holds the current data byte and shifts it out LSB-first on each `clk_i` edge
2. **Frame FSM** — sequences through UART frame states, controls `tx_o`, manages the valid/ready handshake, and computes parity

The baud clock `clk_i` is the output of the shared `clk_div` module. One clock cycle = one baud period. The system clock is not directly visible inside `uart_tx`.

![uart_tx](svg/uart_tx.svg)

---

## Frame FSM

The FSM for this module is as follows:

![uart_tx_fsm](svg/uart_tx_fsm.svg)

### States

| State    | `tx_o`  | Description                                                                       |
| -------- | ------- | --------------------------------------------------------------------------------- |
| `IDLE`   | 1       | Waiting for `data_valid_i`. `data_ready_o = 1`. Loads byte on handshake          |
| `START`  | 0       | Drives start bit for one baud period                                              |
| `DATA`   | bit n   | Shifts out data bits LSB-first. Counts down from `data_bits_i` value             |
| `PARITY` | parity  | Drives computed parity bit. Entered only when `parity_en_i = 1`                  |
| `STOP`   | 1       | Drives first stop bit for one baud period                                         |
| `STOP2`  | 1       | Drives second stop bit. Entered only when `extra_stop_i = 1`                     |

### State Transitions

```
IDLE   ──(data_valid_i)──────────────────► START
START  ──(next clk_i)────────────────────► DATA
DATA   ──(last_bit & parity_en_i)────────► PARITY
DATA   ──(last_bit & !parity_en_i)───────► STOP
PARITY ──(next clk_i)────────────────────► STOP
STOP   ──(extra_stop_i)──────────────────► STOP2
STOP   ──(!extra_stop_i)─────────────────► IDLE
STOP2  ──(next clk_i)────────────────────► IDLE
```

---

## Frame Format

```
Idle:   tx_o = 1 continuously

Frame:  [START=0] [D0] [D1] ... [Dn] ([PARITY]) [STOP=1] ([STOP2=1])

START   : tx_o = 0, one baud period
D0..Dn  : data bits LSB first, count = 5/6/7/8 per data_bits_i
PARITY  : computed parity bit, only when parity_en_i = 1
STOP    : tx_o = 1, one baud period
STOP2   : tx_o = 1, one extra baud period, only when extra_stop_i = 1
```

**Parity computation:**

```
even parity : parity_bit = XOR  of all transmitted data bits
odd  parity : parity_bit = XNOR of all transmitted data bits
```

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

**Why is `clk_i` the baud clock and not the system clock?**
The `clk_div` module divides the system clock down to the baud rate and feeds its output directly as `clk_i` to `uart_tx`. This keeps the FSM simple — one clock cycle equals one baud period. No tick counter is needed inside `uart_tx`. The same pattern is used in the APB-UART reference design.

**Why valid/ready handshake instead of direct FIFO interface?**
The valid/ready interface decouples `uart_tx` from the FIFO implementation. A CDC FIFO, synchronous FIFO, or any other data source can connect without changing the transmitter.

**Why LSB first?**
Standard UART protocol transmits the least significant bit first. This matches all standard UART receivers.

**Why deassert `data_ready_o` during transmission?**
A new byte must not be loaded mid-frame. Deasserting `data_ready_o` prevents the upstream from presenting new data until the current frame is fully transmitted.

**Why add `data_bits_i` and `parity_type_i` beyond the APB version?**
The AXI4-Lite UART register map (`uart_reg`) exposes configurable data bits (5–8) and parity type from `UART_CFG`. The APB version used fixed 8-bit data. These two ports allow `uart_tx` to be fully driven by `uart_reg` outputs without any hardcoded frame format.