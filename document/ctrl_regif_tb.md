# ctrl_regif Testbench

## Target DUT

`ctrl_regif` — AXI4-Lite slave control register block for the SC-SoC. See [`ctrl_reg.md`](ctrl_reg.md) for the full register map and bit-field definitions, and [`ctrl_if.sv`](../hardware/source/ctrl_if.sv) for the RTL.

## Functional Description

`ctrl_if` exposes twelve memory-mapped registers over AXI4-Lite at `CTRL_BASE = 0x0001_0000`. Seven registers are RW (software-writable); five are RO (hardware-driven constants or live sideband inputs). All five AXI channels are buffered through an internal `axi4l_fifo`. Partial writes (`strb != 4'b1111`) and writes to RO registers return SLVERR. Unmapped offsets return SLVERR on both reads and writes.

RW register outputs (`boot_addr_o`, `hart_id_o`, `core_rst_en_o`, `core_clk_en_o`, `tohost_o`, `fromhost_o`) update one clock after a successful write. RO sideband inputs (`bootmode_i`, `pll_ref_div_i`, `pll_fb_div_i`) are reflected combinationally on reads.

## Challenges and Risks

- RO protection must be verified register-by-register — both fixed-constant RO and live-sideband RO behave differently.
- Sideband outputs must be cross-checked against AXI reads to confirm register-to-output propagation.
- `CORE_CLK_RST` has two active bits in a 32-bit word; reserved bits must remain zero.
- `PLL_CFG` bit-field assembly (`pll_ref_div_i` at `[4:0]`, `pll_fb_div_i` at `[18:5]`) needs explicit layout verification.

## Test Environment

- **Driver** (`axi4l_driver`): generates AXI4-Lite transactions and drives the interface.
- **Monitor** (`axi4l_monitor`): observes DUT responses and forwards them to the scoreboard.
- **Scoreboard**: holds a shadow copy of all RW registers; checks every read against expected data.
- **Sideband model**: testbench-top logic drives `bootmode_i`, `pll_ref_div_i`, `pll_fb_div_i` and samples output ports (`boot_addr_o`, `hart_id_o`, etc.) for cross-checking against AXI reads.

---

## Test Cases

### TC0 — Reset Behavior

#### Objective
Verify all outputs are in their defined reset state and all RW registers read back their reset defaults after `arst_ni` is released.

#### Test Steps
- Assert `arst_ni = 0` for 5 cycles; sample AXI ready/valid and sideband outputs.
- Deassert reset; wait 5 cycles.
- Read every RW register via `read_32` and compare against reset values.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| AXI ready/valid during reset | All 0 |
| `boot_addr_o` during reset | `0x40000000` |
| `hart_id_o`, `tohost_o`, `fromhost_o` during reset | `0x00000000` |
| `core_rst_en_o`, `core_clk_en_o` during reset | `0` |
| RW register reads after reset | Match documented reset values |

---

### TC1 — RO Constant Reads 

#### Objective
Verify SOC_ID and REV_ID return their fixed values on every read.

#### Test Steps
- Read SOC_ID (`0x000`) twice; read REV_ID (`0x004`) twice.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| SOC_ID (both reads) | `0x44670931`, `r.resp = OKAY` |
| REV_ID (both reads) | `0x00000001`, `r.resp = OKAY` |

---

### TC2 — RW Write / Readback 

#### Objective
Verify CORE_BOOT_ADDR and CORE_HART_ID store values and drive their sideband outputs.

#### Test Steps
- Write unique values to each register; read back; sample `boot_addr_o` and `hart_id_o` directly.
- Write second distinct values; repeat.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| `b.resp` | OKAY |
| AXI readback | Matches written value |
| Sideband output | Matches AXI readback |

---

### TC3 — CORE_CLK_RST Bit-Fields

#### Objective
Verify `CORE_RST_EN` (bit 0) and `CORE_CLK_EN` (bit 1) update independently and drive the correct sideband outputs.

#### Test Steps
- Write `0x1`, `0x2`, `0x3`, `0x0` in sequence; after each write read back and sample `core_rst_en_o` / `core_clk_en_o`.

#### Pass Criteria

| Written Value | `core_rst_en_o` | `core_clk_en_o` | `r.data[31:2]` |
| --- | --- | --- | --- |
| `0x00000001` | 1 | 0 | 0 |
| `0x00000002` | 0 | 1 | 0 |
| `0x00000003` | 1 | 1 | 0 |
| `0x00000000` | 0 | 0 | 0 |

---

### TC4 — PLL_CFG Bit-Field Assembly

