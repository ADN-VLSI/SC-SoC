// ============================================================================
// TC8 Architecture
// Author: "Motasim Faiyaz" <motasimfaiyaz@gmail.com> 
// TX write path used by this testcase:
//   AXI-Lite master -> axi4l_fifo -> axi4l_uart_regif -> TX CDC FIFO -> uart_tx -> u_uart_if
//
// STATUS.tx_cnt and STATUS.tx_full observe TX CDC FIFO occupancy only.
// They do not include a byte that has already been popped from the FIFO and
// loaded into `uart_tx`. Once TX is enabled, the next byte may already be in
// the serializer even though the FIFO count has dropped.
//
// Because of that pipeline boundary, this testcase checks:
//   1. Exact fill to FIFO depth while TX is disabled.
//   2. Overflow rejection with SLVERR and no count growth.
//   3. FIFO-order preservation on the first transmitted byte.
//   4. Deassertion of TX_FULL after draining starts, without assuming whether
//      the next byte is still in the FIFO or already in the transmitter.
// ============================================================================

localparam int TC8_FIFO_COUNT_W = $clog2(FIFO_DEPTH) + 1;
localparam logic [TC8_FIFO_COUNT_W:0] TC8_FIFO_DEPTH_EXT = (TC8_FIFO_COUNT_W + 1)'(FIFO_DEPTH);

//`include "methods/motasim.sv"

// ----------------------------------------------------------------------------
// AXI-Lite access helpers
// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------
// STATUS helper
// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------
// Wait until TX no longer reports full.
// ----------------------------------------------------------------------------

task automatic tc8_wait_for_tx_not_full(
  output bit  ok,
  input  int  timeout_cycles = 5000
);
  uart_stat_reg_t stat;
  bit             stat_ok;

  begin
    ok = 1'b0;
    repeat (timeout_cycles) begin
      tc8_read_stat(stat, stat_ok);
      if (stat_ok && !stat.tx_full) begin
        ok = 1'b1;
        return;
      end
      @(posedge clk_i);
    end
  end
endtask

// ----------------------------------------------------------------------------
// TX FIFO full / overflow testcase
// ----------------------------------------------------------------------------

