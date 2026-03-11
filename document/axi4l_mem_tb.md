# AXI4-Lite Memory Testbench

## Document Information

| Item               | Description                           |
| ------------------ | ------------------------------------- |
| DUT Name           | `axi4l_mem`                           |
| Design Type        | AXI4-Lite slave memory peripheral     |
| Verification Level | Module-level                          |
| Language           | SystemVerilog                         |
| Verification Style | Structured (Non-UVM, scalable to UVM) |

## Target DUT Description

### RTL Interface

```systemverilog
module axi4l_mem #(
    parameter type axi4l_req_t = defaults_pkg::axi4l_req_t,
    parameter type axi4l_rsp_t = defaults_pkg::axi4l_rsp_t,
    parameter int  ADDR_WIDTH  = 32,
    parameter int  DATA_WIDTH  = 64
) (
    input  logic       arst_ni,
    input  logic       clk_i,
    input  axi4l_req_t axi4l_req_i,
    output axi4l_rsp_t axi4l_rsp_o
);
```

### AXI4-Lite Struct Fields

#### `axi4l_req_t` — Master → DUT

| Field      | Width          | Description                           |
| ---------- | -------------- | ------------------------------------- |
| `aw.addr`  | `ADDR_WIDTH`   | Write address                         |
| `aw.prot`  | 3              | Write protection attributes           |
| `aw_valid` | 1              | Write address valid                   |
| `w.data`   | `DATA_WIDTH`   | Write data                            |
| `w.strb`   | `DATA_WIDTH/8` | Byte write strobes                    |
| `w_valid`  | 1              | Write data valid                      |
| `b_ready`  | 1              | Master ready to accept write response |
| `ar.addr`  | `ADDR_WIDTH`   | Read address                          |
| `ar.prot`  | 3              | Read protection attributes            |
| `ar_valid` | 1              | Read address valid                    |
| `r_ready`  | 1              | Master ready to accept read data      |

#### `axi4l_rsp_t` — DUT → Master

| Field      | Width        | Description                                   |
| ---------- | ------------ | --------------------------------------------- |
| `aw_ready` | 1            | DUT ready to accept write address             |
| `w_ready`  | 1            | DUT ready to accept write data                |
| `b.resp`   | 2            | Write response (`2'b00`=OKAY, `2'b10`=SLVERR) |
| `b_valid`  | 1            | Write response valid                          |
| `ar_ready` | 1            | DUT ready to accept read address              |
| `r.data`   | `DATA_WIDTH` | Read data                                     |
| `r.resp`   | 2            | Read response (`2'b00`=OKAY, `2'b10`=SLVERR)  |
| `r_valid`  | 1            | Read data valid                               |

### Parameter Definitions

| Parameter    | Description                            | Default |
| ------------ | -------------------------------------- | ------- |
| `ADDR_WIDTH` | Width of AXI address bus in bits       | 32      |
| `DATA_WIDTH` | Width of AXI data bus in bits          | 64      |
| `DEPTH`      | Memory locations (`2^ADDR_WIDTH`)      | —       |
| `BYTE_LANES` | Byte strobes per word (`DATA_WIDTH/8`) | 8       |

#### Assumptions

- `DATA_WIDTH` is a multiple of 8.
- All per-channel FIFOs have depth 4 (`FIFO_SIZE=2`, so `2^2 = 4` entries).
- FIFOs are configured with `ALLOW_FALLTHROUGH=0` (registered outputs only).
- The `axi4l_mem_ctrlr` is purely combinational — no internal state.
- Reset is asynchronous, active-low (`arst_ni`).

## Functional Description

### Overview

`axi4l_mem` is a fully registered AXI4-Lite slave memory. Each of the five AXI4-Lite channels (AW, W, B, AR, R) passes through a depth-4 FIFO before reaching the internal controller, decoupling the master from back-pressure. An `axi4l_mem_ctrlr` instance arbitrates access and drives a `dual_port_mem` backend.

### Write Path

1. Master presents AW and W beats; each is independently enqueued into its FIFO.
2. The controller dequeues from both FIFOs simultaneously when `aw_valid & w_valid & b_ready`.
3. If `aw.prot[1:0] == 2'b00` (unprivileged non-secure): `wenable` is asserted, OKAY is returned.
4. Otherwise: write is suppressed, SLVERR is returned.
5. The write response is enqueued into the B FIFO and forwarded once the master asserts `b_ready`.

### Read Path

1. Master presents an AR beat; it is enqueued into the AR FIFO.
2. The controller dequeues the AR beat when `r_ready` is high (data channel is free).
3. `dual_port_mem` returns read data combinationally in the same cycle.
4. If `ar.prot[1:0] == 2'b00`: read data is forwarded with OKAY.
5. Otherwise: zeroed data is returned with SLVERR.
6. The read response is enqueued into the R FIFO and forwarded once the master asserts `r_ready`.

