# clk_mux

### Author : Adnan Sami Anirban (adnananirban259@gmail.com)

## Description

The `clk_mux` module is a glitch-free clock multiplexer that selects one of two input clocks
(`clk0_i` or `clk1_i`) based on the select signal (`sel_i`) and forwards the selected clock to
the output (`clk_o`).

This module is designed to safely switch between two clock domains without generating spurious
glitches on the output clock. The selection logic ensures that clock transitions occur in a
controlled manner.

The module uses an asynchronous active-low reset (`arst_ni`) to initialize internal control
signals into a known safe state.

This type of clock multiplexer is commonly used in:

- Dynamic frequency scaling systems
- Power management architectures
- Multi-clock SoC subsystems
- Clock source selection logic

## Parameters

This module does not use configurable parameters.

## Ports

| Name    | Direction | Type  | Dimension | Description                                          |
| ------- | --------- | ----- | --------- | ---------------------------------------------------- |
| arst_ni | input     | logic |           | Asynchronous active low reset                        |
| sel_i   | input     | logic |           | Clock select signal (`0` → `clk0_i`, `1` → `clk1_i`) |
| clk0_i  | input     | logic |           | First clock input                                    |
| clk1_i  | input     | logic |           | Second clock input                                   |
| clk_o   | output    | logic |           | Selected output clock                                |

## Block Diagram

<img src="./clk_mux.svg">

## Functional Overview

- When `sel_i = 0` → `clk0_i` is selected
- When `sel_i = 1` → `clk1_i` is selected

The output clock (`clk_o`) follows only one clock source at a time.

Clock switching is performed in a controlled manner to prevent:

- Clock glitches
- Short pulses
- Metastability propagation

## Reset Behavior

- When `arst_ni = 0`, the internal selection logic is reset.
- The output clock is forced into a safe deterministic state.
- After reset release, clock selection follows `sel_i`.

## Design Considerations

- The select signal (`sel_i`) must be stable during clock switching.
- If `sel_i` changes asynchronously relative to both clocks, proper synchronization
  is recommended before feeding it to this module.
- For high-frequency designs, ensure timing constraints are properly defined in STA.
