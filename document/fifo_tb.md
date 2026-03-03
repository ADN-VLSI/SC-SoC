# Handshake FIFO Test Plan

## Hand shake FIFO

The Device Under Test (DUT) is a Parametric Synchronous FIFO. It acts as a First-In-First-Out buffer to synchronize data flow between a producer and a consumer on a single clock domain.


#### Type:

Synchronous FIFO with valid/ready handshake

#### Parameters:

- DATA_WIDTH – Width of data bus

- FIFO_SIZE – Log2 of FIFO depth

- FIFO_DEPTH = 2**FIFO_SIZE

#### Inputs

- clk_i – Clock

- arst_ni – Asynchronous active-low reset

- data_i[DATA_WIDTH-1:0] – Input data

- data_i_valid_i – Input valid

- data_o_ready_i – Output ready

#### Outputs

- data_i_ready_o – FIFO ready to accept input

- data_o[DATA_WIDTH-1:0] – Output data

- data_o_valid_o – Output valid


## Functional Description

The DUT manages data storage using a circular buffer implementation.

- Handshaking: Uses valid and ready signals to ensure zero data loss (Backpressure).

- Write Logic: Occurs only when data_i_valid_i and data_i_ready_o are both high.

- Read Logic: Occurs only when data_o_valid_o and data_o_ready_i are both high.

- Status Tracking: An internal count register tracks the number of elements to determine full and empty states.

## Challenges and Risks

- Handshake Corner Cases: Many valid/ready timing combinations may hide data loss or duplication bugs.

- Boundary Conditions: Errors may occur at Empty ↔ Non-Empty and Full ↔ Non-Full transitions.

- Simultaneous Read/Write: Risk of incorrect pointer/count updates in same-cycle operations.

- Asynchronous Reset: Reset during active transactions may corrupt pointers or count.

- Parameterization Issues: Bugs may appear for small depths (e.g., depth=1) or large configurations.

- Scoreboard Misalignment: Incorrect handshake tracking may cause false mismatches.

## Test Environment

The environment will follow a standard UVM-like layered architecture:
- Driver: Drives the input interface (data_i, data_i_valid_i) and responds to the DUT's ready signal.
- Monitor (Input): Captures successful writes (where valid & ready are high) and sends them to the scoreboard.
- Monitor (Output): Captures successful reads (where valid & ready are high) from the output bus.
- Scoreboard: Contains a SystemVerilog Queue to model the FIFO. It compares the expected data from the input monitor against the actual data from the output monitor.

### Testbench Architecture

![alt text](fifo_tb.drawio.svg)

## Verification Methodology

- Constrained Random Testing (CRT): Primary method to hit a wide range of data patterns and handshake timing (e.g., randomizing the "ready" signal from the consumer). 
- Directed Testing: Specifically used for Reset and "Full-to-Empty" transitions. 
- Scoreboarding: A reference model will predict the FIFO state. Since the DUT is a simple FIFO, a push_back() and pop_front() queue mechanism is used for checking. 
- Stimulus Generation: Random delays will be inserted between valid assertions to stress-test the DUT's ability to hold data.
## Test Cases


### TC1: Single Write and Read
---
#### Description
Verify that the FIFO correctly handles one write followed by one read and maintains proper data integrity.

#### Test Steps
1. Apply reset and release reset.
2. Ensure FIFO is empty.
3. Drive one valid write transaction:
   - Set `data_i_valid_i = 1`
   - Provide a known value on `data_i`
4. Wait for write handshake:
   - `data_i_valid_i && data_i_ready_o`
5. Deassert `data_i_valid_i`.
6. Drive read:
   - Set `data_o_ready_i = 1`
7. Wait for read handshake:
   - `data_o_valid_o && data_o_ready_i`

#### Expected Results
- FIFO accepts the data.
- `data_o_valid_o` becomes `1` after write.
- Read data matches written data.
- FIFO becomes empty after read.
- No overflow or underflow occurs.


---
### TC2: Multiple Write and Read
---
#### Description
Verify FIFO behavior for multiple sequential writes followed by multiple reads, ensuring correct FIFO ordering.

