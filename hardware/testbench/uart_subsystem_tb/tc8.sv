// TC8: TX FIFO Full Test
// Verifies TX FIFO fill behavior, overflow handling, and correct drain operation/order

//`include "methods/motasim.sv"

task automatic tc8_write_32(
  input  logic [31:0] addr,
  input  logic [31:0] data,
  output logic [1:0]  bresp
);
  begin
    cpu_write_32(addr, data, bresp); // AXI write transaction helper
  end
endtask

task automatic tc8_read_32(
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic [1:0]  rresp
);
  begin
    cpu_read_32(addr, data, rresp); // AXI read transaction helper
  end
endtask

task automatic tc8_read_stat(
  output uart_stat_reg_t stat,
  output bit             ok
);
  logic [31:0] stat_word;
  logic [1:0]  rresp;

  begin
    tc8_read_32(UART_STAT_OFFSET, stat_word, rresp); // Read STATUS register
    ok = (rresp === 2'b00);                          // Check read response OKAY
    stat = stat_word;                                // Cast to structured type
  end
endtask

task automatic tc8_wait_for_tx_level(
  input  int  expected_level,
  output bit  ok,
  input  int  timeout_cycles = 5000
);
  uart_stat_reg_t stat;
  bit             stat_ok;

  begin
    ok = 1'b0;
    repeat (timeout_cycles) begin
      tc8_read_stat(stat, stat_ok); // Poll STATUS register
      if (stat_ok &&
          (stat.tx_cnt == expected_level[9:0]) &&         // Check TX count reached expected level
          (stat.tx_empty == (expected_level == 0))) begin // Check TX empty flag consistency
        ok = 1'b1;
        return;
      end
      @(posedge clk_i); // Wait one cycle
    end
  end
endtask

task automatic tc8(); // TX FIFO Full test
  uart_stat_reg_t stat;
  logic [1:0]     bresp;
  logic [7:0]     first_tx_byte;
  logic           first_tx_parity;
  string          overflow_policy;
  bit             stat_ok;
  bit             wait_ok;
  bit             setup_ok;

  begin
    testcase_begin("TC8: TX FIFO Full test");
    reset_dut(); // Reset DUT to known state
    setup_ok = 1'b1;

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp); // Disable TX/RX
    testcase_check(bresp === 2'b00,
                   $sformatf("Disabled UART TX/RX before fill test (BRESP=%0b)", bresp));
    setup_ok &= (bresp === 2'b00);

    tc8_write_32(UART_CFG_OFFSET, 32'h0003_41B0, bresp); // Configure UART
    testcase_check(bresp === 2'b00,
                   $sformatf("Programmed UART_CFG for TX drain check (BRESP=%0b)", bresp));
    setup_ok &= (bresp === 2'b00);
    repeat (8) @(posedge clk_i); // Allow config to settle

    tc8_read_stat(stat, stat_ok); // Initial STATUS check
    testcase_check(stat_ok, "Initial STATUS read completed");
    if (stat_ok) begin
      testcase_check((stat.tx_cnt === 10'd0) && stat.tx_empty && !stat.tx_full,
                     $sformatf("TX FIFO starts empty (tx_cnt=%0d tx_empty=%0b tx_full=%0b)",
                               stat.tx_cnt, stat.tx_empty, stat.tx_full)); // Verify empty FIFO
    end else begin
      testcase_check(1'b0, "Initial STATUS contents unavailable");
      setup_ok = 1'b0;
    end

    if (setup_ok) begin
      for (int i = 0; i < FIFO_DEPTH; i++) begin
        tc8_write_32(UART_TXD_OFFSET, {24'h0, i[7:0]}, bresp); // Fill FIFO with known pattern
        if (bresp !== 2'b00)
          setup_ok = 1'b0;
      end
      testcase_check(setup_ok,
                     $sformatf("Loaded exactly FIFO_DEPTH=%0d bytes into TX FIFO", FIFO_DEPTH));
    end else begin
      testcase_check(1'b0, "Skipped FIFO fill because setup did not complete");
    end

    tc8_read_stat(stat, stat_ok); // Check FIFO full state
    testcase_check(stat_ok, "STATUS read after FIFO fill completed");
    if (stat_ok) begin
      testcase_check(stat.tx_cnt === FIFO_DEPTH[9:0], // Verify count equals depth
                     $sformatf("STATUS.TX_CNT reached FIFO depth (%0d)", stat.tx_cnt));
      testcase_check(stat.tx_full,                    // Verify full flag asserted
                     $sformatf("STATUS.TX_FULL asserted at FIFO depth (tx_full=%0b)", stat.tx_full));
      testcase_check(!stat.tx_empty,                  // Verify empty flag deasserted
                     $sformatf("STATUS.TX_EMPTY deasserted after fill (tx_empty=%0b)", stat.tx_empty));
    end else begin
      testcase_check(1'b0, "Filled FIFO level unavailable");
      testcase_check(1'b0, "Filled FIFO full flag unavailable");
      testcase_check(1'b0, "Filled FIFO empty flag unavailable");
    end

    tc8_write_32(UART_TXD_OFFSET, 32'h0000_00FF, bresp); // Overflow write attempt
    case (bresp)
      2'b10: overflow_policy = "drop-new with SLVERR";   // Error response
      2'b00: overflow_policy = "silent drop with OKAY";  // Accepted but ignored
      default: overflow_policy = $sformatf("unexpected BRESP=%0b", bresp);
    endcase
    testcase_check((bresp === 2'b10) || (bresp === 2'b00),
                   $sformatf("Overflow write returned supported response (%s)", overflow_policy));

    tc8_read_stat(stat, stat_ok); // Verify no overflow corruption
    testcase_check(stat_ok, "STATUS read after overflow write completed");
    if (stat_ok) begin
      testcase_check(stat.tx_cnt === FIFO_DEPTH[9:0], // Count must not exceed depth
                     $sformatf("Overflow write did not increase TX count beyond depth (tx_cnt=%0d)",
                               stat.tx_cnt));
    end else begin
      testcase_check(1'b0, "Overflow level check unavailable");
    end

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0008, bresp); // Enable TX (start draining)
    testcase_check(bresp === 2'b00,
                   $sformatf("Enabled TX to drain one byte (BRESP=%0b)", bresp));

    u_uart_if.recv_rx(first_tx_byte, first_tx_parity, BAUD_RATE, 1'b0, 1'b0, 1'b0, 8); // Capture first transmitted byte

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp); // Disable TX after one byte
    testcase_check(bresp === 2'b00,
                   $sformatf("Disabled TX after first drained byte (BRESP=%0b)", bresp));

    tc8_wait_for_tx_level(FIFO_DEPTH - 1, wait_ok); // Wait until one byte drained
    testcase_check(wait_ok,
                   $sformatf("TX FIFO level dropped to %0d after one drain", FIFO_DEPTH - 1));

    tc8_read_stat(stat, stat_ok); // Final STATUS check
    testcase_check(stat_ok, "Final STATUS read completed");
    if (stat_ok) begin
      testcase_check(!stat.tx_full, // Full flag must deassert after drain
                     $sformatf("STATUS.TX_FULL deasserted after one byte drained (tx_full=%0b)",
                               stat.tx_full));
    end else begin
      testcase_check(1'b0, "Final TX_FULL check unavailable");
    end

    testcase_check(first_tx_byte === 8'h00, // Verify FIFO order (first-in-first-out)
                   $sformatf("First transmitted byte preserved FIFO order (got 0x%02h)",
                             first_tx_byte));

    $display("TC8 overflow policy observed: %s", overflow_policy);
    testcase_end("TC8: TX FIFO Full test");

    // ---- SYNC counters with main TB ----
    total_pass += total_p;
    total_fail += total_f;
  end
endtask