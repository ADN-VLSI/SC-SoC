# AXI4-Lite Memory Peripheral

## Overview

`axi4l_mem` is a fully registered **AXI4-Lite slave memory peripheral**. Each of the five AXI4-Lite channels (AW, W, B, AR, R) is decoupled from the internal logic through a small synchronous FIFO, providing registered outputs on every port and isolating the master from back-pressure. An `axi4l_mem_ctrlr` instance arbitrates read/write requests and drives a `dual_port_mem` instance that holds the actual storage.

---

## Key Features

- Fully registered: every AXI4-Lite channel passes through a depth-4 FIFO before reaching the controller
- Decoupled channels: the master is isolated from memory back-pressure on all five channels
- Protection-bit access control (via `axi4l_mem_ctrlr`): unprivileged non-secure accesses (`prot[1:0] == 2'b00`) return **OKAY**; all others return **SLVERR** with write suppression and zeroed read data
- Dual-port memory backend: separate write and read ports allow simultaneous access without structural hazards
- Synchronous reset via active-low `arst_ni`

---

## Parameters

| Name           | Type   | Default                     | Description                                     |
| -------------- | ------ | --------------------------- | ----------------------------------------------- |
| `axi4l_req_t`  | type   | `defaults_pkg::axi4l_req_t` | AXI4-Lite request struct type (packed)          |
| `axi4l_rsp_t`  | type   | `defaults_pkg::axi4l_rsp_t` | AXI4-Lite response struct type (packed)         |
| `ADDR_WIDTH`   | int    | 32                          | Width of the AXI address bus in bits            |
| `DATA_WIDTH`   | int    | 64                          | Width of the AXI data bus in bits (must be multiple of 8) |

---

## Ports

### Global Signals

| Name      | Direction | Width | Description                     |
| --------- | --------- | ----- | ------------------------------- |
| `arst_ni` | input     | 1     | Asynchronous reset, active-low  |
| `clk_i`   | input     | 1     | System clock                    |

### AXI4-Lite Interface

| Name          | Direction | Type          | Description                          |
| ------------- | --------- | ------------- | ------------------------------------ |
| `axi4l_req_i` | input     | `axi4l_req_t` | AXI4-Lite request bundle from master |
| `axi4l_rsp_o` | output    | `axi4l_rsp_t` | AXI4-Lite response bundle to master  |

---

## Architecture

The `axi4l_mem` module consists of three main components:
1. **Five FIFOs**: one for each AXI4-Lite channel, buffering requests and responses between the master and the controller
2. **`axi4l_mem_ctrlr`**: a combinational controller that arbitr
ates access to the memory based on incoming requests and generates appropriate responses
3. **`dual_port_mem`**: a dual-port memory block that serves as the storage backend, allowing simultaneous read and write access without structural hazards

<img src="./axi4l_mem_arch.svg">

### Submodule Instances

| Instance     | Module            | Description                                                         |
| ------------ | ----------------- | ------------------------------------------------------------------- |
| `aw_fifo`    | `fifo`            | Buffers incoming write-address beats `{addr[ADDR_WIDTH-1:0], prot[2:0]}` |
| `w_fifo`     | `fifo`            | Buffers incoming write-data beats `{data[DATA_WIDTH-1:0], strb[DATA_WIDTH/8-1:0]}` |
| `b_fifo`     | `fifo`            | Buffers outgoing write-response beats `{resp[1:0]}`                 |
| `ar_fifo`    | `fifo`            | Buffers incoming read-address beats `{addr[ADDR_WIDTH-1:0], prot[2:0]}`  |
| `r_fifo`     | `fifo`            | Buffers outgoing read-data beats `{data[DATA_WIDTH-1:0], resp[1:0]}` |
| `ctrlr_inst` | `axi4l_mem_ctrlr` | Arbitrates write/read requests and generates AXI responses          |
| `mem_inst`   | `dual_port_mem`   | Dual-port storage backing the peripheral                            |

### FIFO Configuration

All five channel FIFOs share the same configuration:

| Parameter          | Value | Notes                                          |
| ------------------ | ----- | ---------------------------------------------- |
| `FIFO_SIZE`        | 2     | Depth = 2² = 4 entries                         |
| `ALLOW_FALLTHROUGH`| 0     | Registered outputs only — no combinational path |

FIFO data widths:

| FIFO       | `DATA_WIDTH` expression        | Example (ADDR=32, DATA=64) |
| ---------- | ------------------------------ | -------------------------- |
| `aw_fifo`  | `ADDR_WIDTH + 3`               | 35 bits                    |
| `w_fifo`   | `DATA_WIDTH + DATA_WIDTH/8`    | 72 bits                    |
| `b_fifo`   | `2`                            | 2 bits                     |
| `ar_fifo`  | `ADDR_WIDTH + 3`               | 35 bits                    |
| `r_fifo`   | `DATA_WIDTH + 2`               | 66 bits                    |

---

## Functional Description

### Write Path

1. The master presents AW and W channel beats which are independently enqueued into `aw_fifo` and `w_fifo`.
2. `axi4l_mem_ctrlr` dequeues from both FIFOs simultaneously when a write transaction can complete in a single cycle (`aw_valid & w_valid & b_ready`).
3. The controller checks `aw.prot[1:0]`: if `2'b00` (unprivileged non-secure), it drives `wenable_o` high and returns **OKAY**; otherwise `wenable_o` is suppressed and **SLVERR** is returned.
4. The write response is pushed into `b_fifo` and forwarded to the master when it asserts `b_ready`.

### Read Path

1. The master presents an AR channel beat which is enqueued into `ar_fifo`.
2. `axi4l_mem_ctrlr` accepts a read address when the read-data channel is free (`ar_ready = r_ready`).
3. `dual_port_mem` returns read data combinationally in the same cycle the address is presented.
4. The controller checks `ar.prot[1:0]`: if `2'b00`, it forwards `rdata_i` to the R channel with an **OKAY** response; otherwise zeroed data and **SLVERR** are returned.
5. The read response and data are pushed into `r_fifo` and forwarded to the master when it asserts `r_ready`.

### Protection Policy

Both paths enforce the same rule using `prot[1:0]`:

| `prot[1:0]` | Privilege     | Security   | Result                                               |
| ----------- | ------------- | ---------- | ---------------------------------------------------- |
| `2'b00`     | Unprivileged  | Non-secure | **OKAY** — access permitted, data read or written    |
| Any other   | Privileged or Secure | —   | **SLVERR** — write suppressed, read data zeroed      |

---

## Usage Example

```systemverilog
axi4l_mem #(
    .ADDR_WIDTH (32),
    .DATA_WIDTH (64)
) u_axi4l_mem (
    .arst_ni      (arst_n),
    .clk_i        (clk),
    .axi4l_req_i  (axi4l_req),
    .axi4l_rsp_o  (axi4l_rsp)
);
```
