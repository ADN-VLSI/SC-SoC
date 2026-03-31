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

| Offset | Register    | Type | Reset Value | Description                                |
|--------|-------------|------|-------------|--------------------------------------------|
| 0x000  | UART_CTRL   | RW   | 0x00000000  | Control: reset, FIFO flush, TX/RX enable   |
| 0x004  | UART_CFG    | RW   | 0x0003405B  | Configuration: baud rate, frame format     |
| 0x008  | UART_STAT   | RO   | 0x00500000  | Status: FIFO fill levels, empty/full flags |
| 0x010  | UART_TXR    | WO   | –           | TX request ID queue                        |
| 0x014  | UART_TXGP   | RO   | 0x00000000  | TX grant ID peek (non‑consuming)           |
| 0x018  | UART_TXG    | RO   | 0x00000000  | TX grant ID (consuming)                    |
| 0x01C  | UART_TXD    | WO   | –           | TX data byte                               |
| 0x020  | UART_RXR    | WO   | –           | RX request ID queue                        |
| 0x024  | UART_RXGP   | RO   | 0x00000000  | RX grant ID peek (non‑consuming)           |
| 0x028  | UART_RXG    | RO   | 0x00000000  | RX grant ID (consuming)                    |
| 0x02C  | UART_RXD    | RO   | 0x00000000  | RX data byte                               |
| 0x030  | UART_INT    | RW   | 0x00000000  | Interrupt enable bits                      |

---

## Register Details

### UART_CTRL (0x000, RW)
- **Bit 0 – uart_rst:** Software reset.  
- **Bit 1 – tx_fifo_flush:** Clears TX FIFO.  
- **Bit 2 – rx_fifo_flush:** Clears RX FIFO.  
- **Bit 3 – tx_en:** Enables transmitter.  
- **Bit 4 – rx_en:** Enables receiver.  

### UART_CFG (0x004, RW)
- **Bits 11:0 – clk_div:** Clock divider.  
- **Bits 15:12 – psclr:** Prescaler.  
- **Bits 17:16 – db:** Data bits (5–8).  
- **Bit 18 – pen:** Parity enable.  
- **Bit 19 – ptp:** Parity type (even/odd).  
- **Bit 20 – sb:** Stop bits (1 or 2).  

### UART_STAT (0x008, RO)
- **Bits 9:0 – tx_cnt:** TX FIFO entries.  
- **Bits 19:10 – rx_cnt:** RX FIFO entries.  
- **Bit 20 – tx_empty:** TX FIFO empty flag.  
- **Bit 21 – tx_full:** TX FIFO full flag.  
- **Bit 22 – rx_empty:** RX FIFO empty flag.  
- **Bit 23 – rx_full:** RX FIFO full flag.  

### UART_TXR (0x010, WO)
- **Bits 7:0 – id:** TX access request identifier.  
- **Bit 31 – valid:** Indicates request validity.  

### UART_TXGP (0x014, RO)
- **Bits 7:0 – id:** Current granted TX master ID (peek).  
- **Bit 31 – valid:** Indicates if grant is valid.  

### UART_TXG (0x018, RO)
- **Bits 7:0 – id:** Current granted TX master ID (consuming read).  
- **Bit 31 – valid:** Indicates if grant is valid.  

### UART_TXD (0x01C, WO)
- **Bits 7:0 – data:** Transmit data byte.  

### UART_RXR (0x020, WO)
- **Bits 7:0 – id:** RX access request identifier.  
- **Bit 31 – valid:** Indicates request validity.  

### UART_RXGP (0x024, RO)
- **Bits 7:0 – id:** Current granted RX master ID (peek).  
- **Bit 31 – valid:** Indicates if grant is valid.  

### UART_RXG (0x028, RO)
- **Bits 7:0 – id:** Current granted RX master ID (consuming read).  
- **Bit 31 – valid:** Indicates if grant is valid.  

### UART_RXD (0x02C, RO)
- **Bits 7:0 – data:** Receive data byte.  

### UART_INT (0x030, RW)
- **Bit 0 – tx_empty:** Interrupt when TX FIFO transitions non‑empty → empty.  
- **Bit 1 – tx_full:** Interrupt when TX FIFO transitions non‑full → full.  
- **Bit 2 – rx_empty:** Interrupt when RX FIFO transitions non‑empty → empty.  
- **Bit 3 – rx_full:** Interrupt when RX FIFO transitions non‑full → full.  

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

## Interrupt Handling
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