#### Objective
Verify PLL_CFG assembles `pll_ref_div_i[4:0]` at bits `[4:0]` and `pll_fb_div_i[13:0]` at bits `[18:5]`, with bits `[31:19]` always zero.

#### Test Steps
- Drive `pll_ref_div_i = 5'h10`, `pll_fb_div_i = 14'h3E8`; read PLL_CFG.
- Drive different non-default values; read PLL_CFG again.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| First read | `0x00000C90`, `r.resp = OKAY` |
| Second read `[4:0]` | Matches `pll_ref_div_i` |
| Second read `[18:5]` | Matches `pll_fb_div_i` |
| `[31:19]` | Always `0` |

---

### TC5 — RO Write Protection
 
#### Objective
Verify writes to SOC_ID, REV_ID, and PLL_CFG return SLVERR and leave values unchanged.
 
#### Test Steps
- Using low-level `send_aw` / `send_w` tasks, issue a full-word write (`strb = 4'b1111`) to each of the three registers (SOC_ID at `0x000`, REV_ID at `0x004`, PLL_CFG at `0x040`); record `b.resp` for each.
- Read back each register after its write attempt.

#### Pass Criteria
 
| Check | Expected |
| --- | --- |
| `b.resp` for all three writes (SOC_ID, REV_ID, PLL_CFG) | SLVERR (`2'b10`) |
| SOC_ID readback | `0x44670931` unchanged |
| REV_ID readback | `0x00000001` unchanged |
| PLL_CFG readback | Unchanged |

---

### TC6 — RO Write Protection 

#### Objective
Verify writes to BOOTMODE return SLVERR, and that reads reflect the live `bootmode_i` input immediately.

#### Test Steps
- Drive `bootmode_i = 1`; attempt a write to BOOTMODE (`0x080`); record `b.resp`.
- Read BOOTMODE; verify live value.
- Change `bootmode_i = 0`; re-read without any write and verify updated value.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| `b.resp` | SLVERR |
| BOOTMODE read `[0]` | Matches `bootmode_i` |
| BOOTMODE read `[31:1]` | `0` |

---

### TC7 — TOHOST and FROMHOST Independence

#### Objective
Verify TOHOST and FROMHOST store values independently with no cross-contamination, and drive their respective sideband outputs.

#### Test Steps
- Write distinct values to each; read back both; sample `tohost_o` and `fromhost_o`.
- Write a new value to TOHOST only; confirm FROMHOST is unchanged, and vice versa.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| `b.resp` | OKAY |
| Readbacks | Each returns its own written value |
| `tohost_o` / `fromhost_o` | Match AXI readback |
| Cross-contamination | None |

---

### TC8 — Partial Write Rejection

#### Objective
Verify any `strb != 4'b1111` write returns SLVERR and does not modify the target register.

#### Test Steps
- Using low-level tasks, issue writes to CORE_BOOT_ADDR with strb patterns: `4'b0001`, `4'b0011`, `4'b0111`, `4'b1110`, `4'b1100`, `4'b1000`. Record `b.resp` for each; read back after each.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| `b.resp` for all partial writes | SLVERR |
| CORE_BOOT_ADDR after each rejected write | Unchanged |

---

### TC9 — Unmapped Address Handling
 
#### Objective
Verify reads and writes to unmapped offsets within the CTRL aperture return SLVERR safely, including the interior hole at `0x064` between TOHOST and FROMHOST.
 
#### Test Steps
- Issue full-word writes (`strb = 4'b1111`) to offsets `0x008`, `0x050`, `0x064`, `0x0F0`; record `b.resp` for each.
- Issue reads to the same four offsets; record `r.resp` and `r.data` for each.

#### Pass Criteria
 
| Check | Expected |
| --- | --- |
| `b.resp` for all four writes | SLVERR (`2'b10`) |
| `r.resp` for all four reads | SLVERR (`2'b10`) |
| `r.data` for all four reads | `0x00000000` |


---

### TC10 — AXI FIFO Back-Pressure

#### Objective
Verify the internal `axi4l_fifo` correctly stalls and drains under back-pressure on both the write and read paths.

#### Test Steps
- **Write path:** Queue 4 writes to CORE_BOOT_ADDR while holding `b_ready = 0`; assert `b_ready` and confirm all responses drain.
- **Read path:** Queue 4 reads from CORE_HART_ID while holding `r_ready = 0`; assert `r_ready` and confirm all responses drain.

#### Pass Criteria

| Check | Expected |
| --- | --- |
| `aw_ready` / `w_ready` when FIFO full | Deasserted |
| `ar_ready` when FIFO full | Deasserted |
| All write responses after drain | OKAY, in order |
| All read responses after drain | OKAY, correct data, in order |