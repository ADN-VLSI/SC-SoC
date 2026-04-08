# AXI4-Lite UART Register Interface Documentation

## Author
- Sheikh Shuparna Haque — sheikhshuparna3108@gmail.com  
- Motasim Faiyaz — motasimfaiyaz@gmail.com  
- **Date:** 2026-04-01  
- **Version:** 1.1 (Corrected)

---

## Overview
The AXI-Lite UART register interface (`axi4l_uart_regif`) provides memory-mapped control and status registers for the UART peripheral.

Software uses these registers to:
- Configure baud rate and frame format  
- Monitor FIFO status  
- Enqueue transmit/receive requests  
- Manage interrupts  

The interface is accessed via AXI-Lite read and write transactions.

### Block Diagram
![AXI4-Lite UART RTL Diagram](axi4l_uart_regif.svg)

### Register Types
- **RW (Read/Write):** Software can read and update values  
- **RO (Read-Only):** Updated only by hardware  
- **WO (Write-Only):** Software write-only; read is not meaningful  

---

## Module Ports

```systemverilog
module axi4l_uart_regif (
    input  logic            clk_i,
    input  logic            arst_ni,

    input  uart_axil_req_t  req_i,
    output uart_axil_rsp_t  resp_o,

    output uart_ctrl_reg_t  uart_ctrl_o,
    output uart_cfg_reg_t   uart_cfg_o,
    output uart_stat_reg_t  uart_stat_o,

    output uart_data_t      tx_data_o,
    output logic            tx_data_valid_o,
    input  logic            tx_data_ready_i,

    input  uart_data_t      rx_data_i,
    input  logic            rx_data_valid_i,
    output logic            rx_data_ready_o,

    input  uart_count_t     tx_data_cnt_i,
    input  uart_count_t     rx_data_cnt_i,

    output uart_int_reg_t   uart_int_en_o
);
```

---

## Clock and Reset

| Signal   | Direction | Width | Description                      |
|----------|-----------|-------|----------------------------------|
| `clk_i`  | input     | 1     | System clock                     |
| `arst_ni`| input     | 1     | Active-low asynchronous reset    |

---

## AXI-Lite Slave Interface
- Request and response channels are bundled into:
  - `uart_axil_req_t`
  - `uart_axil_rsp_t`
- Each AXI channel (**AW, W, AR, B, R**) is buffered using FIFOs (`axi4l_fifo`)
- Handshake follows AXI4-Lite protocol semantics

---

## Register Map
The UART register map is defined in:  [uart_reg.md](uart_reg.md)


This file contains:
- Register offsets  
- Access types (RW/RO/WO)  
- Reset values  
- Bit-field descriptions  


---

## Arbitration Mechanism

The interface uses FIFO-based arbitration for fair multi-master access:

- **TXR / RXR (Request):** Enqueue master IDs into request FIFOs  
- **TXGP / RXGP (Grant Peek):** Non-consuming read of current grant  
- **TXG / RXG (Grant Consume):** Dequeue and advance FIFO  

This ensures:
- Fair scheduling  
- No starvation  
- Deterministic access ordering  

---

## Interrupts

- `UART_INT_EN` is a **32-bit register** with 4 active bits:
  - `tx_empty_en`
  - `tx_full_en`
  - `rx_empty_en`
  - `rx_full_en`

### Notes
- Reserved bits must be written as `0`  
- Hardware events are ANDed with enable bits  
- When triggered, an interrupt is generated  

### Software Handling
1. Interrupt occurs  
2. ISR reads `UART_STAT`  
3. Identify source  
4. Clear condition by:
   - Writing to FIFO, or  
   - Reading from FIFO  

---

## Reset Behavior

On reset:

| Register        | Value      |
|----------------|-------------|
| `UART_CTRL`    | 0x00000000  |
| `UART_CFG`     | 0x0003405B  |
| `UART_INT_EN`  | 0x00000000  |

### FIFO Status Flags 

| Signal     | Definition                                      | RTL Expression                           | Notes                                    |
|------------|-------------------------------------------------|------------------------------------------|-------                                   |
| tx_empty   | Asserted (1) when TX FIFO has no entries        | `(tx_data_cnt_i == '0)`                  | Direct comparison of full struct to zero |
| tx_full    | Asserted (1) when TX FIFO is at max depth (512) | `(tx_data_cnt_i.count == 10'd512)`       | Uses `.count` field                      |
| rx_empty   | Asserted (1) when RX FIFO has no entries        | `(rx_data_cnt_i == '0)`                  | Same structure comparison as TX          |
| rx_full    | Asserted (1) when RX FIFO is at max depth (512) | `(rx_data_cnt_i.count == 10'd512)`       | Uses `.count` field                      |
| tx_cnt     | Number of entries in TX FIFO                    | `tx_data_cnt_i.count`                    | Direct mapping                           | 
| rx_cnt     | Number of entries in RX FIFO                    | `rx_data_cnt_i.count`                    | Direct mapping                           |

## Software Usage Example

1. Configure baud rate and frame format via `UART_CFG`  
2. Enable TX/RX using `UART_CTRL`  
3. Write data to `UART_TXD` to transmit  
4. Read data from `UART_RXD` when available  
5. Monitor FIFO state via `UART_STAT`  
6. Enable interrupts in `UART_INT_EN` for event-driven operation  

---

## Notes
- Documentation aligns with:
  - [`axi4l_uart_regif.sv`](../hardware/source//axi4l_uart_regif.sv)
  - [`uart_pkg.sv`](../hardware/include/package/uart_pkg.sv)
- Register-level details are centralized in [uart_reg.md](uart_reg.md)

---
