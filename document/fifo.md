#Handshake FIFO
---
##Author's Name: Dhruba Jyoti Barua
---


##Overview

This repository contains a **parameterized synchronous Handshake FIFO** implemented in **SystemVerilog**.

The FIFO uses the standard **valid–ready handshake protocol** to safely transfer data between a producer and a consumer block operating in the same clock domain.

---

###Key Features

---

- Flow control (backpressure)
- Safe buffering
- Simultaneous read/write support
- Scalable depth and width
- Clean RTL implementation
- Synthesizable design

---
![Handshake FIFO](fifo.drawio.svg)
---

##Why is FIFO Needed

In digital systems, different modules may:

- Operate at different speeds
- Stall due to downstream pipeline backpressure
- Produce or consume data in bursts

Without proper buffering:

- Data may be lost (**overflow**)
- Garbage data may be read (**underflow**)
- System throughput may degrade
- Design becomes tightly coupled and fragile

This FIFO solves these issues by implementing:

- Controlled data transfer
- Occupancy tracking
- Full/empty detection
- Valid-ready handshake protocol
- Automatic backpressure propagation

---

##Architecture

###FIFO Depth

```
FIFO_DEPTH = 2**FIFO_SIZE
```

Example:

-`FIFO_SIZE = 4`
-`FIFO_DEPTH = 16`

---

### Internal Components

- Memory array
- Write pointer
- Read pointer
- Occupancy counter
- Full / Empty detection logic

---

##Interface Description

---

###Parameters

| Parameter     | Description                        |
|--------------|------------------------------------|
| DATA_WIDTH   | Width of the data bus              |
| FIFO_SIZE    | log2 of FIFO depth                 |


---

###Clock & Reset

| Signal     | Direction | Description                     |
|------------|-----------|---------------------------------|
| clk_i      | Input     | System clock                    |
| arst_ni    | Input     | Asynchronous active-low reset   |


---

#### Write Handshake Condition

```
write_fire = data_i_valid_i && data_i_ready_o
```

Write occurs only when both signals are high.

---

### Read Side (FIFO → Consumer)

| Signal              | Direction | Description                              |
|---------------------|----------|------------------------------------------|
| data_o              | Output   | Output data                              |
| data_o_valid_o      | Output   | Indicates output data is valid           |
| data_o_ready_i      | Input    | Consumer ready to accept output data     |

#### Read Handshake Condition

```
read_fire = data_o_valid_o && data_o_ready_i
```

Read occurs only when both signals are high.

---

##Behaviour

This FIFO implements a **synchronous valid–ready handshake buffer** that guarantees:

- Ordered data storage (First-In First-Out)
- No overflow
- No underflow
- Automatic backpressure propagation
- Safe simultaneous read and write

---

###Reset Behaivour

When `arst_ni = 0` (active-low reset):

- Write pointer is reset to 0
- Read pointer is reset to 0
- FIFO occupancy becomes 0
- `data_o_valid_o = 0` (no valid output data)
- `data_i_ready_o = 1` (FIFO ready to accept data)

The FIFO starts in an **empty state**.

---

### Normal Operation


The FIFO operates using the valid–ready handshake protocol.

---

####  Write Operation

A write occurs when:

```
data_i_valid_i && data_i_ready_o
```

When a write happens:

- Input data is stored in memory
- Write pointer increments
- FIFO occupancy increases

If FIFO becomes full:

```
data_i_ready_o = 0
```

Producer must stop sending data.

---

### Read Operation

A read occurs when:

```
data_o_valid_o && data_o_ready_i
```

When a read happens:

- Data is provided on `data_o`
- Read pointer increments
- FIFO occupancy decreases

If FIFO becomes empty:

```
data_o_valid_o = 0
```

Consumer must wait for new data.

---

### Full Condition

The FIFO is **full** when:

```
occupancy == FIFO_DEPTH
```

When full:

- `data_i_ready_o = 0`
- Further writes are blocked
- Memory contents are protected
- Backpressure propagates upstream

---

