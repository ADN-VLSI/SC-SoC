# AXI‑Lite UART Register Interface Documentation



## Overview
The AXI‑Lite UART register interface provides memory‑mapped control and status registers for the UART peripheral.  
Software uses these registers to configure baud rate and frame format, monitor FIFO status, enqueue transmit/receive requests, and manage interrupts.  
The interface is accessed via AXI‑Lite read and write transactions.

Registers are categorized as:
- **RW (Read/Write):** Software can read and update values.
- **RO (Read‑Only):** Updated only by hardware; software can read but not modify.
- **WO (Write‑Only):** Software writes values; reading is not meaningful.

---
![AXI4-Lite UART RTL Diagram](axi4l_uart_regif.svg)
- - -
## Register Map

For Full register Map See Document  [OPEN uart_reg.md](uart_reg.md)

---

## Register Details

For Full register Details See Document [OPEN uart_reg.md](uart_reg.md)

---

## Reset Behavior
- On reset, RW registers load their documented defaults.  
- FIFOs are cleared (`tx_empty = 1`, `rx_empty = 1`).  
- Interrupts are disabled (`UART_INT = 0x00000000`).  

---

## Arbitration Mechanism
- **TXR/RXR:** enqueue master IDs into request FIFOs.  
- **TXGP/RXGP:** non‑consuming peek at current grant.  
- **TXG/RXG:** consuming read that advances the grant FIFO.  
- Ensures fair multi‑master access to TX and RX paths.  

---

## Interrupt Setting
- Hardware events (FIFO empty/full, parity error) are ANDed with `UART_INT` bits.  
- If enabled, the UART raises an interrupt line.  
- Software ISR reads `UART_STAT` to identify the source and clears the condition by servicing FIFO or error.  

---

## Software Usage Example
1. Configure baud rate and frame format via `UART_CFG`.  
2. Enable TX/RX via `UART_CTRL`.  
3. Write data to `UART_TXD` to transmit.  
4. Read data from `UART_RXD` when available.  
5. Use `UART_STAT` to monitor FIFO state.  
6. Enable interrupts in `UART_INT` for event‑driven operation.  

---

## AXI‑Lite Interface Notes
- **Write transactions:** update RW and WO registers.  
- **Read transactions:** return RW and RO register values.  
- **Address decoding:** offsets are byte‑aligned (0x000, 0x004, etc.).  
- **Data width:** 32‑bit registers, with unused bits reserved.  

---

## Reserved Bits
- Must be written as `0`.  
- Should be ignored on read.  
- Reserved for future expansion.  

---



