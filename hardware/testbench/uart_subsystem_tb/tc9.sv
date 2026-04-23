/////////////////////////////////////////////////////////////////////////
//
// TC9: TX/RX Config Sweep
//
/////////////////////////////////////////////////////////////////////////
//
// Author: Shykul Islam Siam
//
/////////////////////////////////////////////////////////////////////////
//
// Objective: Verifies that the UART transmitter and receiver accept all
//            supported frame configurations. A loopback path (tx_o wired
//            to rx_i) is used so each transmitted byte is echoed back
//            through the RX path and verified to match the original data
//            across all parity, stop-bit, and data-bit combinations.
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
//   All BRESP and RRESP responses == 2'b00 (OKAY).
//   RXD data matches transmitted byte for every frame format.
//   No RX timeout for any configuration.
//
/////////////////////////////////////////////////////////////////////////
//
// Step-by-step process:
//
//  Step 1:  Baseline reads
//           Read CTRL and CFG to capture reset-state values.
//
//  Step 2:  Configuration sweep (c = 0 to 5)
//    2a     Build CFG word:
//             CFG[20]    = sb  (extra stop bit)
//             CFG[19]    = ptp (parity type: 0=even 1=odd)
//             CFG[18]    = pen (parity enable)
//             CFG[17:16] = db  (data bits: 2=7bit 3=8bit)
//             CFG[15:12] = psclr = 4
//             CFG[11:0]  = clk_div = 0x1B0
//             Configurations:
//               0 → 0x000341B0  (8N1)
//               1 → 0x000741B0  (8E1)
//               2 → 0x000F41B0  (8O1)
//               3 → 0x001341B0  (8N2)
//               4 → 0x000641B0  (7E1)
//               5 → 0x001E41B0  (7O2)
//    2b     Disable UART. Wait 10 clocks.
//           Flush FIFOs (CTRL=0x6). Wait 20 clocks.
//           Clear flush (CTRL=0x0). Wait 20 clocks.
//           Write CFG. Check BRESP == OKAY.
//           Force loopback (tx wired to rx).
//           Enable UART (CTRL=0x18). Wait STABILISE_CYCLES.
//    2c     Read CFG back. Check readback == cfg.
//    2d     Wait for TX FIFO empty (STAT[20]).
//           Write 0x55 to TXD. Check BRESP == OKAY.
//    2e     Poll STAT[22] (rx_empty) up to RX_TIMEOUT_CYCLES.
//           Check poll did not time out.
//    2f     Read RXD. Check RRESP == OKAY.
//           Check rdata[7:0] == 0x55.
//           For 7-bit configs (db=2) only bits [6:0] are compared.
//
//  Step 3:  Restore
//           Wait for TX drain. Release loopback.
//           Disable, flush, clear flush, restore CFG, restore CTRL.
//
/////////////////////////////////////////////////////////////////////////