### Empty Condition

The FIFO is **empty** when:

```
occupancy == 0
```

When empty:

- `data_o_valid_o = 0`
- Read pointer does not advance
- No invalid data is produced

---

### Simultanous Read and Write

If both write and read occur in the same clock cycle:

- Write pointer increments
- Read pointer increments
- Occupancy remains unchanged
- Throughput can reach 1 transfer per cycle

This allows high-performance pipeline operation.

---

### Data Ordering Guarantee 

The FIFO ensures strict ordering:

```
First data written == First data read
```

No reordering occurs.

---

### Backpressure Mechanism

| Condition     | Effect on System |
|--------------|-----------------|
| FIFO Full    | Producer stalls |
| FIFO Empty   | Consumer stalls |

This decouples producer and consumer speeds.

---

### Safety Guarantees

The FIFO guarantees:

- No overflow (write blocked when full)
- No underflow (read blocked when empty)
- Stable output when no read occurs
- Synthesizable logic
- Deterministic behavior

---

### Throughput Characteristics

| Scenario                        | Result |
|---------------------------------|--------|
| Continuous write only           | Fills FIFO |
| Continuous read only            | Drains FIFO |
| Continuous read & write         | Steady-state streaming |
| Bursty traffic                  | Smooth buffering |

Maximum sustained throughput: **1 word per clock cycle**

---

### Summary 

This FIFO behaves as a :

- Safe
- Ordered
- Flow-controlled
- Synchronous buffering element

It is suitable for:

- Pipeline decoupling
- Streaming interfaces
- AXI-like handshakes
- SoC datapaths
- DSP chains

---

## Integration Checklist

### Clock & Reset
- [ ] Single clock domain
- [ ] Reset polarity correct (active-low)
- [ ] Reset sequencing verified

---

### Handshake Compliance
Producer:
- [ ] Holds `in_data` stable until accepted
- [ ] Uses `in_valid && in_ready` as write condition

Consumer:
- [ ] Uses `out_valid && out_ready` as read condition
- [ ] Does not sample data when `out_valid=0`

---

### Configuration
- [ ] `WIDTH` matches system bus
- [ ] `DEPTH` sized for worst-case burst
- [ ] Throughput requirement satisfied

---

### Safety
- [ ] No overflow (writes blocked when full)
- [ ] No underflow (reads blocked when empty)
- [ ] Backpressure acceptable in system

---

# Test Ideas

### Reset Tests
- After reset:
  - `out_valid = 0`
  - `in_ready = 1`
- Reset during activity → FIFO returns to empty state.

---

### Basic Functional Tests
- Write 1 item → Read 1 item → Data matches.
- Write multiple items → Read all → Order preserved.
- Consumer stall (`out_ready=0`) → `out_data` stable.
- Producer stall (`in_valid=0`) → No write occurs.

---

### Full / Empty Tests

- Fill FIFO completely → `in_ready = 0`.
- Try writing when full → No overwrite.
- Drain FIFO completely → `out_valid = 0`.
- Try reading when empty → No pointer movement.

---

### Simultaneous Read & Write 

- Keep `in_valid=1` and `out_ready=1`.
- Expect sustained 1 transfer per cycle.
- No overflow or underflow.

---

### Random Stress Test

- Randomize `in_valid` and `out_ready`.
- Use a scoreboard queue:
  - Push on write_fire
  - Pop on read_fire
- Compare expected vs actual output.

---

### Handshake Compliance

Producer:
- [ ] Holds `in_data` stable until accepted
- [ ] Uses `in_valid && in_ready` as write condition

Consumer:
- [ ] Uses `out_valid && out_ready` as read condition
- [ ] Does not sample data when `out_valid=0`

---

### Configuration
- [ ] `WIDTH` matches system bus
- [ ] `DEPTH` sized for worst-case burst
- [ ] Throughput requirement satisfied

---

### Safety
- [ ] No overflow (writes blocked when full)
- [ ] No underflow (reads blocked when empty)
- [ ] Backpressure acceptable in system
































































































