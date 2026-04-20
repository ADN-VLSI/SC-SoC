/////////////////////////////////////////////////////////////////////////
//
// TC16: LOOPBACK
//
/////////////////////////////////////////////////////////////////////////
//
// Author: Shykul Islam Siam
//
/////////////////////////////////////////////////////////////////////////
//
// Objective: Verifies that the UART loopback mode correctly returns
//            every transmitted byte back through the receive path,
//            across a pattern array covering boundary and alternating
//            bit values.
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
//   Every TXD write returns BRESP == 2'b00 (OKAY).
//   RXD data arrives within RX_TIMEOUT_CYCLES for each byte.
//   rdata[7:0] matches the transmitted pattern byte exactly.
//
/////////////////////////////////////////////////////////////////////////
//
// Step-by-step process:
//
//  Step 1:  Baseline reads
//           Read CTRL and CFG to capture reset-state values.
//
//  Step 2:  Reset sequence
//           Write 0x0 to CTRL (disable). Wait 20 clocks.
//
//  Step 3:  Configure
//           Write 0x000341B0 to CFG. Wait 20 clocks.
//           Set loopback_en in uart_if to wire tx_o back to rx_i.
//           Write 0x18 to CTRL (rx_en + tx_en). Wait STABILISE_CYCLES.
//
//  Step 4:  Pattern sweep (i = 0 to NUM_BYTES-1)
//    4a     Write tx_pat[i] to TXD. Check BRESP == OKAY.
//    4b     Poll STAT[22] up to RX_TIMEOUT_CYCLES clock cycles.
//           Break as soon as rx_empty == 0 (byte in RX FIFO).
//    4c     Check poll did not time out.
//    4d     Read RXD. Check RRESP == OKAY.
//           Check rdata[7:0] == tx_pat[i].
//
//  Step 5:  Restore
//           Wait for TX drain (wait_tx_done).
//           Clear loopback_en. Write saved baselines back to CFG and CTRL.
//
/////////////////////////////////////////////////////////////////////////

task automatic tc16();
  logic [31:0] ctrl0, cfg0, stat, rdata;                                                     // ctrl0/cfg0 = baselines; stat = status poll scratch; rdata = RX readback scratch
  logic [1:0]  bresp, rresp;                                                                 // bresp = write response; rresp = read response
  bit          ok;                                                                           // flag: RX byte arrived before timeout

  localparam int NUM_BYTES         = 8;                                                      // number of pattern bytes to transmit
  localparam int RX_TIMEOUT_CYCLES = 50000;                                                  // maximum poll iterations before declaring timeout
  logic [7:0] tx_pat [0:NUM_BYTES-1] = '{                                                    // alternating-bit and boundary test pattern
    8'h00, 8'hFF, 8'h55, 8'hAA, 8'hA5, 8'h5A, 8'h01, 8'hFE
  };

  $display("------------------------------------------------------------");                  // visual separator in sim log
  $display("TC16: LOOPBACK");                                                                // test case banner
  $display("------------------------------------------------------------");                  // visual separator in sim log

  // Step 1: capture reset-state baselines before any writes
  cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);                                               // save CTRL default
  check(rresp == 2'b00, "tc16: read UART_CTRL");                                             // AXI read must succeed
  cpu_read_32(UART_CFG_OFFSET, cfg0, rresp);                                                 // save CFG default
  check(rresp == 2'b00, "tc16: read UART_CFG");                                              // AXI read must succeed

  // Step 2: reset sequence — disable UART before changing configuration
  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);                                              // disable UART
  check(bresp == 2'b00, "tc16: write UART_CTRL reset");                                      // AXI write must succeed
  repeat (20) @(posedge clk_i);                                                              // allow disable to propagate

  // Step 3: apply loopback configuration then enable
  cpu_write_32(UART_CFG_OFFSET, 32'h000341B0, bresp);                                        // write baud and frame configuration
  check(bresp == 2'b00, "tc16: write UART_CFG");                                             // AXI write must succeed
  repeat (20) @(posedge clk_i);                                                              // allow config to settle

  u_uart_if.loopback_en = 1;                                                                 // wire tx_o back to rx_i via uart_if assign; loopback_en_i propagates to RTL clock mux

  cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);                                             // enable rx_en[4] and tx_en[3]; no hardware loopback bit in this design
  check(bresp == 2'b00, "tc16: enable UART/loopback");                                       // AXI write must succeed
  repeat (STABILISE_CYCLES) @(posedge clk_i);                                                // wait for transceiver to reach steady state

  // Step 4: sweep pattern array — transmit each byte and verify loopback echo
  for (int i = 0; i < NUM_BYTES; i++) begin                                                  // iterate over every pattern byte

    // Step 4a: transmit pattern byte and check AXI acknowledgement
    cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);                                // zero-extend byte to 32 bits and write
    check(bresp == 2'b00,                                                                    // AXI must acknowledge write cleanly
          $sformatf("tc16: TX write idx %0d (0x%02h)", i, tx_pat[i]));                       // report index and pattern value

    // Step 4b: poll STAT until rx_empty[22] == 0 (byte present in RX FIFO)
    ok = 0;                                                                                  // clear valid flag before polling
    for (int t = 0; t < RX_TIMEOUT_CYCLES; t++) begin                                        // poll up to RX_TIMEOUT_CYCLES times
      cpu_read_32(UART_STAT_OFFSET, stat, rresp);                                            // read status register
      if (rresp == 2'b00 && stat[22] == 1'b0) begin                                          // rx_empty == 0 means at least one byte is available
        ok = 1;                                                                              // mark byte as received
        break;                                                                               // exit poll loop immediately
      end
      @(posedge clk_i);                                                                      // advance one clock before next poll
    end

    // Step 4c: confirm the byte arrived before the timeout expired
    check(ok, $sformatf("tc16: RX timeout idx %0d (0x%02h)", i, tx_pat[i]));                 // fail if RX FIFO never became non-empty

    // Step 4d: read RXD and verify loopback data matches the transmitted pattern byte
    if (ok) begin                                                                            // only read and check when a byte is actually present
      cpu_read_32(UART_RXD_OFFSET, rdata, rresp);                                            // consume byte from RX FIFO
      check(rresp == 2'b00,                                                                  // regif must return OKAY (rx_data_valid was asserted)
            $sformatf("tc16: RXD read idx %0d", i));                                         // report index on unexpected SLVERR
      check(rdata[7:0] == tx_pat[i],                                                         // lower byte must equal the transmitted pattern
            $sformatf("tc16: loopback idx %0d got=0x%02h exp=0x%02h",                        // neutral label — readable on both pass and fail
                      i, rdata[7:0], tx_pat[i]));
    end

  end                                                                                        // end pattern sweep

  // Step 5: drain TX, disable loopback, restore baselines
  wait_tx_done();                                                                            // block until tx_empty set in STAT[20] — CFG write gated on both FIFOs empty
  u_uart_if.loopback_en = 0;                                                                 // release loopback wire before restoring CTRL
  cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp);                                             // restore CFG
  check(bresp == 2'b00, "tc16: restore UART_CFG");                                          // AXI write must succeed
  cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);                                             // restore CTRL
  check(bresp == 2'b00, "tc16: restore UART_CTRL");                                         // AXI write must succeed

  $display("TC16 DONE");                                                                    // confirm test case completion in sim log

endtask                                                                                     // end tc16