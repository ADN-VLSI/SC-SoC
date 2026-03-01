#   Testbench for Generic Memory
##  DUT: Generic Memory (`mem`)
### Author: Dhruba Jyoti Barua


---

# 1. Document Information

| Item | Description |
|------|------------|
| DUT Name | `mem` |
| Design Type | Parameterized single-port memory |
| Verification Level | Module-level |
| Language | SystemVerilog |
| Verification Style | Structured (Non-UVM, scalable to UVM) |

---

# 2. Target DUT Description

## 2.1 RTL Interface

```systemverilog
module mem #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    input  logic                    we_i,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    input  logic [DATA_WIDTH/8-1:0] wstrb_i,
    output logic [DATA_WIDTH-1:0]   rdata_o
);
```
## 2.2 Parameter Definitions

| Parameter | Description | Derived Value |
|------------|------------|---------------|
| `ADDR_WIDTH` | Address bus width in bits | — |
| `DATA_WIDTH` | Data bus width in bits | — |
| `DEPTH` | Number of memory locations | `2^ADDR_WIDTH` |
| `BYTE_LANES` | Number of byte segments per word | `DATA_WIDTH / 8` |

### Assumptions
- `DATA_WIDTH` is a multiple of 8.
- Memory is single-clocked.
- Write occurs on positive clock edge.
- Read behavior is asynchronous (unless specified otherwise).

---

# 3  Functional Description

## 3.1 Overview

The DUT is a parameterized single-port memory with byte-enable write capability.

It supports:
- Full word writes
- Partial byte writes
- Read access through address selection

---

## 3.2 Write Operation

- Triggered on `posedge clk_i`
- Active when `we_i == 1`
- For each byte lane `b`:
 
if (wstrb_i[b] == 1)
update byte
else
retain previous value

- `wstrb_i` controls which bytes are modified.

---

## 3.3 Read Operation

- `rdata_o` reflects memory content at `addr_i`.
- Read is assumed combinational (asynchronous).
- If design is synchronous-read, verification timing must adjust accordingly.

---

## 3.4 Key Functional Capabilities

- Parameterizable depth and width
- Byte masking support
- Single-port architecture
- Independent address selection

---


# 4. Architecture



## 4.1 DUT Architecture

![DUT Architecture](mem_tb_dut_arch.drawio.svg)

## 4.2 Verification Architecture

![verification Architecture](mem_tb_verification.drawio.svg)

---

# 5. Challenges and Risks

## 5.1 Functional Risks

| Risk | Description |
|------|------------|
| Byte slicing errors | Incorrect `[8*b +: 8]` indexing |
| Mask logic error | Incorrect update of non-selected bytes |
| Read-after-write timing | Misinterpreting read during write cycle |
| Uninitialized memory | X propagation during early reads |

---

## 5.2 Verification Risks

- Missing corner cases
- Incomplete strobe coverage
- Race conditions in testbench
- Insufficient random stress

---

# 6. Test Environment

## 6.1 Environment Overview

The testbench consists of:

Test → Driver → DUT → Monitor → Scoreboard

---

## 6.2 Components

### Driver
- Drives input signals:
  - `addr_i`
  - `we_i`
  - `wdata_i`
  - `wstrb_i`
- Synchronized to clock

---

### Monitor
- Observes:
  - Address
  - Write enable
  - Write data
  - Strobes
  - Read data
- Samples at safe timing point (recommended: negedge)

---

### Scoreboard
- Maintains reference memory model
- Applies same write logic as DUT
- Compares expected vs observed read data

---

## 6.3 Simulation Requirements

- SystemVerilog simulator
- Clock generation
- Controlled initialization phase
- Error reporting mechanism

---

# 7. Testbench Architecture

## 7.1 Structural Components

| Component | Responsibility |
|------------|---------------|
| Interface | Signal encapsulation |
| Driver | Stimulus generation |
| Monitor | Signal sampling |
| Scoreboard | Golden reference |
| Test Controller | Test execution |

---

## 7.2 Synchronization Strategy

- Write sampled at posedge.
- Read comparison sampled at negedge or with small delay.
- Avoid race conditions between DUT and scoreboard.

---

# 8. Verification Methodology

## 8.1 Strategy

Hybrid approach:

1. Directed testing
2. Constrained random testing
3. Functional coverage-driven verification

---

## 8.2 Exit Criteria

- All directed test cases pass
- No mismatches in random regression
- Coverage goals achieved

---

# 9. Stimulus Generation

## 9.1 Directed Stimulus

- Full word write and read
- Single byte write
- Mixed byte write
- No-op write (`wstrb = 0`)
- Boundary address testing
- Repeated masked updates to same address

---

## 9.2 Random Stimulus

Randomize:
- Address
- Write enable
- Write data
- Write strobe

Recommended distribution:
- 60% writes
- 40% reads

Ensure sufficient write operations before checking reads.

---

# 10. Scoreboarding

## 10.1 Reference Model

Reference memory:

``` 
ref_mem[0 : DEPTH-1]

```
Track initialization status per address.

---

## 10.2 Write Update Rule


for each byte lane `b`:

    if (wstrb[b] == 1)
    ref_mem[addr][8b +: 8] = wdata[8b +: 8]

---

## 10.3 Read Comparison Rule

expected = ref_mem[addr]
if (observed !== expected)
report error

Use case-inequality (`!==`) to detect X/Z mismatches.

---

# 11 Test Cases

---

## TC1 – Full Write

### Name
`tc_full_write`

### Description
Verify complete 32-bit write and correct readback.

### Test Steps
Write:
  addr = 0x3
  wdata = 0xDEAD_BEEF
  wstrb = 4'b1111

Read:
  addr = 0x3

### Expected Result
rdata_o = 0xDEAD_BEEF

---

## TC2 – Partial Write

### Name
`tc_partial_write `

### Description
Verify byte-enable write behavior

### Test Steps
1. Full Write

addr = 0xB
wdata = 0x1122_3344
wstrb = 1111

2. Partial Write

addr = 0xB
wdata = 0x0000_00AA
wstrb = 0001

3. Read back

addr = 0xB

### Expected Result

0x1122_33AA

---

## TC3 – No-Op Write(wrtrb = 0)

### Name
`tc_noop`

### Description
Ensure memory is unchanged when no write strobes active.

Sequence.

### Test Steps
1. Write

addr = 0x4
wdata = 0xCAFE_BABE
wstrb = 1111

2. No-op write

addr = 0x4
wdata = 0xFFFF_FFFF
wstrb = 0000

3. Read

addr = 0x4


### Expected Result

0xCAFE_BABE

---

## TC4 – Same Row Test (Word Alignment)

### Name
`tc_same_row`

### Description
Verify addresses within same word return identical data.

### Test Steps

1. Write

addr = 0x8
wdata = 0xAAAA_BBBB
wstrb = 1111

2. Read

addr = 0X9

3. Read

addr = 0XA

### Expected Result

rdata_o = 0xAAAA_BBBB

---


---

