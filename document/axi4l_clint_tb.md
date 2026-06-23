# AXI4-Lite CLINT Testbench

## Document Information

| Item | Description |
| ---- | ----------- |
| Testbench | `axi4l_clint_tb` |
| DUT | `axi4l_clint` |
| Verification Level | Module-level wrapper |
| Language | SystemVerilog |
| Verification Style | Directed self-checking |

## Target DUT

`axi4l_clint` is the top-level CLINT wrapper. It instantiates `axi4l_clint_regif`, exposes the AXI4-Lite slave interface, forwards raw CLINT status outputs, and packs local interrupt sources into the 32-bit CPU interrupt vector.

See [`axi4l_clint.md`](axi4l_clint.md) for the wrapper architecture and SoC integration notes.

## Test Environment

The testbench instantiates:

- **DUT**: `axi4l_clint`
- **Interface**: `axi4l_if` parameterized with CLINT AXI4-Lite request/response types
- **Stimulus tasks**: local `write_32()` and `read_32()` helpers
- **Interrupt stimulus**: direct control of `timer_en_i` and `ext_irq_i`
- **Checker**: `check()` task that accumulates pass/fail counts and fails the run if any check fails

The wrapper test intentionally keeps register behavior checks small because detailed register verification is covered by [`axi4l_clint_regif_tb.md`](axi4l_clint_regif_tb.md). Its main purpose is to prove wrapper-level connectivity and interrupt-vector packing.

## CPU Interrupt Mapping Under Test

| Source | Output Bit | Meaning |
| ------ | ---------- | ------- |
| `msip_irq_o` | `irq_o[3]` | Machine software interrupt |
| `timer_irq_o` | `irq_o[7]` | Machine timer interrupt |
| `ext_irq_i` | `irq_o[11]` | Machine external interrupt |

All other `irq_o` bits are expected to remain low in this directed test.

## Helper Tasks

| Task | Purpose |
| ---- | ------- |
| `write_32(addr, data, resp)` | Sends a full-word AXI4-Lite write |
| `read_32(addr, data, resp)` | Sends an AXI4-Lite read and extracts data/response |
| `reset_dut()` | Clears stimulus, resets the DUT, and releases reset after four clocks |
| `check(ok, msg)` | Reports each check and updates pass/fail counters |

## Test Cases

### TC0 - IRQ Vector Packing

#### Objective
Verify that the wrapper maps software, timer, and external interrupts into the expected CPU IRQ bits.

#### Steps
- Reset the DUT and confirm `irq_o` is zero.
- Write `MSIP = 1` through the AXI4-Lite interface.
- Drive `ext_irq_i = 1`.
- Program `MTIME = 0` and `MTIMECMP = 1`.
- Enable `timer_en_i` for one clock.
- Check combined IRQ vector state.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| Reset vector | `irq_o = 0x0000_0000` |
| MSIP write response | OKAY |
| Software interrupt mapping | `msip_irq_o = 1` and `irq_o[3] = 1` |
| Timer/external bits before stimulus | `irq_o[7] = 0`, `irq_o[11] = 0` |
| External interrupt mapping | `ext_irq_i = 1` drives `irq_o[11] = 1` |
| Timer compare match | `timer_irq_o = 1` and `irq_o[7] = 1` |
| Combined state | `irq_o[3]`, `irq_o[7]`, and `irq_o[11]` can be high together |

### TC1 - Register Access Through Wrapper

#### Objective
Verify that the wrapper forwards AXI4-Lite register accesses to the internal register interface and exposes the resulting sideband outputs.

#### Steps
- Clear `MSIP` through the wrapper and check `irq_o[3]`.
- Write both halves of `MTIMECMP`.
- Check the assembled `mtimecmp_o` output.
- Read `MTIMECMP_LO` back through the wrapper.

#### Pass Criteria

| Check | Expected |
| ----- | -------- |
| Clear MSIP write | OKAY and `irq_o[3] = 0` |
| `mtimecmp_o` output | `0x0000_0002_CAFE_BABE` |
| `MTIMECMP_LO` readback | `0xCAFE_BABE`, OKAY |

## Expected Result

The testbench prints individual check results and ends with:

```text
axi4l_clint_tb summary: pass=<N> fail=0
```

Any nonzero fail count terminates the simulation with `$fatal`.

## Run Command

```bash
make simulate TOP=axi4l_clint_tb
```

The testbench writes `axi4l_clint_tb.vcd` for waveform inspection.

