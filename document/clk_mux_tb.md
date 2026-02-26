# Clock Multiplexer Test Plan

## Clock Multiplexer
 
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

### Ports:

|Name|Direction|Type|Dimension|Description|
|-|-|-|-|-|
|arst_ni|input|logic|| Asynchronous active low reset|
|sel_i|input|logic|| Clock select signal (`0` → `clk0_i`, `1` → `clk1_i`)|
|clk0_i|input|logic|| First clock input|
|clk1_i|input|logic|| Second clock input|
|clk_o|output|logic|| Selected output clock|

## Functional Overview

- When `sel_i = 0` → `clk0_i` is selected  
- When `sel_i = 1` → `clk1_i` is selected  

The output clock (`clk_o`) follows only one clock source at a time.

Clock switching is performed in a controlled manner to prevent:
- Clock glitches
- Short pulses
- Metastability propagation

---

## Parameters

This module does not use configurable parameters.

# Reset Behavior

- When `arst_ni = 0`, the internal selection logic is reset.
- The output clock is forced into a safe deterministic state.
- After reset release, clock selection follows `sel_i`.

---

## Design Considerations

- The select signal (`sel_i`) must be stable during clock switching.
- If `sel_i` changes asynchronously relative to both clocks, proper synchronization
  is recommended before feeding it to this module.
- For high-frequency designs, ensure timing constraints are properly defined in STA.

## Challenges and Risks

| **Challenge / Risk**                    | **Description**                                                                           | **Mitigation / Notes**                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Clock Domain Crossing (CDC)             | Two asynchronous clocks (`clk0_i` and `clk1_i`) may cause metastability or glitches.      | Use 2-stage DFF synchronizers; test multiple clock combinations.                 |
| Glitch Prevention                       | Switching between clocks can create momentary glitches on `clk_o`.                        | Cross-coupled handshake logic; task-based test cases to check switching.         |
| Reset Timing                            | Asynchronous reset (`arst_ni`) can occur during active clock or clock switch.             | Test reset during operation and edge cases; monitor `clk_o` and enables.         |
| Switching Between Clocks                | Enabling new clock before disabling old clock may overlap signals.                        | Verify switching 0→1, 1→0, rapid toggle; use assertions.                         |
| Different Clock Frequencies             | The clk_mux module must handle clocks of different frequencies (non-harmonic, fast/slow). | Run test cases with various frequency ratios; check for glitches.                |
| Observability & Debugging               | Output `clk_o` is a single line; internal enables may hide issues.                        | Monitor `en0`, `en1`, `clk_o`; use `$monitor` and waveform viewers.              |
| Task-Based Sequential Testing           | Each test case runs sequentially; missing delays may mask failures.                       | Use `$stop` after each task; ensure proper delay between scenarios.              |
| Self-Checking Verification (Assertions) | Assertions may not cover all critical scenarios.                                          | Use `always_comb` assertions for enables, output, reset behavior; check all TCs. |



## Test Environment

The verification environment will include:

* Clock Generators (clk0_i & clk1_i): Provide the input clocks for the clock multiplexer.
* Reset Generator: Initializes the clock multiplexer to a known state at the start of     simulation.
* Stimulus Driver (for sel_i): Sends selection signals to test different clock paths.
* Monitor: Observes the output of the clock multiplexer and records events.
* Scoreboard: Compares the multiplexer output with expected results and reports mismatches.

### Testbench Architecture

<img src="./clk_mux_tba.svg">


# Verification Methodology

Hybrid approach:

* Directed testing
* Randomized select switching
* Assertion-based verification

---

### Stimulus Generation

* Deterministic clock generation
* Controlled sel transitions
* Random toggle mode
* Reset injection at different times

Example configurations:

| Mode      | clk0 | clk1 |
| --------- | ---- | ---- |
| Equal     | 10ns | 10ns |
| Different | 10ns | 17ns |
| Stress    | 7ns  | 23ns |

---

### Scoreboarding

Scoreboard responsibilities:

1. Checking clk_o matches selected clock
2. Detecting unexpected or incorrect pulses
3. Verifying safe switching sequence

---

# Test Cases

## TC1 – Reset Verification

### Test Case Name
Reset Behavior

### Description
Verify safe state during reset.

### Test Steps
1. Apply arst_ni = 0
2. Observe clk_o
3. Release reset

### Expected Results
* clk_o = 0
* Normal operation resumes after reset

---

## TC2 – Select clk0

### Test Case Name
Static Select clk0

### Description
Verify clk0 propagates when sel=0.

### Test Steps
1. Release reset
2. Set sel_i = 0
3. Observe clk_o

### Expected Results
* clk_o follows clk0_i

---

## TC3 – Select clk1

### Test Case Name
Static Select clk1

### Description
Verify clk1 propagates when sel=1.

### Test Steps
1. Release reset
2. Set sel_i = 1
3. Observe clk_o

### Expected Results
* clk_o follows clk1_i

---

## TC4 – Switch 0 → 1

### Test Case Name
Clock Switch 0 to 1

### Description
Verify correct switching from clk0 to clk1.

### Test Steps
1. Start with sel=0
2. After a few cycles, change sel to 1

### Expected Results
1. clk_o follows clk0 initially
2. clk_o transitions to follow clk1 after switch
3. No incorrect or spurious pulses
4. Clean transition on clk_o

---

## TC5 – clk_o Behavior Verification

### Test Case Name
Check clk_o if `assign` was used

### Description
This test demonstrates the unsafe behavior of clk_o if a plain `assign` statement is used in clk_mux.  
Since clk_o depends on FF outputs from two different clock domains, using `assign` may produce unexpected or incorrect values in simulation.

### Test Steps
1. Set sel_i = 0 and arst_ni = 1  
2. Rapidly toggle clk0_i and clk1_i to simulate clock changes  
3. Monitor clk_o after each toggle  
4. Observe for unexpected values that would occur if `assign` were used

### Expected Results
* If clk_o uses proper gated logic (always_comb or FF-based), output is correct  
* If assign was used, clk_o may show:  
  - X (unknown) values in the waveform  
  - Incorrect output relative to clk0_i/clk1_i

---

# Test Case Summary Table

| TC ID | Test Name                  | Type     | Priority |
| ----- | -------------------------- | -------- | -------- |
| TC1   | Reset Verification         | Directed | High     |
| TC2   | Static Select clk0         | Directed | High     |
| TC3   | Static Select clk1         | Directed | High     |
| TC4   | Clock Switch 0 → 1         | Directed | High     |
| TC5   | clk_o Behavior Verification| Directed | Medium   |

---

# Functional Coverage 

Coverage goals:

### Coverpoints
* sel = 0
* sel = 1
* 0→1 transition
* 1→0 transition
* reset assertion
* reset during active clock
* different frequency configurations

### Cross Coverage
* sel transition × clock frequency mode
* reset × active clock
