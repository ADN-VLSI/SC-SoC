# AXI4-Lite CLINT Register Interface Testbench

## Document Information

| Item | Description |
| ---- | ----------- |
| Testbench | `axi4l_clint_regif_tb` |
| DUT | `axi4l_clint_regif` |
| Verification Level | Module-level |
| Language | SystemVerilog |
| Verification Style | Directed self-checking |

## Target DUT

`axi4l_clint_regif` is the AXI4-Lite register interface for the single-hart CLINT block. It exposes `MSIP`, `MTIMECMP`, and `MTIME` registers and drives raw machine software and timer interrupt outputs.

See [`axi4l_clint_regif.md`](axi4l_clint_regif.md) for the full register map and functional behavior.

## Test Environment

The testbench instantiates:

- **DUT**: `axi4l_clint_regif`
- **Interface**: `axi4l_if` parameterized with `clint_axil_req_t` and `clint_axil_resp_t`
- **Clock/reset generation**: 100 MHz-style clock (`#5` half period) and active-low asynchronous reset
- **Stimulus tasks**: local AXI4-Lite write/read helpers using interface `send_*` and `recv_*` tasks
- **Checker**: `check()` task that counts pass/fail results and ends the simulation with `$fatal` on any failure

The testbench drives local CLINT offsets directly. The SoC-level base address subtraction is verified in wrapper/integration testing, not in this register-interface testbench.

## Helper Tasks

| Task | Purpose |
| ---- | ------- |
| `write_32(addr, data, resp)` | Issues a full-word AXI4-Lite write with `wstrb = 4'b1111` |
| `write_32_strb(addr, data, strb, resp)` | Issues a write with an explicit byte strobe pattern |
| `read_32(addr, data, resp)` | Issues an AXI4-Lite read and splits returned data/response |
| `reset_dut()` | Clears stimulus, asserts reset for four clocks, then releases reset |
| `check(ok, msg)` | Records and displays pass/fail status |

## Test Cases

### TC0 - Reset Values

#### Objective
Verify reset defaults for all software-visible CLINT registers and interrupt outputs.

#### Steps
- Reset the DUT.
- Read `MSIP`, `MTIMECMP_LO`, `MTIMECMP_HI`, `MTIME_LO`, and `MTIME_HI`.
- Sample `msip_irq_o` and `timer_irq_o`.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| `MSIP` | `0x0000_0000`, OKAY |
| `MTIMECMP_LO` | `0xFFFF_FFFF`, OKAY |
| `MTIMECMP_HI` | `0xFFFF_FFFF`, OKAY |
| `MTIME_LO` | `0x0000_0000`, OKAY |
| `MTIME_HI` | `0x0000_0000`, OKAY |
| Interrupt outputs | Both low |

### TC1 - MSIP Behavior

#### Objective
Verify that only `MSIP[0]` is stored and that it controls the software interrupt output.

#### Steps
- Write `0xFFFF_FFFF` to `MSIP`.
- Read `MSIP` back and sample `msip_irq_o`.
- Write `0x0000_0000` to `MSIP`.
- Read `MSIP` back and sample `msip_irq_o` again.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| Set write response | OKAY |
| Set readback | `0x0000_0001` |
| `msip_irq_o` after set | High |
| Clear write response | OKAY |
| Clear readback | `0x0000_0000` |
| `msip_irq_o` after clear | Low |

### TC2 - 64-bit Register Read/Write

#### Objective
Verify split 32-bit access to the 64-bit `MTIMECMP` and `MTIME` registers.

#### Steps
- Write lower and upper halves of `MTIMECMP`.
- Check the assembled `mtimecmp_o` output.
- Read both halves back.
- Write lower and upper halves of `MTIME`.
- Check the assembled `mtime_o` output.
- Read both halves back.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| `MTIMECMP` assembled output | `0x0123_4567_89AB_CDEF` |
| `MTIMECMP_LO` readback | `0x89AB_CDEF`, OKAY |
| `MTIMECMP_HI` readback | `0x0123_4567`, OKAY |
| `MTIME` assembled output | `0xFEDC_BA98_7654_3210` |
| `MTIME_LO` readback | `0x7654_3210`, OKAY |
| `MTIME_HI` readback | `0xFEDC_BA98`, OKAY |

### TC3 - Timer Count and Interrupt

#### Objective
Verify timer enable, timer incrementing, timer compare interrupt assertion, and interrupt clearing by moving the compare value into the future.

#### Steps
- Program `MTIME = 0`.
- Program `MTIMECMP = 3`.
- Enable `timer_en_i` for three clocks.
- Disable `timer_en_i` and observe that `MTIME` stops changing.
- Program a future `MTIMECMP` value.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| Before compare match | `timer_irq_o = 0` |
| After three enabled clocks | `mtime_o` increases by `3` |
| At compare match | `timer_irq_o = 1` |
| With `timer_en_i = 0` | `mtime_o` remains stable |
| Future compare write | OKAY and `timer_irq_o = 0` |

### TC4 - Error Responses

#### Objective
Verify the register interface rejects unsupported writes and unmapped offsets.

#### Steps
- Attempt a partial write to `MSIP` with `wstrb = 4'b0001`.
- Attempt a full-word write to unmapped offset `0x0004`.
- Attempt a read from unmapped offset `0x0004`.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| Partial write | SLVERR |
| Unmapped write | SLVERR |
| Unmapped read | SLVERR with `r.data = 0x0000_0000` |

## Expected Result

The testbench prints a pass/fail line for each check, then reports:

```text
axi4l_clint_regif_tb summary: pass=<N> fail=0
```

Any nonzero fail count terminates the simulation with `$fatal`.

## Run Command

```bash
make simulate TOP=axi4l_clint_regif_tb
```

Enable wave dumping in the simulator output by opening the generated `axi4l_clint_regif_tb.vcd`.

