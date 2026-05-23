# AXI4-Lite to Memory Interface Bridge

## Overview

`axi4l_to_memif` is a **purely combinational** bridge that translates AXI4-Lite master transactions into a flat generic memory interface (`waddr/wdata/wstrb/wenable/werror` and `raddr/rdata/rerror`). It adds a security sideband (`wnsecure_o` / `rnsecure_o`) derived from the AXI protection attribute, and folds memory-side error signals back into AXI slave-error responses.

There are no registers, FIFOs, or outstanding-transaction tracking inside the module.

---

## Block Diagram

```
         ┌─────────────────────────┐
AXI4L ──►│                         ├──► waddr_o / wnsecure_o / wdata_o / wstrb_o / wenable_o
         │   axi4l_to_memif        │◄── werror_i
         │                         │
AXI4L ◄──┤                         ├──► raddr_o / rnsecure_o
         │                         │◄── rdata_i / rerror_i
         └─────────────────────────┘
```

---

## Key Features

- Fully combinational — zero-latency, no clock required
- Single-cycle write transactions (AW + W + B channels all handshake in one cycle)
- Single-cycle read transactions (AR + R channels handshake in one cycle)
- Non-secure sideband: `aw.prot[1]` / `ar.prot[1]` forwarded as `wnsecure_o` / `rnsecure_o`
- Protection-bit access control: accesses with `prot[1:0] == 2'b00` return **OKAY** (unless the memory reports an error); all other cases return **SLVERR**
- Memory-error feedback: `werror_i` / `rerror_i` translate into AXI `SLVERR` responses

---

## Parameters

| Name           | Type  | Default                     | Description                            |
| -------------- | ----- | --------------------------- | -------------------------------------- |
| `axi4l_req_t`  | type  | `defaults_pkg::axi4l_req_t` | AXI4-Lite request struct type (packed) |
| `axi4l_resp_t` | type  | `defaults_pkg::axi4l_resp_t`| AXI4-Lite response struct type (packed)|
| `ADDR_WIDTH`   | int   | 32                          | Width of the address bus in bits       |
| `DATA_WIDTH`   | int   | 32                          | Width of the data bus in bits          |

---

## Ports

### AXI4-Lite Interface

| Name           | Direction | Type           | Description                          |
| -------------- | --------- | -------------- | ------------------------------------ |
| `axi4l_req_i`  | input     | `axi4l_req_t`  | AXI4-Lite request bundle from master |
| `axi4l_resp_o` | output    | `axi4l_resp_t` | AXI4-Lite response bundle to master  |

### Memory Write Interface

| Name          | Direction | Width          | Description                                          |
| ------------- | --------- | -------------- | ---------------------------------------------------- |
| `waddr_o`     | output    | `ADDR_WIDTH`   | Write address                                        |
| `wnsecure_o`  | output    | 1              | Non-secure flag — mirrors `aw.prot[1]`               |
| `wdata_o`     | output    | `DATA_WIDTH`   | Write data                                           |
| `wstrb_o`     | output    | `DATA_WIDTH/8` | Byte write strobe (1 bit per byte lane)              |
| `wenable_o`   | output    | 1              | Write enable; asserted only on permitted accesses    |
| `werror_i`    | input     | 1              | Memory write error; causes AXI `SLVERR` when high   |

### Memory Read Interface

| Name          | Direction | Width        | Description                                         |
| ------------- | --------- | ------------ | --------------------------------------------------- |
| `raddr_o`     | output    | `ADDR_WIDTH` | Read address                                        |
| `rnsecure_o`  | output    | 1            | Non-secure flag — mirrors `ar.prot[1]`              |
| `rdata_i`     | input     | `DATA_WIDTH` | Read data from memory                               |
| `rerror_i`    | input     | 1            | Memory read error; causes AXI `SLVERR` when high   |

---

## Functional Description

### Write Path

A write transaction completes in a **single cycle** when all three conditions are met simultaneously:

```
do_write = aw_valid & w_valid & b_ready
```

| Signal        | Behaviour                                                              |
| ------------- | ---------------------------------------------------------------------- |
| `aw_ready`    | Driven by `do_write`                                                   |
| `w_ready`     | Driven by `do_write`                                                   |
| `b_valid`     | Driven by `do_write`                                                   |
| `b.resp`      | `OKAY (2'b00)` when `aw.prot[1:0] == 2'b00` and `werror_i == 0`, else `SLVERR (2'b11)` |
| `waddr_o`     | Combinationally wired from `aw.addr`                                   |
| `wnsecure_o`  | Combinationally wired from `aw.prot[1]`                                |
| `wdata_o`     | Combinationally wired from `w.data`                                    |
| `wstrb_o`     | Combinationally wired from `w.strb`                                    |
| `wenable_o`   | Asserted when `do_write` is high **and** `aw.prot[1:0] == 2'b00`      |

> **Note:** `wenable_o` is driven solely by the AXI protection check, not by `werror_i`. This ensures the downstream memory still receives the access and can generate the error signal.

### Read Path

A read transaction completes in a **single cycle** whenever the master is ready to receive data:

```
ar_ready = r_ready
```

| Signal        | Behaviour                                                              |
| ------------- | ---------------------------------------------------------------------- |
| `ar_ready`    | Driven directly by `r_ready`                                           |
| `r_valid`     | Driven directly by `ar_valid`                                          |
| `r.resp`      | `OKAY (2'b00)` when `ar.prot[1:0] == 2'b00` and `rerror_i == 0`, else `SLVERR (2'b11)` |
| `r.data`      | Forwarded from `rdata_i` on OKAY; `'0` on SLVERR (prevents data leakage) |
| `raddr_o`     | Combinationally wired from `ar.addr`                                   |
| `rnsecure_o`  | Combinationally wired from `ar.prot[1]`                                |

### Protection Policy

| Condition                                       | Result                                           |
| ----------------------------------------------- | ------------------------------------------------ |
| `prot[1:0] == 2'b00` and memory error input low | **OKAY** — access permitted                      |
| `prot[1:0] != 2'b00`                            | **SLVERR** — access denied; write suppressed, read data zeroed |
| `prot[1:0] == 2'b00` and memory error high      | **SLVERR** — downstream memory reported an error |

---

## Usage Example

```systemverilog
axi4l_to_memif #(
    .ADDR_WIDTH (32),
    .DATA_WIDTH (32)
) u_axi4l_to_memif (
    .axi4l_req_i  (axi4l_req),
    .axi4l_resp_o (axi4l_rsp),

    .waddr_o      (mem_waddr),
    .wnsecure_o   (mem_wnsecure),
    .wdata_o      (mem_wdata),
    .wstrb_o      (mem_wstrb),
    .wenable_o    (mem_wenable),
    .werror_i     (mem_werror),

    .raddr_o      (mem_raddr),
    .rnsecure_o   (mem_rnsecure),
    .rdata_i      (mem_rdata),
    .rerror_i     (mem_rerror)
);
```