### Protection Policy

| `prot[1:0]` | Access Type              | Result                                       |
| ----------- | ------------------------ | -------------------------------------------- |
| `2'b00`     | Unprivileged, Non-secure | OKAY — write permitted or read data returned |
| Any other   | Privileged or Secure     | SLVERR — write suppressed, read data zeroed  |

### Key Functional Capabilities

- Fully registered AXI4-Lite slave (all channel outputs registered via FIFOs)
- Independent acceptance of AW and W channel beats
- Per-channel back-pressure isolation via depth-4 FIFOs
- Byte-granularity write masking via `wstrb`
- Dual-port memory backend (simultaneous read and write supported)
- Asynchronous reset via active-low `arst_ni`

## Test Environment

The following figure illustrates the testbench environment for `axi4l_mem`. The DUT is instantiated with its AXI4-Lite interface connected to an `axi4l_driver` and `axi4l_monitor`. The testbench top has different tasks as individual sequences. All the response observed by the monitor is sent to a central scoreboard for checking the expected response.

![alt text](axi4l_mem_tb_env.svg)

### Component Descriptions

- **DUT (`axi4l_mem`)**: The AXI4-Lite memory peripheral under test.
- **Interface (`axi4l_if`)**: A SystemVerilog interface encapsulating AXI4-Lite signals, used for connecting the driver and monitor to the DUT and performing signal level operations.
- **Driver (`axi4l_driver`)**: Generates AXI4-Lite transactions (AW, W, AR) based on test sequences and commands the interface to drives them to the DUT.
- **Monitor (`axi4l_monitor`)**: Observes AXI4-Lite signals from the DUT through the interface, reconstructs transactions, and sends them to the scoreboard.
- **Scoreboard**: Maintains expected vs. actual responses, checks for correctness, and tracks coverage.

## Verification Methodology

The testbench will be implement the previously prepared AXI 4 Lite VIP (Verification Intellectual Property) in a structured, non-UVM style. The test sequences will be implemented as individual tasks within the testbench top module, allowing for easy expansion and reuse. The driver will provide methods for generating various AXI4-Lite transactions, while the monitor will capture and record responses for analysis through the scoreboard.

**However, others tests such as the reset behavior, back pressure scenarios and independent AW-W will still be manually tested on the testbench top as the VIP is not yet advanced enough to handle them internally.**

## Test Cases

### TC0 – Reset Behavior
<TODO Motasim>

#### Goal
Check all the critical output are in known state. Also check the output ready are low during reset and high after reset.

#### Description
1. Apply asynchronous active-low reset (`arst_ni=0`) and keep asserted for at least 5 clock cycles.
2. During reset, sample AXI4-Lite ready/valid outputs (`aw_ready`, `w_ready`, `b_valid`, `ar_ready`, `r_valid`) from the DUT via monitor.
3. Deassert reset (`arst_ni=1`) and allow 5–10 clock cycles for the DUT to stabilize.
4. Check that no qualifier response (OKAY/SLVERR) is produced during reset and that all FIFOs are cleared to idle.

#### Expectation
- During reset: `aw_ready=0`, `w_ready=0`, `ar_ready=0`, `b_valid=0`, `r_valid=0`.
- After reset release: `aw_ready=1`, `w_ready=1`, `ar_ready=1` (or not held low by back-pressure), FIFOs in known empty state.
- No memory writes or reads should occur until after reset is deasserted.
- Scoreboard should report no unexpected responses in reset window.

### TC1 - Lowest Address Access
<TODO Shuparna>

#### Goal
Test a single byte write read transaction in at Address 0x00000000 using VIP.

#### Description

#### Expectation

### TC2 - Highest Address Access
<TODO Dhruba>

#### Goal
Test a single byte write read transaction in at Address 0xffffffff using VIP. `data_width` alignment will be considered.

#### Description

#### Expectation

### TC3 - Alignment Check
<TODO Siam>

#### Goal
Test a single byte write read transaction in at Address with last two LSB being `2'b00`, `2'b01`, `2'b10` & `2'b11` using VIP. `data_width` alignment will be considered.

#### Description

#### Expectation

### TC4 – Read-After-Write (Same Address)
<TODO Adnan>

#### Goal
Initiate a read request immediately 1 cycle after the write request.

#### Description

#### Expectation

### TC5 – Partial Write (Byte Strobe)
<TODO Motasim>

#### Goal
Test Different Combinations of Write Strobe

#### Description
1. Perform a series of write transactions to a single address with varying `wstrb` patterns (e.g., `8'b00000001`, `8'b00000011`, ..., `8'b11111111`).
2. For each partial-write, read back the same address and compare returned data with expected masked result (unchanged bytes remain from prior state, written bytes updated correctly).
3. Ensure `aw_prot` is set to unprivileged non-secure (`2'b00`) and all transfers are valid.
4. Include mixed ordering by interleaving writes and reads to stress in-flight data paths.