#### Test Steps
1. Apply reset and release.
2. Write `N` data values sequentially (`N < FIFO_DEPTH`).
3. Store written values in a reference queue.
4. Assert `data_o_ready_i` and read `N` times.
5. Compare each read value with the reference queue output.

#### Expected Results
- All writes are accepted.
- All reads occur in the same order as written.
- No data corruption.
- FIFO becomes empty after all reads.

---

### TC3: FIFO Full Condition
---

#### Description
Verify that FIFO correctly detects the full condition and prevents overflow.

#### Test Steps
1. Apply reset.
2. Continuously write data until `data_i_ready_o` becomes `0`.
3. Attempt additional write while FIFO is full.
4. Keep `data_i_valid_i = 1`.

#### Expected Results
- FIFO accepts exactly `FIFO_DEPTH` entries.
- `data_i_ready_o` becomes `0` when FIFO is full.
- Additional writes are not accepted.
- No overflow occurs.
- Stored data remains correct.

---

### TC4: Simultaneous Read and Write
---

#### Description
Verify FIFO behavior when read and write occur in the same clock cycle.

#### Test Steps
1. Apply reset.
2. Write a few entries into FIFO (not full).
3. In the same clock cycle:
   - Set `data_i_valid_i = 1`
   - Set `data_o_ready_i = 1`
4. Continue for multiple cycles.
5. Track expected FIFO count in reference model.

#### Expected Results
- Read and write occur in the same cycle.
- FIFO count remains unchanged.
- Data ordering is maintained.
- No pointer corruption occurs.

---

### TC5: Random Read and Write

#### Description
Verify FIFO robustness under random valid/ready behavior with random data patterns.

#### Test Steps
1. Apply reset.
2. For a large number of cycles:
   - Randomize `data_i_valid_i`
   - Randomize `data_o_ready_i`
   - Randomize `data_i`
3. Maintain a reference queue model.
4. Compare DUT output with reference model.

#### Expected Results
- No overflow or underflow.
- FIFO ordering is always preserved.
- No data mismatches occur.
- FIFO operates correctly under stress conditions.

---

## Test Case Summary Table

| Test Case Name | Objective | Handshake Scenario | Pass Criteria |
|----------------|-----------|--------------------|---------------|
| Single Write and Read | Verify basic write and read functionality | Simple valid-ready handshake | Read data matches written data, FIFO returns to empty |
| Multiple Write and Read | Verify FIFO ordering and sequential operations | Continuous valid and ready | Data read order matches write order (FIFO behavior) |
| FIFO Full Condition | Verify full detection and overflow protection | Valid asserted while ready deasserted | `data_i_ready_o` goes LOW at full, no overflow occurs |
| Simultaneous Read and Write | Verify correct behavior when read & write occur same cycle | Valid & Ready asserted on both sides | FIFO count unchanged, data integrity maintained |
| Random Read and Write | Verify robustness under random traffic | Random valid/ready toggling | No mismatch, no overflow/underflow, stable operation |

---


## Functional Coverage [LATER]

The functional coverage aims to ensure all critical FIFO behaviors are exercised:

- FIFO States: Empty, Near-Empty, Partial, Near-Full, Full.

- Handshake Coverage: All valid/ready combinations for both write and read sides.

- Simultaneous Operations: Read+Write in the same cycle (crossed with FIFO state).

- Boundary Transitions: Empty→Non-Empty, Non-Empty→Empty, Full→Non-Full, Non-Full→Full.

- Reset Scenarios: Reset at different occupancy levels and during active transactions.

- Data Patterns: Zero, max/min values, alternating, and random data.


#### Measurement Method

- Implement SystemVerilog covergroups in monitor/scoreboard.

- Use coverpoints for FIFO count, handshake signals, and operations.

- Use cross coverage for critical combinations (e.g., Read/Write × FIFO state).

- Generate simulator coverage reports.

- Closure when all defined bins are hit and no critical scenarios remain uncovered.
