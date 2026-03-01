# Dual-Edge Register

## Overview

The `dual_edge_reg` module is a parameterized **Double Data Rate (DDR) register** that captures and updates data on **both the rising and falling edges** of the clock. This effectively doubles the data throughput relative to the clock frequency compared to a conventional single-edge register.

Two internal flip-flops — one positive-edge triggered (`data_p`) and one negative-edge triggered (`data_n`) — operate in tandem. An output multiplexer selects between them based on the current clock phase, producing a single output bus that is valid on every half-cycle.

---

## Block Diagram

<img src="./dual_edge_reg.svg">

---

## Parameters

| Parameter | Type | Default | Description            |
| --------- | ---- | ------- | ---------------------- |
| `WIDTH`   | int  | 8       | Data bus width in bits |

---

## Ports

| Port     | Direction | Width     | Description                                    |
| -------- | --------- | --------- | ---------------------------------------------- |
| `arst_ni`| input     | 1         | Asynchronous active-low reset (0 = reset)      |
| `clk_i`  | input     | 1         | Clock input                                    |
| `en_i`   | input     | 1         | Data capture enable (active high)              |
| `data_i` | input     | `WIDTH`   | Data input                                     |
| `data_o` | output    | `WIDTH`   | Data output (updated on every clock half-cycle)|

---

## Internal Signals

| Signal   | Width   | Description                                    |
| -------- | ------- | ---------------------------------------------- |
| `data_p` | `WIDTH` | Posedge-triggered register (rising-edge stage) |
| `data_n` | `WIDTH` | Negedge-triggered register (falling-edge stage)|

---

## Functional Description

### Reset

When `arst_ni` is de-asserted (low), **both** internal registers are asynchronously cleared to zero, regardless of the clock state.

### Data Capture (`en_i = 1`)

- On the **rising edge** of `clk_i`: `data_p` captures `data_i`.
- On the **falling edge** of `clk_i`: `data_n` captures `data_i`.

Both registers therefore hold the same value (`data_i`) after one full clock cycle.

### Hold / Circulation (`en_i = 0`)

- On the **rising edge** of `clk_i`: `data_p` captures the current value of `data_n`.
- On the **falling edge** of `clk_i`: `data_n` captures the current value of `data_p`.

The two registers exchange values each half-cycle. Because each always reads what the other stored in the previous half-cycle, the net result is that both registers **retain their last captured value**.

### Output Selection

```sv
assign data_o = clk_i ? data_p : data_n;
```

`data_o` is driven by `data_p` while the clock is high and by `data_n` while the clock is low. This creates a continuous, glitch-free output that is valid throughout the entire clock cycle.

> **Note:** The output assignment is currently a combinational `assign`. A future improvement (marked `// TODO ALWAYS_COMB`) is to replace this with an `always_comb` block to make the synthesizer's intent explicit and avoid any implicit latch inference warnings.

---

## Truth Table

| `arst_ni` | `en_i` | Clock Edge | `data_p` next | `data_n` next | `data_o`            |
| --------- | ------ | ---------- | ------------- | ------------- | ------------------- |
| 0         | X      | Any        | 0             | 0             | 0                   |
| 1         | 1      | Rising     | `data_i`      | —             | `data_p` (clk high) |
| 1         | 1      | Falling    | —             | `data_i`      | `data_n` (clk low)  |
| 1         | 0      | Rising     | `data_n`      | —             | `data_p` (clk high) |
| 1         | 0      | Falling    | —             | `data_p`      | `data_n` (clk low)  |

---

## Timing Diagram

```
clk_i   ___/‾‾‾\___/‾‾‾\___/‾‾‾\___
en_i    ___/‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
data_i       A   A   B   B
             |   |   |   |
data_p       A       B             (updated on rising edge)
data_n           A       B         (updated on falling edge)
data_o       A   A   B   B         (mux selects p/n by clk phase)
```

- During the high phase of `clk_i`, `data_o` reflects `data_p`.
- During the low phase of `clk_i`, `data_o` reflects `data_n`.
- Both registers are refreshed once per clock cycle, so `data_o` updates **twice per cycle**.

---

## RTL Interface

```sv
module dual_edge_reg #(
    parameter WIDTH = 8
) (
    input  logic             arst_ni,
    input  logic             clk_i,
    input  logic             en_i,
    input  logic [WIDTH-1:0] data_i,
    output logic [WIDTH-1:0] data_o
);
```

---

## Typical Applications

- **DDR I/O interfaces** — capturing or driving data on both clock edges to double throughput without increasing the clock frequency.
- **Clock-domain crossing assist** — sampling a signal's state at both phases for improved metastability margin.
- **DDR memory controllers** — registering address/data lines that must be presented on both clock edges.
- **High-speed serial links** — serializing data at 2× the clock rate.
