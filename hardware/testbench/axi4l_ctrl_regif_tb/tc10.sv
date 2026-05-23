// tc10.sv — TC10: AXI FIFO Back-Pressure
//
// The internal axi4l_fifo has FIFO_SIZE=2 on every channel.
//
// Write path:
//   - Send 2 AW+W transactions to CORE_BOOT_ADDR while holding b_ready low
//     (not calling recv_b).  The B FIFO fills; aw_ready/w_ready then deassert
//     (inner logic stalls once B FIFO is full).
//   - Assert b_ready (call recv_b twice) and confirm both responses drain
//     with OKAY, in order.
//
// Read path:
//   - Send 2 AR transactions to CORE_HART_ID while holding r_ready low
//     (not calling recv_r).  The R FIFO fills; ar_ready then deasserts.
//   - Assert r_ready (call recv_r twice) and confirm both responses drain
//     with OKAY and the correct data.
//
// Note: FIFO_SIZE=2 constrains the queue depth.  Two transactions are used
//       to fill each FIFO without over-running it.
// -----------------------------------------------------------------------------
task automatic tc10(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp1, resp2;
  logic [33:0] r_bus1, r_bus2;
  logic [31:0] r_data1, r_data2;
  logic [1:0]  r_resp1, r_resp2;
  p = 0; f = 0;

  $display("\n-- TC10: AXI FIFO Back-Pressure --");

  // =========================================================================
  // Write path
  // =========================================================================
  // Pre-load CORE_BOOT_ADDR with a known starting value so we can verify
  // the last write landed correctly after drain.
  write_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), 32'h0000_0000, resp1);
  @(posedge clk_i);

  // Send 2 AW+W pairs, do NOT recv_b — b_ready stays deasserted (0).
  // The tasks send aw/w and return once aw_ready/w_ready pulse; they do
  // not touch b_ready.  B responses accumulate in the B FIFO.
  fork
    // Transaction 1
    send_aw_w(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), 32'hABCD_0001, 4'b1111);
  join
  $display("  Write tx[0] AW+W sent");

  fork
    // Transaction 2
    send_aw_w(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), 32'hABCD_0002, 4'b1111);
  join
  $display("  Write tx[1] AW+W sent");

  // Both B responses are buffered in the FIFO; drain now by asserting b_ready.
  intf.recv_b(resp1);
  intf.recv_b(resp2);

  $display("  Write B resp[0]=%0b  resp[1]=%0b", resp1, resp2);
  check(resp1 === 2'b00, p, f, "Write FIFO drain: tx[0] resp=OKAY");
  check(resp2 === 2'b00, p, f, "Write FIFO drain: tx[1] resp=OKAY");

  // Readback should show the last written value (0xABCD_0002)
  @(posedge clk_i);
  read_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), rdata, resp1);
  $display("  CORE_BOOT_ADDR after drain = 0x%08h", rdata);
  check(rdata === 32'hABCD_0002, p, f,
        $sformatf("CORE_BOOT_ADDR=0x%0h after write drain (exp 0xABCD0002)", rdata));

  // =========================================================================
  // Read path
  // =========================================================================
  // Pre-load CORE_HART_ID with a known value.
  write_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), 32'hBEEF_1234, resp1);
  @(posedge clk_i);

  // Send 2 AR transactions, do NOT recv_r — r_ready stays deasserted (0).
  // R responses (data + resp) accumulate in the R FIFO.
  fork
    intf.send_ar({reg_addr(CTRL_CORE_HART_ID_OFFSET), 3'h0});
  join
  $display("  Read  AR[0] sent");

  fork
    intf.send_ar({reg_addr(CTRL_CORE_HART_ID_OFFSET), 3'h0});
  join
  $display("  Read  AR[1] sent");

  // Drain R responses by asserting r_ready.
  intf.recv_r(r_bus1);
  intf.recv_r(r_bus2);

  r_data1 = r_bus1[33:2];  r_resp1 = r_bus1[1:0];
  r_data2 = r_bus2[33:2];  r_resp2 = r_bus2[1:0];

  $display("  Read  R resp[0]=%0b data[0]=0x%08h", r_resp1, r_data1);
  $display("  Read  R resp[1]=%0b data[1]=0x%08h", r_resp2, r_data2);

  check(r_resp1 === 2'b00,         p, f, "Read FIFO drain: tx[0] resp=OKAY");
  check(r_data1 === 32'hBEEF_1234, p, f,
        $sformatf("Read FIFO drain: tx[0] data=0x%0h (exp 0xBEEF1234)", r_data1));
  check(r_resp2 === 2'b00,         p, f, "Read FIFO drain: tx[1] resp=OKAY");
  check(r_data2 === 32'hBEEF_1234, p, f,
        $sformatf("Read FIFO drain: tx[1] data=0x%0h (exp 0xBEEF1234)", r_data2));

endtask
