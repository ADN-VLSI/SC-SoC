# 📘 uart_subsystem_tb

---

## 1. Overview

The **UART Subsystem Testbench (`uart_subsystem_tb`)** is designed to verify the functional correctness, protocol compliance, and robustness of a UART subsystem with an AXI4-Lite interface.

This testbench validates the complete UART data path including AXI interface, transmitter, receiver, and FIFO behavior under normal, boundary, and stress conditions.

This testbench covers:

- Reset behavior and initialization  
- AXI4-Lite protocol compliance  
- UART TX functionality and timing  
- UART RX functionality and ordering  
- FIFO boundary conditions (full, empty, overflow)  
- Error detection (parity, framing)  
- End-to-end validation using loopback  

A total of **18 structured test cases** ensure comprehensive verification.

---

## 2. Test Categories

### 🔹 Reset & Initialization
- TC0: Power-On Reset  
- TC1: Mid-Operation Reset  

### 🔹 AXI Interface
- TC2: Basic Read/Write  
- TC3: Invalid Address Handling  
- TC4: Back-to-Back Transactions  
- TC5: Concurrent Access  
- TC13: Backpressure Handling  

### 🔹 Transmitter (TX)
- TC6: Single Byte Transmission  
- TC7: Continuous Stream  
- TC8: TX FIFO Full  
- TC9: Configuration Sweep  

### 🔹 Receiver (RX)
- TC10: Parity Flag Check  
- TC11: Continuous RX  
- TC12: RX FIFO Overflow  

### 🔹 Integration
- TC16: Loopback Test  

---

## 3. Important Registers

| Register  | Offset | Description |
|----------|--------|------------|
| CTRL     | 0x00   | UART configuration (TX enable, parity, stop bits, etc.) |
| BAUD_DIV | 0x04   | Baud rate divisor |
| STATUS   | 0x08   | Status flags (TX_EMPTY, RX_FULL, errors) |
| TX_DATA  | 0x10   | Transmit FIFO input |
| RX_DATA  | —      | Receive FIFO output |

---

## 4. Test Cases

---

### TC0: Power-On Reset

**Objective**  
Verify system initializes to a known safe state after reset.

**Preconditions**  
Fresh DUT, clocks running  

**Test Steps**
- Assert reset  
- Deassert reset  
- Read registers  
- Check FIFO levels  

**Pass Criteria**

| Check | Expected |
|------|--------|
| tx_o | HIGH |
| Registers | Default values |
| FIFO | Empty |

---

### TC1: Mid-Operation Reset

**Objective**  
Verify reset during transmission clears system immediately.

**Preconditions**  
Ongoing transmission  

**Test Steps**
- Start TX  
- Assert reset mid-frame  
- Deassert reset  
- Restart TX  

**Pass Criteria**

| Check | Expected |
|------|--------|
| tx_o | Returns HIGH |
| FIFO | Cleared |
| TX restart | Works |

---

### TC2: AXI Basic Read/Write

**Objective**  
Verify AXI read/write correctness.

**Preconditions**  
DUT initialized  

**Test Steps**
- Write registers  
- Read back values  
- Test RO register  

**Pass Criteria**

| Check | Expected |
|------|--------|
| BRESP/RRESP | OKAY |
| Readback | Matches |

---

### TC3: AXI Invalid Address

**Objective**  
Verify invalid address handling.

**Preconditions**  
DUT initialized  

**Test Steps**
- Access invalid address  
- Read valid registers  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Response | SLVERR |
| Registers | Unchanged |

---

### TC4: Back-to-Back AXI Transactions

**Objective**  
Verify continuous AXI operations.

**Preconditions**  
AXI ready  

**Test Steps**
- Issue continuous writes  
- Issue continuous reads  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Transactions | Complete |
| Order | Preserved |

---

### TC5: Concurrent AXI Access

**Objective**  
Verify simultaneous TX and RX operations.

**Preconditions**  
RX FIFO preloaded  

**Test Steps**
- Perform TX write + RX read  
- Repeat sequence  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Deadlock | None |
| Data | Correct |

---

### TC6: Single Byte Transmission

**Objective**  
Verify correct UART frame transmission.

**Preconditions**  
UART configured  

**Test Steps**
- Send 0x55  
- Observe frame  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Frame | Correct |
| Timing | Accurate |

---

### TC7: Continuous Stream

**Objective**  
Verify continuous transmission without gaps.

**Preconditions**  
FIFO maintained  

**Test Steps**
- Fill FIFO  
- Keep writing  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Gaps | None |
| Data | No loss |

---

### TC8: TX FIFO Full

**Objective**  
Verify FIFO full and overflow handling.

**Preconditions**  
Known FIFO depth  

**Test Steps**
- Fill FIFO  
- Attempt extra write  
- Observe response  
- Drain FIFO  

**Pass Criteria**

| Check | Expected |
|------|--------|
| TX_FULL | Asserted |
| Overflow | No corruption |
| Order | Preserved |

---

### TC9: Configuration Sweep

**Objective**  
Verify different UART configurations.

**Preconditions**  
Configurable UART  

**Test Steps**
- Change config  
- Send data  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Frame | Matches config |
| Parity | Correct |

---

### TC10: Parity Flag Check

**Objective**  
Verify parity error detection.

**Preconditions**  
Parity enabled  

**Test Steps**
- Inject wrong parity  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Parity flag | Asserted |

---

### TC11: Continuous RX

**Objective**  
Verify continuous reception.

**Preconditions**  
RX active  

**Test Steps**
- Send stream  
- Read FIFO  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Data | Correct |
| Order | Preserved |

---

### TC12: RX FIFO Overflow

**Objective**  
Verify RX overflow handling.

**Preconditions**  
FIFO depth known  

**Test Steps**
- Fill FIFO  
- Send extra byte  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Overflow flag | Asserted |
| Data | Valid |

---

### TC13: Backpressure Handling

**Objective**  
Verify AXI backpressure behavior.

**Preconditions**  
AXI active  

**Test Steps**
- Deassert READY  
- Observe VALID  

**Pass Criteria**

| Check | Expected |
|------|--------|
| VALID | Held |
| Transactions | Resume |

---

### TC16: Loopback Test

**Objective**  
Verify end-to-end data path.

**Preconditions**  
tx_o connected to rx_i  

**Test Steps**
- Send data  
- Read back  
- Run stress test  

**Pass Criteria**

| Check | Expected |
|------|--------|
| Data | Match |
| Order | Correct |
| Errors | None |

