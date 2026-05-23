# AXI4-Lite Memory Controller

## Overview

`axi4l_mem_ctrlr` is a **purely combinational** AXI4-Lite memory controller. It performs single-cycle write and read transactions with **no internal state** — there are no registers, FIFOs, or outstanding-transaction tracking inside the module.

---

## Block Diagram

<img src="./axi4l_mem_ctrlr.svg">

---

## Key Features

- Fully combinational — zero-latency, no clock required
- Single-cycle write transactions (AW + W + B channels all handshake in one cycle)
- Single-cycle read transactions (AR + R channels handshake in one cycle)
- Protection-bit access control: accesses with `prot[1:0] == 2'b00` return **OKAY** unless the memory interface reports an error; all other cases return **SLVERR**

---

## Parameters

| Name         | Type          | Default                      | Description                                        |
| ------------ | ------------- | ---------------------------- | -------------------------------------------------- |
| `axi4l_req_t` | type         | `defaults_pkg::axi4l_req_t`  | AXI4-Lite request struct type (packed)             |
| `axi4l_rsp_t` | type         | `defaults_pkg::axi4l_rsp_t`  | AXI4-Lite response struct type (packed)            |
| `ADDR_WIDTH`  | int           | 32                           | Width of the address bus in bits                   |
| `DATA_WIDTH`  | int           | 32                           | Width of the data bus in bits                   |

---

## Ports

### AXI4-Lite Interface

| Name          | Direction | Type          | Description                         |
| ------------- | --------- | ------------- | ----------------------------------- |
| `axi4l_req_i` | input     | `axi4l_req_t` | AXI4-Lite request bundle from master |
| `axi4l_rsp_o` | output    | `axi4l_rsp_t` | AXI4-Lite response bundle to master  |

### Memory Write Interface

| Name        | Direction | Width            | Description                                          |
| ----------- | --------- | ---------------- | ---------------------------------------------------- |
| `waddr_o`   | output    | `ADDR_WIDTH`     | Write address to memory                              |
| `wnsecure_o`| output    | 1                | Mirrors `aw.prot[1]` onto the memory interface       |
| `wdata_o`   | output    | `DATA_WIDTH`     | Write data to memory                                 |
| `wstrb_o`   | output    | `DATA_WIDTH/8`   | Byte write strobe (1 bit per byte)                   |
| `wenable_o` | output    | 1                | Write enable; asserted only on permitted transactions |
| `werror_i`  | input     | 1                | Memory-side write error; returns `SLVERR` when high  |

### Memory Read Interface

| Name      | Direction | Width        | Description              |
| --------- | --------- | ------------ | ------------------------ |
| `raddr_o` | output    | `ADDR_WIDTH` | Read address to memory   |
| `rnsecure_o`| output  | 1            | Mirrors `ar.prot[1]` onto the memory interface |
| `rdata_i` | input     | `DATA_WIDTH` | Read data from memory    |
| `rerror_i`| input     | 1            | Memory-side read error; returns `SLVERR` when high |

---

## AXI4-Lite Struct Fields

The default types (from `defaults_pkg`, instantiated with `ADDR_WIDTH=32`, `DATA_WIDTH=64`) expose the following fields.

### `axi4l_req_t` — Request (master → controller)

| Field       | Width            | Description                                      |
| ----------- | ---------------- | ------------------------------------------------ |
| `aw.addr`   | `ADDR_WIDTH`     | Write address                                    |
| `aw.prot`   | 3                | Write protection attributes                      |
| `aw_valid`  | 1                | Write address valid                              |
| `w.data`    | `DATA_WIDTH`     | Write data                                       |
| `w.strb`    | `DATA_WIDTH/8`   | Write byte strobes                               |
| `w_valid`   | 1                | Write data valid                                 |
| `b_ready`   | 1                | Master ready to accept write response            |
| `ar.addr`   | `ADDR_WIDTH`     | Read address                                     |
| `ar.prot`   | 3                | Read protection attributes                       |
| `ar_valid`  | 1                | Read address valid                               |
| `r_ready`   | 1                | Master ready to accept read data                 |

### `axi4l_rsp_t` — Response (controller → master)

| Field      | Width        | Description                                |
| ---------- | ------------ | ------------------------------------------ |
| `aw_ready` | 1            | Controller ready to accept write address   |
| `w_ready`  | 1            | Controller ready to accept write data      |
| `b.resp`   | 2            | Write response (`2'b00`=OKAY, `2'b11`=SLVERR) |
| `b_valid`  | 1            | Write response valid                       |
| `ar_ready` | 1            | Controller ready to accept read address    |
| `r.data`   | `DATA_WIDTH` | Read data                                  |
| `r.resp`   | 2            | Read response (`2'b00`=OKAY, `2'b11`=SLVERR)  |
| `r_valid`  | 1            | Read data valid                            |

