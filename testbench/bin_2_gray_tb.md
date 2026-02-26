# Binary to Gray Code Converter Testplan - Comprehensive Stress Testing

## 1. Introduction
This testplan outlines an exhaustive and stress-testing verification strategy for the Binary to Gray Code Converter module (`bin_2_gray`). The goal is to push the module to its limits by covering all possible inputs, edge cases, random scenarios, and parameterized configurations. The module is combinational, converting binary input `bin_i` to Gray code output `gray_o` using XOR operations.

<center>
<img src="./bin_to_gray_tb.svg">
</center>

## 2. Module Interface
- **Parameters:**
  - `WIDTH`: Bit width of inputs/outputs (default 8, tested up to 32 or more)
- **Inputs:**
  - `bin_i`: [WIDTH-1:0] binary value
- **Outputs:**
  - `gray_o`: [WIDTH-1:0] Gray code value
- **Algorithm:**
  - `gray_o[WIDTH-1] = bin_i[WIDTH-1]`
  - `gray_o[i] = bin_i[i] ^ bin_i[i+1]` for i = 0 to WIDTH-2

## 3. Test Objectives
- Achieve 100% functional coverage: Verify correct conversion for every possible input.
- Stress test: Rapid input changes, large datasets, parameterized sweeps.
- Edge case validation: Boundary values, special patterns.
- Performance: Ensure no combinatorial delays or glitches (though combinational).
- Regression: Re-run tests after any code changes.

## 4. Test Environment
- **Testbench Language:** SystemVerilog
- **Simulation Tool:** Vivado Simulator (based on workspace files)
- **Coverage Tools:** Functional coverage for input/output toggles, transitions.
- **Stimulus:** Directed, random, and exhaustive vectors.

## 5. Test Cases - Pushing to Limits

### 5.1 Exhaustive Testing (for WIDTH ≤ 8)
For small widths, test all 2^WIDTH combinations to ensure no missed cases.

| Test Case | WIDTH | Inputs | Expected Behavior | Rationale |
|-----------|-------|--------|-------------------|-----------|
| TC_EXH_4 | 4 | All 16 values (0 to 15) | Correct Gray codes (e.g., 0→0, 1→1, 2→3, ..., 15→8) | Full coverage for small width |
| TC_EXH_8 | 8 | All 256 values | Correct conversions | Stresses logic for byte-width |

### 5.2 Edge Cases
| Test Case | Input (`bin_i`) | Expected (`gray_o`) | Rationale |
|-----------|-----------------|---------------------|-----------|
| TC_ZERO | 0 | 0 | Minimum value |
| TC_MAX | {WIDTH{1'b1}} | MSB=1, rest XORed (e.g., for 8-bit: 255→128) | Maximum value, checks MSB handling |
| TC_POW2 | 2^k for k=0 to WIDTH-1 | Specific Gray (e.g., 1→1, 2→3, 4→6, 8→12) | Powers of 2, toggles single bits |
| TC_ALT1 | Alternating 1s (e.g., 8'b10101010) | XOR result (e.g., 8'b11111111) | Pattern to stress XOR chain |
| TC_ALT2 | Alternating 0s (e.g., 8'b01010101) | XOR result (e.g., 8'b01111111) | Inverse pattern |

### 5.3 Random and Stress Testing
| Test Case | Description | Stimulus | Expected | Rationale |
|-----------|-------------|----------|----------|-----------|
| TC_RAND_1K | 1000 random inputs | Random [0:2^WIDTH-1] | Correct Gray for each | Statistical coverage |
| TC_RAND_10K | 10,000 random inputs | Random vectors | No errors | Stress for large datasets |
| TC_TRANS | Transition coverage | Sweep consecutive values (0 to 2^WIDTH-1) | Each step differs by 1 bit in Gray | Verifies Gray property |
| TC_RAPID | Rapid changes | Toggle inputs every clock (if clocked) | Stable outputs | Checks for glitches (though combinational) |

### 5.4 Parameterized Testing
| Test Case | WIDTH Values | Inputs per WIDTH | Expected | Rationale |
|-----------|--------------|------------------|----------|-----------|
| TC_PARAM_SWEEP | 1,2,4,8,16,32 | Edge cases + random | Correct scaling | Ensures parameterization works |
| TC_WIDTH_1 | 1 | 0,1 | 0→0, 1→1 | Minimal width |
| TC_WIDTH_32 | 32 | 0, 2^31-1, 2^31, 2^32-1 | Correct 32-bit conversions | Large width stress |

### 5.5 Functional Coverage Goals
- **Input Coverage:** 100% toggle on each bit of `bin_i`.
- **Output Coverage:** 100% toggle on each bit of `gray_o`.
- **Transition Coverage:** All possible 1-bit changes in Gray code.
- **Corner Cases:** All combinations of MSB/LSB states.

## 6. Testbench Implementation
- **Stimulus Generation:** Use loops for exhaustive, $random for random.
- **Checking:** Assert `gray_o == expected` for each input.
- **Reporting:** Log failures, coverage metrics.
- **Performance:** Run simulations with timing analysis if applicable.

## 7. Pass/Fail Criteria
- All test cases pass without assertion failures.
- 100% coverage achieved.
- No simulation errors or timeouts.
- Outputs match expected Gray codes for all inputs.

## 8. Risks and Mitigations
- **Large WIDTH:** For WIDTH>8, exhaustive not feasible; rely on random + directed.
- **Timing:** If added to synchronous design, test with clock.
- **Tool Limits:** Use batch simulations for large test suites.

This testplan pushes the module by ensuring exhaustive coverage where possible and statistical stress otherwise, validating the XOR logic thoroughly.

