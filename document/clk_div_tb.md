# Clock Divider Verification Plan

## Target DUT

The `clk_div` module is a parameterized clock divider that generates a lower-frequency output clock from a higher-frequency reference clock. The division ratio is programmable via an input control signal. The design uses a counter-based toggle mechanism and dual-edge output generation to improve duty-cycle characteristics.

<img src = ./clk_div_tb.svg>

## Parameters

| Parameter         | Description                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `DIV_WIDTH`       | Width of the division control input `div_i`. Determines maximum programmable division factor. |
| `TP`/Clock_Period | Reference input clock period used for timing calculations.                                    |

## Ports

| Port Name | Direction | Width       | Description                   |
| --------- | --------- | ----------- | ----------------------------- |
| `clk_i`   | Input     | 1           | Reference input clock         |
| `div_i`   | Input     | `DIV_WIDTH` | Programmable division factor  |
| `arst_ni` | Input     | 1           | Asynchronous active-low reset |
| `clk_o`   | Output    | 1           | Divided clock output          |

## Challenges and Risks

| Risk              | Description         |
| ----------------- | ------------------- |
| `div_i`=0         | Illegal Value       |
| Small div value   | div=1 edge case     |
| Reset mid-cycle   | Async reset hazards |
| Odd divide values | Non 50% duty cycle  |
| Dual edge timing  | Glitch posibilities |

## Verification Methodology

- **Directed Testing:**  
  Targeted tests for minimum, maximum, zero, and mid-range division values.

- **Edge-case Testing:**  
  Verify `div_i = 1`, `div_i = max`, `div_i = 0`.

- **Reset Testing:**  
  Assert reset during idle and during active counting to verify correct output clearing.

- **Sweep Testing:**  
  Iterate all valid `div_i` values to ensure functional correctness across the full input range.

- **Simulation Monitoring:**  
  Measure output clock period using `$time` to ensure accuracy.

  ## Stimulus Generation

- **Generated using SystemVerilog tasks:**
  - `apply_reset()` → Resets the DUT at the start of simulation.
  - `async_reset()` → Tests asynchronous reset behavior.
  - `check_division(div_val)` → Applies a division ratio and measures the output clock period.
  - `reset_during_op(div_val)` → Asserts reset mid-operation and verifies recovery.

- **Input Clock Generation:**  
  Generated using the following statement:
  ```verilog
  always #(TP/2) clk_i <= ~clk_i;
  ```

## Scoreboarding

- **Output Verification:**  
  Output clock periods are measured and compared against expected values (`TP` \* `div_i`) for each division ratio.

- **Pass/Fail Reporting:**  
  Any mismatch triggers a pass/fail message using `$display`.

## Test Cases

| Test Case              | Description                                  | Test Steps                                    | Expected Output                                      |
| ---------------------- | -------------------------------------------- | --------------------------------------------- | ---------------------------------------------------- |
| Reset Behaviour        | Verify async reset clears counter and output | Apply reset using `apply_reset()`             | `clk_o = 0`                                          |
| Minimum Division       | Verify divider works for div=1               | `check_division(1)`                           | `clk_o` period = `TP`                                |
| Maximum Division       | Verify divider works for div=max (div=15)    | `check_division(15)`                          | `clk_o` period = `TP*15`                             |
| Zero Division          | Verify behavior for div=0                    | `check_division(0)`                           | Output may be undefined; no crash                    |
| Async Reset            | Verify async reset during operation          | `async_reset()`                               | `clk_o = 0`                                          |
| Full Divisional Sweep  | Test all values from 1 to 15                 | Loop `check_division(i)`                      | `clk_o` period = `TP*i`                              |
| Reset During Operation | Assert reset mid-cycle                       | `reset_during_op(3)` and `reset_during_op(2)` | `clk_o = 0` during reset, then correct periods after |

## Test Procedure / Run Instructions

```bash
make all TOP=clk_div_tb
```
