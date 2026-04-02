# CDC FIFO

### Overview

A CDC FIFO (Clock Domain Crossing First-In-First-Out) is a mechanism that safely transfers data between two asynchronous clock domains using an explicit **request-acknowledge (req/ack)** signaling protocol. Unlike Gray-code pointer-based CDC FIFOs, the handshake method requires both the write domain and the read domain to mutually agree before each data transfer takes place. 

---

### Key Features

**Asynchronous Clock Crossing**: Safely handles data transfers between independent wr_clk and rd_clk domains.
**Dual-Flow Control**: Implements a full Valid/Ready handshake on both interfaces to ensure zero data loss.
**Active-Low Ready Logic**: Specifically designed to interface with systems using rd_ready = 0 as the "Ready" state.
**Metastability Guard**: Utilizes 2-Stage FF Synchronizers for all control signals moving across clock boundaries.
**Single-Bit Change Safety**: Employs Gray Code pointer conversion to ensure robust synchronization of memory addresses.
**Atomic Data Latching**: Latches wr_data into a stable internal register, holding it constant throughout the transfer cycle.
**Full/Empty Logic**: Uses an additional MSB bit on pointers to accurately distinguish between a completely full and completely empty buffer.
**Real-Time Occupancy**: Provides wr_count and rd_count outputs for immediate feedback on FIFO fill levels.


---

### Parameters

| PARAMETER      | TYPE | DEFAULT            | DESCRIPTION
| ---------------|------|--------------------|-----------------------------------------------------------------------------------|
| `DATA_WIDTH `  | int  | 32                 | Defines the bit-width of the data bus (wr_data and rd_data).                      |
| `FIFO_DEPTH `  | int  | 16                 | The maximum number of data elements the FIFO can store.                           |
| `ADDR_WIDTH `  | int  | $clog2(FIFO_DEPTH) | The number of bits required for the memory address.                               |
| `COUNT_WIDTH`  | int  | ADDR_WIDTH+1       | The width of the wr_count and rd_count buses.                                     |
| `SYNC_STAGES`  | int  | 2                  | The number of flip-flop stages used in the synchronizers to prevent metastability.|

---

### Ports

| PORT NAME    | DIR | DOMAIN | DESCRIPTION
| ------------ |-----|--------|----------------------------------------------------------------------------------------------------|
| `arst_ni `   | IN  | Global | Global Reset: Asynchronous, Active-Low (0 = Reset). Resets all internal pointers and control logic.|
| `wr_clk  `   | IN  | Source | Write Clock: The clock signal for the source (write) side domain.                                  |
| `wr_data `   | IN  | Source | Write Data: The data bus carries information to be stored in the FIFO memory.                      |
| `wr_valid`   | IN  | Source | Write Valid: High (1) indicates that the source has valid data ready to be written.                |
| `wr_ready`   | OUT | Source | Write Ready: High (1) indicates the FIFO is NOT FULL and can accept new data.                      |
| `wr_count`   | OUT | Source | Write Count: Indicates the number of elements currently stored in the FIFO.                        |
| `rd_clk  `   | IN  | Dest   | Read Clock: The clock signal for the destination (read) side domain.                               |
| `rd_ready`   | IN  | Dest   | Read Ready: Active-Low (0 = Ready). Indicates the destination is ready to consume data.            |
| `rd_valid`   | OUT | Dest   | Read Valid: High (1) indicates the FIFO is NOT EMPTY and data is available to be read.             |
| `rd_data `   |OUT  | Dest   | Read Data: The data bus carries the information being retrieved from the FIFO.                     |
| `rd_count`   |OUT  | Dest   | Read Count: Indicates the number of elements available to be read.                                 |

---

### Block Diagram

<img src="./cdc_fifo.drawio.svg">

### Functional Description

**Asynchronous active-low reset**: This clears all internal registers, pointers, and handshake logic to a known initial state.

**Data Input**: When wr_valid = 1 (enough data to send) and wr_ready = 1 (FIFO free can take data), then wr_data is written to the Memory.

**Binary Write Pointer**: After successfully writing the data into the memory, the wr_ptr_bin (binary write pointer) increases by one. It works as a memory address.

**Binary to Gray Conversion**: Before sending the data to the read side, the binary pointer is converted into the gray code. In binary, when transitioning from 011 to 100, all three bits change simultaneously, which can cause incorrect data during synchronization. In Gray code, only one bit changes at a time, making it much safer.

**2-Stage Synchronizer**: Data is transferred from the write domain to the read domain using a 2-flip-flop (2-FF) synchronizer to mitigate metastability. Likewise, data from the read domain is transferred back to the write domain using the same 2-FF synchronizer.

**Empty Check**: Read side rd_ptr_bin compare with the write side wr_ptr_bin.  If rd_ptr_bin = = wr_ptr_bin then rd_valid (FIFO Empty).

**Data Output**: If FIFO is not empty ( rd_valid=1) and the read side is ready to take data (rd_ready=0), then data comes to memory to r_data.

**Binary Read Pointer**: Following each read operation, the read pointer (rd_ptr_bin) is incremented by one, converted into Gray code, and then transmitted back to the write side.

**Full/Empty Logic**:
- **Empty**: when wr_ptr = = rd_ptr FIFO Empty
- **Full**: when wr_ptr = = rd_ptr but wr_ptr_msb !=  rd_ptr_msb

**Read Write Count**:
- **Write Count**: convert Gray code to Binary, then  rd_ptr – wr_ptr
- **Read Count**: sync_wr_ptr – rd_ptr

