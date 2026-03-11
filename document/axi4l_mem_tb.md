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

#### Expectation

### TC1 - Lowest Address Access
<TODO Shuparna>

#### Goal
Test a single byte write read transaction in at Address 0x00000000 using VIP.

#### Description
The AXI4-Lite driver writes `0xA5` to address `0x00000000` with only the first byte strobe (`wstrb[0]`) asserted while all other byte lanes are inactive. After waiting for `b_valid` and confirming that `b_resp = OKAY`, a read request is issued to the same address immediately. The monitor captures `r.data` once `r_valid` is high.

#### Expectation
- `b_valid` asserts once with `b_resp = OKAY`.  
- Read data returns `0xA5` in byte lane 0; other lanes remain unchanged (or zero if memory initialized to zero).  


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

#### Expectation

### TC6 – No-Op Write (All Strobes Deasserted)
<TODO Shuparna>

#### Goal
Test Writes with No Write Strobe asserted.

#### Description
The driver issues a write to a valid address (e.g., `0x00001000`) with `wstrb = 8'b00000000` (all lanes inactive). After `b_valid` asserts from the DUT, a read from the same address is performed to verify memory content.

#### Expectation
- `b_valid` asserts with `b_resp = OKAY` (write accepted but no data changes).  
- Read returns the previous value at the address (no modifications).  
- Write effectively behaves as a no-op.  


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

#### Expectation

### TC11 – AW and W Channel Independent Acceptance
<TODO Shuparna>

#### Goal
Send W before and after AW.

#### Description
Verify that the DUT correctly handles independent AW and W channel arrivals (W before AW and AW before W).In Scenario 1, the W data beat is sent first while the AW beat is delayed by two cycles. In Scenario 2, the AW address beat is sent first while the W beat is delayed by two cycles. `b_valid` is monitored for both transactions, and memory content is checked to ensure correct writes.

#### Expectation
- DUT holds the W or AW beat in FIFO until its counterpart arrives.  
- No data corruption occurs.  
- `b_valid` asserts correctly after both AW and W are received and processed.  
- Back-pressure is correctly applied if necessary (AW/W ready signals).  


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

#### Expectation

### TC16 – Random Stress Test
<TODO Shuparna>

#### Goal
Last simulation with random delays.

#### Description
The driver generates 50–100 random AXI4-Lite read/write transactions to random addresses. `wstrb`, `prot`, and delays between AW/W/AR submissions are randomized (0–5 cycles), and random `b_ready` and `r_ready` deassertions simulate back-pressure. All responses are captured via the monitor and forwarded to the scoreboard for verification.

#### Expectation
- All read/write responses are correct per AXI4-Lite protocol.  
- No deadlocks occur despite random back-pressure and delayed arrivals.  
- Memory contents match expected results after all transactions.  
- Coverage goals for protection, byte strobes, and back-pressure are achieved.  


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