---

## Functional Description

### Write Path

A write transaction completes in a **single cycle** when all three conditions are met simultaneously:

```
do_write = aw_valid & w_valid & b_ready
```

| Signal        | Behaviour                                                      |
| ------------- | -------------------------------------------------------------- |
| `aw_ready`    | Driven by `do_write`                                           |
| `w_ready`     | Driven by `do_write`                                           |
| `b_valid`     | Driven by `do_write`                                           |
| `b.resp`      | `OKAY (2'b00)` when `aw.prot[1:0] == 2'b00` and `werror_i == 0`, else `SLVERR (2'b11)` |
| `wenable_o`   | Asserted only when `do_write` is high **and** `aw.prot[1:0] == 2'b00` |
| `waddr_o`     | Combinationally wired from `aw.addr`                           |
| `wnsecure_o`  | Combinationally wired from `aw.prot[1]`                        |
| `wdata_o`     | Combinationally wired from `w.data`                            |
| `wstrb_o`     | Combinationally wired from `w.strb`                            |

> **Note:** Holding `aw_ready` and `w_ready` low until `b_ready` is asserted prevents the controller from consuming address/data when it cannot immediately issue the response.

### Read Path

A read transaction completes in a **single cycle** whenever the master is ready to receive data:

```
ar_ready = r_ready
```

| Signal     | Behaviour                                                      |
| ---------- | -------------------------------------------------------------- |
| `ar_ready` | Driven directly by `r_ready`                                   |
| `r_valid`  | Driven directly by `ar_valid`                                  |
| `r.resp`   | `OKAY (2'b00)` when `ar.prot[1:0] == 2'b00` and `rerror_i == 0`, else `SLVERR (2'b11)` |
| `r.data`   | Forwarded from `rdata_i` on OKAY; `'0` on SLVERR (prevents data leakage) |
| `raddr_o`  | Combinationally wired from `ar.addr`                           |
| `rnsecure_o`| Combinationally wired from `ar.prot[1]`                       |

> **Note:** `r_valid` is asserted the same cycle as `ar_valid`, relying on the connected memory to present valid read data within the same clock cycle.

### Protection Policy

Both paths enforce the same rule using `prot[1:0]`, and also convert memory-side errors into AXI `SLVERR` responses:

| Condition | Result |
| --------- | ------ |
| `prot[1:0] == 2'b00` and memory error input low | **OKAY** — access permitted |
| Any other case | **SLVERR** — access denied or downstream memory reported an error |

---

## Timing Diagram

### Write Transaction (Permitted)

```
          ┌───┐   ┌───┐
aw_valid  │   │   │   │
       ───┘   └───┘   └───
          ┌───┐   ┌───┐
w_valid   │   │   │   │
       ───┘   └───┘   └───
          ┌───┐   ┌───┐
b_ready   │   │   │   │
       ───┘   └───┘   └───
              ┌───┐
do_write      │   │
       ───────┘   └───────
              ┌───┐
wenable_o     │   │         (OKAY access)
       ───────┘   └───────
```

### Read Transaction (Permitted)

```
           ┌───┐
ar_valid   │   │
        ───┘   └───────
           ┌───┐
r_ready    │   │
        ───┘   └───────
           ┌───┐
ar_ready   │   │           = r_ready
        ───┘   └───────
           ┌───┐
r_valid    │   │           = ar_valid
        ───┘   └───────
         [   rdata_i   ]   forwarded to r.data same cycle
```

---

## Usage Example

```systemverilog
axi4l_mem_ctrlr #(
    .ADDR_WIDTH (32),
    .DATA_WIDTH (64)
) u_axi4l_mem_ctrlr (
    .axi4l_req_i (axi4l_req),
    .axi4l_rsp_o (axi4l_rsp),
    .waddr_o     (mem_waddr),
    .wnsecure_o  (mem_wnsecure),
    .wdata_o     (mem_wdata),
    .wstrb_o     (mem_wstrb),
    .wenable_o   (mem_we),
    .werror_i    (mem_werror),
    .raddr_o     (mem_raddr),
    .rnsecure_o  (mem_rnsecure),
    .rdata_i     (mem_rdata),
    .rerror_i    (mem_rerror)
);
```