task automatic tc9();
  logic [31:0] ctrl0, cfg0, cfg, rd, stat, rdata;                                           // ctrl0/cfg0 = baselines; cfg = sweep value; rd/stat/rdata = scratch
  logic [1:0]  bresp, rresp;                                                                // bresp = write response; rresp = read response
  bit          ok;                                                                          // flag: RX byte arrived before timeout
  logic [7:0]  exp_data;                                                                    // expected RX byte (masked to active data bits)
  logic [7:0]  rx_mask;                                                                     // bit mask for data comparison (7-bit vs 8-bit)

  localparam logic [15:0] TIMING           = 16'h41B0;                                      // psclr=4 | clk_div=0x1B0 -> ~115741 baud at 100 MHz
  localparam int          BITCY            = 865;                                           // cycles per bit at ~115741 baud
  localparam int          RX_TIMEOUT_CYCLES = 200000;                                       // increased: accounts for 4x oversampling + CDC latency
  localparam int          TX_DRAIN_TIMEOUT  = 200000;                                       // maximum poll iterations waiting for tx_empty

  $display("------------------------------------------------------------");
  $display("TC9: TX/RX Config Sweep");
  $display("------------------------------------------------------------");

  // Step 1: capture reset-state baselines before any writes
  cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);                                              // save CTRL default
  check(rresp == 2'b00, "tc9: read UART_CTRL");
  cpu_read_32(UART_CFG_OFFSET, cfg0, rresp);                                                // save CFG default
  check(rresp == 2'b00, "tc9: read UART_CFG");

  // Step 2: sweep all six frame configurations
  for (int c = 0; c < 6; c++) begin

    // Step 2a: build CFG word with frame bits at correct positions [20:16]
    case (c)
      0: cfg = {16'h0003, TIMING};                                                          // 8N1: sb=0 ptp=0 pen=0 db=3
      1: cfg = {16'h0007, TIMING};                                                          // 8E1: sb=0 ptp=0 pen=1 db=3
      2: cfg = {16'h000F, TIMING};                                                          // 8O1: sb=0 ptp=1 pen=1 db=3
      3: cfg = {16'h0013, TIMING};                                                          // 8N2: sb=1 ptp=0 pen=0 db=3
      4: cfg = {16'h0006, TIMING};                                                          // 7E1: sb=0 ptp=0 pen=1 db=2
      5: cfg = {16'h001E, TIMING};                                                          // 7O2: sb=1 ptp=1 pen=1 db=2
    endcase

    // data comparison mask — 7-bit configs only use bits [6:0]
    rx_mask   = (cfg[17:16] == 2'd2) ? 8'h7F : 8'hFF;
    exp_data  = 8'h55 & rx_mask;

    // Step 2b: disable, flush, reconfigure, enable with loopback
    cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);                                           // disable UART
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d disable CTRL", c));
    repeat (10) @(posedge clk_i);

    cpu_write_32(UART_CTRL_OFFSET, 32'h6, bresp);                                           // flush TX[1] + RX[2] FIFOs
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d flush CTRL", c));
    repeat (20) @(posedge clk_i);

    cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);                                           // clear flush bits so CDC counts drain to zero
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d clear flush", c));
    repeat (20) @(posedge clk_i);

    cpu_write_32(UART_CFG_OFFSET, cfg, bresp);                                              // write frame + timing config
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d write UART_CFG", c));

    force u_uart_if.tx = u_uart_if.rx;                                                      // wire tx_o back to rx_i for loopback

    cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);                                          // enable TX[3] + RX[4]
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d enable CTRL", c));
    repeat (STABILISE_CYCLES) @(posedge clk_i);

    // Step 2c: verify CFG readback
    cpu_read_32(UART_CFG_OFFSET, rd, rresp);
    check(rresp == 2'b00, $sformatf("tc9: cfg%0d readback rresp", c));
    check(rd == cfg, $sformatf("tc9: cfg%0d readback got=0x%08h exp=0x%08h", c, rd, cfg));

    // Step 2d: wait for TX empty then transmit one byte
    for (int t = 0; t < TX_DRAIN_TIMEOUT; t++) begin
      cpu_read_32(UART_STAT_OFFSET, stat, rresp);
      if (rresp == 2'b00 && stat[20] == 1'b1) break;                                        // STAT[20] = tx_empty
      @(posedge clk_i);
    end

    cpu_write_32(UART_TXD_OFFSET, 32'h55, bresp);                                           // 0x55 = 0101_0101 alternating-bit pattern
    check(bresp == 2'b00, $sformatf("tc9: cfg%0d TXD write BRESP=OK", c));

    // Step 2e: poll for RX byte
    ok = 0;
    for (int t = 0; t < RX_TIMEOUT_CYCLES; t++) begin
      cpu_read_32(UART_STAT_OFFSET, stat, rresp);
      if (rresp == 2'b00 && stat[22] == 1'b0) begin                                         // STAT[22] = rx_empty; 0 means byte present
        ok = 1;
        break;
      end
      @(posedge clk_i);
    end
    check(ok, $sformatf("tc9: cfg%0d RX timeout", c));

    // Step 2f: read RXD and verify loopback echo
    if (ok) begin
      cpu_read_32(UART_RXD_OFFSET, rdata, rresp);
      check(rresp == 2'b00, $sformatf("tc9: cfg%0d RXD read rresp", c));
      check((rdata[7:0] & rx_mask) == exp_data,
            $sformatf("tc9: cfg%0d loopback got=0x%02h exp=0x%02h", c, rdata[7:0] & rx_mask, exp_data));
    end

  end   // end configuration sweep

  // Step 3: restore
  wait_tx_done();
  uart_if.wait_till_idle();
  release u_uart_if.tx;                                                                      // release loopback before restoring config

  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);                                              // disable before CFG restore
  check(bresp == 2'b00, "tc9: restore disable CTRL");
  repeat (10) @(posedge clk_i);

  cpu_write_32(UART_CTRL_OFFSET, 32'h6, bresp);                                              // flush FIFOs to guarantee empty before CFG write
  check(bresp == 2'b00, "tc9: restore flush");
  repeat (20) @(posedge clk_i);

  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);                                              // clear flush bits
  check(bresp == 2'b00, "tc9: restore clear flush");
  repeat (20) @(posedge clk_i);

  cpu_write_32(UART_CFG_OFFSET, cfg0, bresp);                                                // restore CFG — FIFOs guaranteed empty now
  check(bresp == 2'b00, "tc9: restore UART_CFG");
  cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);                                              // restore CTRL
  check(bresp == 2'b00, "tc9: restore UART_CTRL");

  $display("TC9 DONE");

endtask                                                                                     // end tc9