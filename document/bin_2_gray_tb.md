# Binary to Gray Code Converter - Testbench Documentation
# Bin2Gray Test Plan

## Target DUT

Name: `bin_2_gray`  
Source: `source/bin_2_gray.sv`  
Interface (key signals):
- `bin_i` : input [WIDTH-1:0] — binary value
- `gray_o`: output [WIDTH-1:0] — Gray code equivalent

Parameter(s):
- `WIDTH` (int, default 8) — bit width of the converter

## Functional Description

The DUT converts a binary vector to its Gray-code equivalent using the rule:

```
Gray[MSB] = Binary[MSB]
Gray[i]   = Binary[i] XOR Binary[i+1]
```
<center>
<img src="./bin_2_gray_tb.svg">
</center>

The conversion is purely combinational and parameterized by `WIDTH`.

## Challenges and Risks

- For large `WIDTH` values the testbench exhaustive approach (2^WIDTH vectors) becomes slow or impractical.
- Ensuring consistent bit ordering and endianness in expected-value calculation and display.
- Simulator-dependent formatting for wide vectors in logs (use hex/bin formatting consistently).

## Test Environment

Simulator: XSim / ModelSim (commands given in Usage).  
Files under testbench:
- `testbench/bin_2_gray_new_tb.sv` — directed exhaustive testbench used for verification

### Testbench Architecture

- Stimulus generator: simple up-counter from `0` to `2^WIDTH-1` (`bin_stimulus`).
- DUT instance: `bin_2_gray #(.WIDTH(WIDTH))`
- Checker: `binary_to_gray()` function computes expected value; `verify_gray_output()` compares DUT output and logs result.
- Report: console summary with total / passed / failed counts.

## Verification Methodology

Primary approach: Directed exhaustive testing for small `WIDTH` (default 8 → 256 vectors). For larger widths use sampled/random + corner tests.

- Stimulus Generation: deterministic up-counter covering [0 .. 2^WIDTH-1] for exhaustive checks.
- Scoreboarding: immediate functional comparison in `verify_gray_output()` with expected value from `binary_to_gray()`.
- Coverage (recommended): track which input vectors and transition patterns have been exercised (see Functional Coverage).

## Test Cases

Each test case below is a directed test executed as part of the main loop in `bin_2_gray_new_tb.sv` or as a focused scenario.

### Foreach test case

- Test Case Name: `Exhaustive_Basic`  
  Description: Verify all input vectors for small WIDTH (exhaustive).  
  Test Steps:
  1. For each `i` in 0..(2^WIDTH-1): drive `bin_i = i` and wait 1 time unit.  
  2. Read `gray_o`.  
  3. Compute expected Gray using `binary_to_gray(i)`.  
  4. Compare and log PASS/FAIL.  
  Expected Results: DUT output equals expected Gray for every vector.

- Test Case Name: `Edge_AllZeros`  
  Description: Single-vector test with all zeros.  
  Test Steps: Drive `bin_i = 0`.  
  Expected Results: `gray_o == 0`.

- Test Case Name: `Edge_AllOnes`  
  Description: Single-vector test with all ones.  
  Test Steps: Drive `bin_i = {WIDTH{1'b1}}`.  
  Expected Results: `gray_o == binary_to_gray({WIDTH{1'b1}})`.

- Test Case Name: `Transition_Adjacent`  
  Description: Verify single-bit transitions between adjacent binary values produce single-bit changes in Gray outputs.  
  Test Steps: Iterate small sequence of adjacent binaries (e.g., 0..15) and verify Hamming distance of Gray outputs equals 1 between consecutive vectors.  
  Expected Results: Consecutive Gray code outputs differ by exactly one bit.

- Test Case Name: `Random_Sample`  
  Description: For large WIDTH, sample random vectors plus some corner cases.  
  Test Steps: Apply N random vectors, check output each time.  
  Expected Results: DUT output equals expected Gray for sampled vectors.

## Test Case Summary Table

| Test Case        | Purpose                          | Execution Mode    | Expected Result |
|------------------|----------------------------------|-------------------|-----------------|
| Exhaustive_Basic | Exhaustive functional check      | Directed / loop   | All vectors PASS |
| Edge_AllZeros    | Zero-vector edge case            | Directed single   | PASS            |
| Edge_AllOnes     | All-ones edge case               | Directed single   | PASS            |
| Transition_Adjacent | Bit-transition behavior test  | Directed sequence | PASS (1-bit changes) |
| Random_Sample    | Scalable sampling for large WIDTH| Directed random    | PASS (samples)  |

## Functional Coverage

Coverage goals (examples):

- Input vector coverage: for small `WIDTH` aim for 100% (exhaustive).  
- Bit-transition coverage: ensure all single-bit transitions between adjacent binary values are observed in Gray outputs.  
- Edge coverage: zero and all-ones vectors exercised.

Metric and measurement:
- For `WIDTH <= 10` use exhaustively measured 2^WIDTH vectors and report percent covered.  
- For larger WIDTH, measure percent of sampled space and number of unique Gray outputs observed.

## Test Procedure / Run Instructions

Build & run (XSim example):

```bash
xvlog source/bin_2_gray.sv testbench/bin_2_gray_new_tb.sv
xelab bin_2_gray_tb -debug all
xsim bin_2_gray_tb -gui
```

Or run headless and record transcript:

```bash
xvlog source/bin_2_gray.sv testbench/bin_2_gray_new_tb.sv
xelab bin_2_gray_tb
xsim bin_2_gray_tb -tclbatch run.do -nolog
```

ModelSim/Questa example:

```bash
vlog source/bin_2_gray.sv testbench/bin_2_gray_new_tb.sv
vsim -c bin_2_gray_tb -do "run -all; quit"
```

## Verification Points / Exit Criteria

- DUT passes all directed exhaustive tests for the selected `WIDTH`.  
- No mismatches found in `verify_gray_output()` (fail_count == 0).  
- Transition checks confirm single-bit change between consecutive Gray outputs.  
- Test logs and summary generated, and regression run passes on CI for target WIDTH.

## Notes

- The testbench `bin_2_gray_new_tb.sv` is intentionally simple and deterministic to make debugging straightforward.  
- For integration into a larger regression framework, wrap the testbench in a harness that can accept run-time `WIDTH` overrides and produce machine-readable result artifacts (CSV/JSON).  

## Appendix A — Small Binary→Gray Table (3-bit example)

| Binary | Gray |
|--------|------|
| 000    | 000  |
| 001    | 001  |
| 010    | 011  |
| 011    | 010  |
| 100    | 110  |
| 101    | 111  |
| 110    | 101  |
| 111    | 100  |

## Document History

- Created: February 26, 2026
