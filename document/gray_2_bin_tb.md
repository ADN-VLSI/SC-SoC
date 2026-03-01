# Gray-to-Binary Test Plan

## Target DUT

The Device Under Test (DUT) is a **Gray-to-Binary Converter**.

- **Module Name:** `gray_2_bin`
- **Parameter:** `WIDTH` (Default set to 8, but adjustable to any integer).
- **Inputs:** `gray_i` (Width defined by `WIDTH`).
- **Outputs:** `bin_o` (Width defined by `WIDTH`).

## Functional Description

The DUT is a combinational module that converts a Gray-coded input vector into its standard Binary representation.

- **Logic:** The conversion follows the XOR-chain algorithm.
- **MSB:** The Binary Most Significant Bit is equal to the Gray MSB ($B[n] = G[n]$).
- **LSB & Intermediate Bits:** Each subsequent binary bit is calculated by XORing the current Gray bit with the previously calculated binary bit ($B[i] = G[i] \oplus B[i+1]$).

## Challenges and Risks

- **Combinational Path Length:** As `WIDTH` increases, the sequential nature of the XOR chain increases propagation delay, which may lead to timing issues if not modeled correctly in the testbench.
- **Edge Case Accuracy:** High risk of "off-by-one" errors in the loop logic at the `WIDTH-1` or bit `0` boundaries.
- **Verification Exhaustion:** Testing all $2^{8}$ combinations is not feasible; therefore, the quality of random stimulus is critical.

## Test Environment

The environment uses a non-UVM SystemVerilog approach focused on modularity through tasks.

### Testbench Architecture

<img src="./gray_2_bin_tb.svg">

## Verification Methodology

The plan utilizes a hybrid approach:

- **Stimulus Generation:** \* **Directed:** Targets specific values like all-zeros and all-ones.
- **Random:** Uses constrained random generation to fill the state space.

- **Scoreboarding:** \* Verification is performed by an internal task that mirrors the hardware algorithm in software.
- Uses **Case Equality (`===`)** to ensure no `X` or `Z` values are present on the output bus.

---

## Test Cases

### Test Case 1 – `test_min_boundary`

**Purpose:**  
Verify that the DUT correctly converts the minimum Gray code value (all zeros).

**Stimulus:**

- Gray code input: `8'h00` (all zeros).

**Procedure:**

1. Apply `gray_i = 8'h00` to the DUT.
2. Wait for combinational logic to settle (`#10`).
3. Compare DUT output (`bin_o`) with reference model output (Golden Model).
4. Repeat for 10 iterations.

**Expected Result:**

- DUT output should be `8'h00`.
- Pass/fail counted in scoreboard.

---

## Test Case 2 – `test_max_boundary`

**Purpose:**  
Verify that the DUT correctly converts the maximum Gray code value (all ones).

**Stimulus:**

- Gray code input: `8'hFF` (all ones).

**Procedure:**

1. Apply `gray_i = 8'hFF` to the DUT.
2. Wait for combinational logic to settle (`#10`).
3. Compare DUT output (`bin_o`) with reference model output.
4. Repeat for 10 iterations.

**Expected Result:**

- DUT output should be `8'hAA`.
- Pass/fail counted in scoreboard.

---

## Test Case 3 – `test_check_board`

**Purpose:**  
Verify correct conversion for a checkerboard Gray code pattern.

**Stimulus:**

- Gray code input: alternating pattern `8'hAA`

**Procedure:**

1. Apply `gray_i = {4{2'b10}}` to the DUT.
2. Wait for combinational logic to settle (`#10`).
3. Compare DUT output (`bin_o`) with reference model output.
4. Repeat for 10 iterations.

**Expected Result:**

- DUT output should be `8'hCC`.
- Pass/fail counted in scoreboard.

---

## Test Case 4 – `test_random_sequence`

**Purpose:**  
Verify that the DUT correctly converts random Gray code sequences and that the scoreboard correctly flags errors.

**Stimulus:**

- Random Gray code patterns generated using `$urandom_range(0, 2**WIDTH-1)`.

**Procedure:**

1. Apply random Gray code input to the DUT (`gray_i`).
2. Wait for combinational logic to settle (`#10`).
3. Compare DUT output (`bin_o`) with reference model output.
4. Repeat for 1000 iterations (In our case, it iterates 1,000 times, but it can be iterated by initializing `test_random` with any value.).

**Error Injection:**

- Controlled by the flag: `ENABLE_ERROR_INJECTION`
  - **Type:** `bit`
  - **Default Value:** `1` (enabled)
  - **Purpose:** When enabled, intentional errors are injected at specific iterations:
    - Iteration 50 → LSB of `bin_o` is flipped (`bin_o ^ 1'b1`)
    - Iteration 100 → LSB of `bin_o` is flipped (`bin_o ^ 1'b1`)
  - **Effect:** Triggers scoreboard to increment `fail_count`.
  - **If Disabled (`ENABLE_ERROR_INJECTION = 0`)** → all DUT outputs are compared normally; no intentional errors.

**Expected Result:**

- DUT output should match the reference model except during intentional error injections.
- Failures during error injection confirm that the verification environment correctly detects mismatches.

**Example Usage in Testbench:**

```systemverilog
bit ENABLE_ERROR_INJECTION = 1; // set to 0 to disable error injection
```

## Verification Summary Table

| Test Case Name       | Type              | Iterations | Error Injection | Flag Name                    | Purpose                                     |
| -------------------- | ----------------- | ---------- | --------------- | ---------------------------- | ------------------------------------------- |
| test_min_boundary    | Directed Boundary | 10         | No              | N/A                          | Verify minimum Gray code input (all 0s)     |
| test_max_boundary    | Directed Boundary | 10         | No              | N/A                          | Verify maximum Gray code input (all 1s)     |
| test_check_board     | Pattern           | 10         | No              | N/A                          | Verify checkerboard pattern (1010...)       |
| test_random_sequence | Random            | 1000       | Yes             | `ENABLE_ERROR_INJECTION` = 1 | Verify random Gray codes + scoreboard check |

---

**Total Iterations:** 1030  
**Scoreboard:** Pass/Fail counted for all iterations  
**Error Injection Enabled:** Only in `test_random_sequence` (iterations 50 and 100)

## Test Procedure / Run Instructions

```bash
make all TOP=gray_2_bin_tb
```
