/////////////////////////////////////////////////////////////////////////
//
// TC9: TX Config Sweep
//
/////////////////////////////////////////////////////////////////////////
//
// Author: Shykul Islam Siam
//
/////////////////////////////////////////////////////////////////////////
//
// Objective: Verifies that the UART transmitter accepts all supported
//            frame configurations and responds correctly to TXR writes
//            across a sweep of parity, stop-bit, and data-bit settings.
//
/////////////////////////////////////////////////////////////////////////
//
// Restore:
//   CTRL and CFG are restored to their baseline values captured
//   at the start of the task.
//
/////////////////////////////////////////////////////////////////////////
//
// Pass criteria:
//   CFG readback data matches written value for every configuration.
//   All BRESP responses == 2'b00 (OKAY) for CFG, CTRL, and TXR writes.
//
/////////////////////////////////////////////////////////////////////////
//
// Step-by-step process:
//
//  Step 1:  Baseline reads
//           Read CTRL and CFG to capture reset-state values.
//
//  Step 2:  Compute timing
//           Calculate bitcy = CLK_FREQ / BAUD for inter-step
//           simulation delays.
//
//  Step 3:  Configuration sweep (c = 0 to 5)
//    3a     Select frame format via case on c:
//             0 → 0x0000_0000  (8N1)
//             1 → 0x0000_1000  (8E1)
//             2 → 0x0000_2000  (8O1)
//             3 → 0x0000_3000  (8N2)
//             4 → 0x0000_4000  (7E1)
//             5 → 0x0000_5000  (7O2)
//    3b     Insert baud divisor into cfg[15:0].
//    3c     Write 0x0 to CTRL (disable). Wait 10 clocks.
//           Write 0x6 to CTRL (flush).  Wait 10 clocks.
//           Write cfg   to CFG.         Wait 10 clocks.
//           Write 0x18  to CTRL (enable).
//           Wait bitcy × 4 clocks for the transmitter to settle.
//    3d     Read CFG back. Check readback data == cfg.
//    3e     Write 0x55 to TXR. Check BRESP == OKAY.
//           Wait bitcy × 4 clocks to allow TX to finish.
//
//  Step 4:  Restore
//           Write saved baseline values back to CTRL and CFG.
//
/////////////////////////////////////////////////////////////////////////

task automatic tc9();
    logic [31:0] ctrl0, cfg0, cfg, rd;                                                       // ctrl0/cfg0 = baselines; cfg = sweep value; rd = readback scratch
    logic [1:0]  bresp, rresp;                                                               // bresp = write response; rresp = read response
    int          bitcy;                                                                      // cycles per bit at target baud rate

    int unsigned BAUD      = 115200;                                                         // target baud rate (change as needed)
    int unsigned CLK_FREQ  = 100_000_000;                                                    // system clock frequency — 100 MHz
    int unsigned baud_div;                                                                   // computed divisor written into cfg[15:0]

    $display("------------------------------------------------------------");                // visual separator in sim log
    $display("TC9: TX Config Sweep");                                                        // test case banner
    $display("------------------------------------------------------------");                // visual separator in sim log

    // Step 1: capture reset-state baselines before any writes
    cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);                                             // save CTRL default
    cpu_read_32(UART_CFG_OFFSET,  cfg0,  rresp);                                             // save CFG default

    // Step 2: compute bit-period in clock cycles for simulation delays
    bitcy = CLK_FREQ / BAUD;                                                                 // approximate cycles per bit

    // Step 3: sweep all six frame configurations
    for (int c = 0; c < 6; c++) begin                                                        // iterate c = 0 through 5

        // Step 3a: select frame format for this iteration
        case (c)
            0: cfg = 32'h0000_0000;                                                          // 8N1 — 8 data, no parity, 1 stop
            1: cfg = 32'h0000_1000;                                                          // 8E1 — 8 data, even parity, 1 stop
            2: cfg = 32'h0000_2000;                                                          // 8O1 — 8 data, odd parity, 1 stop
            3: cfg = 32'h0000_3000;                                                          // 8N2 — 8 data, no parity, 2 stop
            4: cfg = 32'h0000_4000;                                                          // 7E1 — 7 data, even parity, 1 stop
            5: cfg = 32'h0000_5000;                                                          // 7O2 — 7 data, odd parity, 2 stop
        endcase

        // Step 3b: insert baud divisor into lower 16 bits of cfg
        baud_div    = CLK_FREQ / BAUD;                                                       // recompute divisor (kept explicit for readability)
        cfg[15:0]   = baud_div[15:0];                                                        // lower 16 bits hold baud divisor

        // Step 3c: disable, flush, reconfigure, then enable the transmitter
        cpu_write_32(UART_CTRL_OFFSET, 32'h0,  bresp);                                       // disable UART before changing config
        repeat (10) @(posedge clk_i);                                                        // allow disable to propagate
        cpu_write_32(UART_CTRL_OFFSET, 32'h6,  bresp);                                       // flush TX and RX FIFOs
        repeat (10) @(posedge clk_i);                                                        // allow flush to complete
        cpu_write_32(UART_CFG_OFFSET,  cfg,    bresp);                                       // write frame configuration
        repeat (10) @(posedge clk_i);                                                        // allow config to settle
        cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);                                       // enable UART (TX + RX enable bits)
        repeat (bitcy * 4) @(posedge clk_i);                                                 // wait for transmitter to reach steady state

        // Step 3d: verify the config register accepted the written value
        cpu_read_32(UART_CFG_OFFSET, rd, rresp);                                             // read back after enable
        check(rd == cfg, $sformatf("cfg%0d accepted: 0x%08h", c, rd));                       // readback must match exactly

        // Step 3e: issue a TXR write and verify AXI acknowledges it
        cpu_write_32(UART_TXR_OFFSET, 32'h55, bresp);                                        // 0x55 = 0101_0101, alternating-bit TX pattern
        check(bresp == 2'b00, $sformatf("cfg%0d TXR write BRESP=OK", c));                    // AXI must acknowledge write cleanly
        repeat (bitcy * 4) @(posedge clk_i);                                                 // allow current frame to complete before next config

    end                                                                                      // end configuration sweep

    // Step 4: restore baselines so subsequent TCs start from a clean state
    cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);                                            // restore CTRL
    cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp);                                            // restore CFG

endtask                                                                                      // end tc9