# AXI4-Lite Memory Testbench

---

## 1. Document Information

| Item               | Description                           |
| ------------------ | ------------------------------------- |
| DUT Name           | `axi4l_mem`                           |
| Design Type        | AXI4-Lite slave memory peripheral     |
| Verification Level | Module-level                          |
| Language           | SystemVerilog                         |
| Verification Style | Structured (Non-UVM, scalable to UVM) |

---

## 2. Target DUT Description

### 2.1 RTL Interface

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

### 2.2 AXI4-Lite Struct Fields

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

### 2.3 Parameter Definitions

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

---

## 3. Functional Description

### 3.1 Overview

`axi4l_mem` is a fully registered AXI4-Lite slave memory. Each of the five AXI4-Lite channels (AW, W, B, AR, R) passes through a depth-4 FIFO before reaching the internal controller, decoupling the master from back-pressure. An `axi4l_mem_ctrlr` instance arbitrates access and drives a `dual_port_mem` backend.

---

### 3.2 Write Path

1. Master presents AW and W beats; each is independently enqueued into its FIFO.
2. The controller dequeues from both FIFOs simultaneously when `aw_valid & w_valid & b_ready`.
3. If `aw.prot[1:0] == 2'b00` (unprivileged non-secure): `wenable` is asserted, OKAY is returned.
4. Otherwise: write is suppressed, SLVERR is returned.
5. The write response is enqueued into the B FIFO and forwarded once the master asserts `b_ready`.

---

### 3.3 Read Path

1. Master presents an AR beat; it is enqueued into the AR FIFO.
2. The controller dequeues the AR beat when `r_ready` is high (data channel is free).
3. `dual_port_mem` returns read data combinationally in the same cycle.
4. If `ar.prot[1:0] == 2'b00`: read data is forwarded with OKAY.
5. Otherwise: zeroed data is returned with SLVERR.
6. The read response is enqueued into the R FIFO and forwarded once the master asserts `r_ready`.

---

### 3.4 Protection Policy

| `prot[1:0]` | Access Type              | Result                                       |
| ----------- | ------------------------ | -------------------------------------------- |
| `2'b00`     | Unprivileged, Non-secure | OKAY — write permitted or read data returned |
| Any other   | Privileged or Secure     | SLVERR — write suppressed, read data zeroed  |

---

### 3.5 Key Functional Capabilities

- Fully registered AXI4-Lite slave (all channel outputs registered via FIFOs)
- Independent acceptance of AW and W channel beats
- Per-channel back-pressure isolation via depth-4 FIFOs
- Byte-granularity write masking via `wstrb`
- Dual-port memory backend (simultaneous read and write supported)
- Synchronous reset via active-low `arst_ni`

---

## 8. Test Cases

- TC0 – Reset Behavior
- TC1 - Lowest Address Access
- TC2 - Highest Address Access
- TC3 - Alignment Check
- TC4 – Basic Write (Full Word)
- TC5 – Basic Read
- TC6 – Read-After-Write (Same Address)
- TC7 – Partial Write (Byte Strobe)
- TC8 – No-Op Write (All Strobes Deasserted)
- TC9 – Protected Write (SLVERR, Write Suppressed)
- TC10 – Protected Read (SLVERR, Zeroed Data)
- TC11 – All Protection Combinations
- TC12 – AW-Channel Back-Pressure
- TC13 – W-Channel Back-Pressure
- TC14 – AR-Channel Back-Pressure
- TC15 – AW and W Channel Independent Acceptance
- TC16 – Simultaneous Read and Write (Different Addresses)
- TC17 – Back-to-Back Write Transactions
- TC18 – Back-to-Back Read Transactions
- TC19 – Single Byte Write
- TC20 – Random Stress Test

## 9. Coverage Goals

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