task automatic tc8();
  uart_stat_reg_t stat;
  logic [1:0]     bresp;
  logic [7:0]     first_tx_byte;
  logic           first_tx_parity;
  logic [TC8_FIFO_COUNT_W:0] tx_count_ext;
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

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "Initial STATUS read completed");
    if (stat_ok) begin
      testcase_check((stat.tx_cnt === 10'd0) && stat.tx_empty && !stat.tx_full,
                     $sformatf("TX FIFO starts empty (tx_cnt=%0d tx_empty=%0b tx_full=%0b)",
                               stat.tx_cnt, stat.tx_empty, stat.tx_full));
    end else begin
      testcase_check(1'b0, "Initial STATUS contents unavailable");
      setup_ok = 1'b0;
    end

    // Fill exactly FIFO_DEPTH entries while TX is disabled so the FIFO cannot drain.
    if (setup_ok) begin
      for (int i = 0; i < FIFO_DEPTH; i++) begin
        tc8_write_32(UART_TXD_OFFSET, {24'h0, i[7:0]}, bresp);
        if (bresp !== 2'b00)
          setup_ok = 1'b0;

        // The empty flag must drop as soon as the first byte is stored in the FIFO.
        if ((i == 0) && (bresp === 2'b00)) begin
          tc8_read_stat(stat, stat_ok);
          testcase_check(stat_ok, "STATUS read after first stored TX byte completed");
          if (stat_ok) begin
            tx_count_ext = (TC8_FIFO_COUNT_W + 1)'(stat.tx_cnt);
            testcase_check(tx_count_ext === ((TC8_FIFO_COUNT_W + 1)'(1)),
                           $sformatf("STATUS.TX_CNT became 1 after first stored byte (tx_cnt=%0d)",
                                     stat.tx_cnt));
            testcase_check(!stat.tx_empty,
                           $sformatf("STATUS.TX_EMPTY deasserted after first stored byte (tx_empty=%0b)",
                                     stat.tx_empty));
            testcase_check(!stat.tx_full,
                           $sformatf("STATUS.TX_FULL remained deasserted after first stored byte (tx_full=%0b)",
                                     stat.tx_full));
          end else begin
            testcase_check(1'b0, "First-byte TX count check unavailable");
            testcase_check(1'b0, "First-byte TX_EMPTY check unavailable");
            testcase_check(1'b0, "First-byte TX_FULL check unavailable");
          end
        end
      end
      testcase_check(setup_ok,
                     $sformatf("Loaded exactly FIFO_DEPTH=%0d bytes into TX FIFO", FIFO_DEPTH));
    end else begin
      testcase_check(1'b0, "Skipped FIFO fill because setup did not complete");
    end

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "STATUS read after FIFO fill completed");
    if (stat_ok) begin
      tx_count_ext = (TC8_FIFO_COUNT_W + 1)'(stat.tx_cnt);
      testcase_check(tx_count_ext === TC8_FIFO_DEPTH_EXT,
                     $sformatf("STATUS.TX_CNT reached FIFO depth (%0d)", stat.tx_cnt));
      testcase_check(stat.tx_full,
                     $sformatf("STATUS.TX_FULL asserted at FIFO depth (tx_full=%0b)", stat.tx_full));
      testcase_check(!stat.tx_empty,
                     $sformatf("STATUS.TX_EMPTY deasserted after fill (tx_empty=%0b)", stat.tx_empty));
    end else begin
      testcase_check(1'b0, "Filled FIFO level unavailable");
      testcase_check(1'b0, "Filled FIFO full flag unavailable");
      testcase_check(1'b0, "Filled FIFO empty flag unavailable");
    end

    tc8_write_32(UART_TXD_OFFSET, 32'h0000_00FF, bresp);
    testcase_check(bresp === 2'b10,
                   $sformatf("Overflow write returned SLVERR as expected (BRESP=%0b)", bresp));

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "STATUS read after overflow write completed");
    if (stat_ok) begin
      tx_count_ext = (TC8_FIFO_COUNT_W + 1)'(stat.tx_cnt);
      testcase_check(tx_count_ext === TC8_FIFO_DEPTH_EXT,
                     $sformatf("Overflow write did not increase TX count beyond depth (tx_cnt=%0d)",
                               stat.tx_cnt));
    end else begin
      testcase_check(1'b0, "Overflow level check unavailable");
    end

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0008, bresp);
    testcase_check(bresp === 2'b00,
                   $sformatf("Enabled TX to drain one byte (BRESP=%0b)", bresp));

    u_uart_if.recv_rx(first_tx_byte, first_tx_parity, BAUD_RATE, 1'b0, 1'b0, 1'b0, 8);

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);
    testcase_check(bresp === 2'b00,
                   $sformatf("Disabled TX after first drained byte (BRESP=%0b)", bresp));

    tc8_wait_for_tx_not_full(wait_ok);
    testcase_check(wait_ok,
                   "STATUS.TX_FULL deasserted after draining started");

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "Final STATUS read completed");
    if (stat_ok) begin
      tx_count_ext = (TC8_FIFO_COUNT_W + 1)'(stat.tx_cnt);
      testcase_check(!stat.tx_full,
                     $sformatf("STATUS.TX_FULL deasserted after one byte drained (tx_full=%0b)",
                               stat.tx_full));
      testcase_check(tx_count_ext < TC8_FIFO_DEPTH_EXT,
                     $sformatf("Drain start reduced FIFO occupancy below full (tx_cnt=%0d)",
                               stat.tx_cnt));
    end else begin
      testcase_check(1'b0, "Final TX_FULL check unavailable");
      testcase_check(1'b0, "Final TX count check unavailable");
    end

    testcase_check(first_tx_byte === 8'h00,
                   $sformatf("First transmitted byte preserved FIFO order (got 0x%02h)",
                             first_tx_byte));
    testcase_end("TC8: TX FIFO Full test");

    // ---- SYNC counters with main TB ----
    total_pass += total_p;
    total_fail += total_f;
  end
endtask