#### Expectation
- Each partial write updates only the byte lanes indicated by `wstrb`.
- Readback returns exactly expected data based on byte-enable mask and previous memory contents.
- `b_resp` is OKAY for each valid partial write.
- No SLVERR for unprivileged non-secure access, and overall coverage of all 16 `wstrb` combinations is exercised.

### TC6 – No-Op Write (All Strobes Deasserted)
<TODO Shuparna>

#### Goal
Test Writes with No Write Strobe asserted.

#### Description

#### Expectation

### TC7 – All Protection Combinations
<TODO Dhruba>

#### Goal
Test Write Read with all combination of the `AXPROT`

#### Description

#### Expectation

### TC8 – AW-Channel Back-Pressure
<TODO Siam>

#### Goal
Check AW gets blocked due to missing W valid or B ready.

#### Description

#### Expectation

### TC9 – W-Channel Back-Pressure
<TODO Adnan>

#### Goal
Check W gets blocked due to missing AW valid or B ready.

#### Description

#### Expectation

### TC10 – AR-Channel Back-Pressure
<TODO Motasim>

#### Goal
Check W gets blocked due to missing R ready.

#### Description
1. Issue a valid read address (`ar_valid=1`) while intentionally deasserting `r_ready=0` on the master side.
2. Keep `r_ready` low for multiple cycles to enforce AR channel back-pressure in the DUT.
3. Track `ar_ready` and `r_valid` signals; ensure `ar_ready` may remain deasserted until `r_ready=1` and response handshake completes.
4. Confirm that the write path is not incorrectly stalled except per AXI4-Lite dependency rules and that write data path remains functional with separate traffic.

#### Expectation
- When `r_ready=0`, `r_valid` should not be accepted (no `r_ready & r_valid` handshake), and `ar_ready` may deassert if the R FIFO is full.
- Once `r_ready=1`, the pending read response is delivered and `r_valid` handshake occurs.
- No deadlock: unrelated AW/W/B channels continue to make forward progress through FIFO isolation.
- Scoreboard verifies read data and response status are still OKAY for unprotected reads.

### TC11 – AW and W Channel Independent Acceptance
<TODO Shuparna>

#### Goal
Send W before and after AW.

#### Description

#### Expectation

### TC12 – Simultaneous Read and Write (Same Addresses)
<TODO Dhruba>

#### Goal
Simultaneous Read and Write (Same Addresses)

#### Description

#### Expectation

### TC13 – Simultaneous Read and Write (Different Addresses)
<TODO Siam>

#### Goal
Simultaneous Read and Write (Different Addresses)

#### Description

#### Expectation

### TC14 – Back-to-Back Write Transactions
<TODO Adnan>

#### Goal
Test back-to-back AW, W, and B without any dead cycles.

#### Description

#### Expectation

### TC15 – Back-to-Back Read Transactions
<TODO Motasim>

#### Goal
Test back-to-back AR, and R without any dead cycles.

#### Description
1. Drive a sequence of back-to-back read address requests (`AR` channel) with `ar_valid=1` each cycle and `ar_addr` incrementing.
2. Keep `r_ready=1` continuously to accept read responses as soon as they are available.
3. Verify that each issued read corresponds to one ordered read response with correct data and response code.
4. Repeat for at least 8 consecutive read addresses to exercise FIFO depth and path throughput.

#### Expectation
- DUT accepts back-to-back AR requests up to FIFO capacity (`ar_ready` high for consecutive cycles until full).
- Each read response returns OKAY and correct data, in the same order as requests.
- No dead cycles in the response path while `r_ready` is asserted.
- Scoreboard reports expected values for all reads and no SLVERR for normal accesses.

### TC16 – Random Stress Test
<TODO Shuparna>

#### Goal
Last simulation with random delays.

#### Description

#### Expectation

## Coverage Goals

| Coverage Point                                 | Target              |
| ---------------------------------------------- | ------------------- |
| All `prot[2:0]` values exercised for writes    | 100%                |
| All `prot[2:0]` values exercised for reads     | 100%                |
| All `wstrb` byte-lane combinations             | All 16 values hit   |
| AW before W ordering                           | ≥ 50 transactions   |
| W before AW ordering                           | ≥ 50 transactions   |
| AW-channel back-pressure                       | ≥ 20 transactions   |
| W-channel back-pressure                        | ≥ 20 transactions   |
| AR-channel back-pressure                       | ≥ 20 transactions   |
| Simultaneous read/write                        | ≥ 10 transactions   |
| SLVERR write suppression verified by read-back | ≥ 10 per prot value |
