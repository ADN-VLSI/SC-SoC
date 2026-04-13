//`include "methods/motasim.sv"

task automatic tc8_write_32(
  input  logic [31:0] addr,
  input  logic [31:0] data,
  output logic [1:0]  bresp
);
  begin
    cpu_write_32(addr, data, bresp);
  end
endtask

task automatic tc8_read_32(
  input  logic [31:0] addr,
  output logic [31:0] data,
  output logic [1:0]  rresp
);
  begin
    cpu_read_32(addr, data, rresp);
  end
endtask

task automatic tc8_read_stat(
  output uart_stat_reg_t stat,
  output bit             ok
);
  logic [31:0] stat_word;
  logic [1:0]  rresp;

  begin
    tc8_read_32(UART_STAT_OFFSET, stat_word, rresp);
    ok = (rresp === 2'b00);
    stat = stat_word;
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
      tc8_read_stat(stat, stat_ok);
      if (stat_ok &&
          (stat.tx_cnt == expected_level[9:0]) &&
          (stat.tx_empty == (expected_level == 0))) begin
        ok = 1'b1;
        return;
      end
      @(posedge clk_i);
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
    testcase_begin("TC8");
    reset_dut();
    setup_ok = 1'b1;

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);
    testcase_check(bresp === 2'b00,
                   $sformatf("Disabled UART TX/RX before fill test (BRESP=%0b)", bresp));
    setup_ok &= (bresp === 2'b00);

    tc8_write_32(UART_CFG_OFFSET, 32'h0003_41B0, bresp);
    testcase_check(bresp === 2'b00,
                   $sformatf("Programmed UART_CFG for TX drain check (BRESP=%0b)", bresp));
    setup_ok &= (bresp === 2'b00);
    repeat (8) @(posedge clk_i);

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

    if (setup_ok) begin
      for (int i = 0; i < FIFO_DEPTH; i++) begin
        tc8_write_32(UART_TXD_OFFSET, {24'h0, i[7:0]}, bresp);
        if (bresp !== 2'b00)
          setup_ok = 1'b0;
      end
      testcase_check(setup_ok,
                     $sformatf("Loaded exactly FIFO_DEPTH=%0d bytes into TX FIFO", FIFO_DEPTH));
    end else begin
      testcase_check(1'b0, "Skipped FIFO fill because setup did not complete");
    end

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "STATUS read after FIFO fill completed");
    if (stat_ok) begin
      testcase_check(stat.tx_cnt === FIFO_DEPTH[9:0],
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
    case (bresp)
      2'b10: overflow_policy = "drop-new with SLVERR";
      2'b00: overflow_policy = "silent drop with OKAY";
      default: overflow_policy = $sformatf("unexpected BRESP=%0b", bresp);
    endcase
    testcase_check((bresp === 2'b10) || (bresp === 2'b00),
                   $sformatf("Overflow write returned supported response (%s)", overflow_policy));

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "STATUS read after overflow write completed");
    if (stat_ok) begin
      testcase_check(stat.tx_cnt === FIFO_DEPTH[9:0],
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

    tc8_wait_for_tx_level(FIFO_DEPTH - 1, wait_ok);
    testcase_check(wait_ok,
                   $sformatf("TX FIFO level dropped to %0d after one drain", FIFO_DEPTH - 1));

    tc8_read_stat(stat, stat_ok);
    testcase_check(stat_ok, "Final STATUS read completed");
    if (stat_ok) begin
      testcase_check(!stat.tx_full,
                     $sformatf("STATUS.TX_FULL deasserted after one byte drained (tx_full=%0b)",
                               stat.tx_full));
    end else begin
      testcase_check(1'b0, "Final TX_FULL check unavailable");
    end

    testcase_check(first_tx_byte === 8'h00,
                   $sformatf("First transmitted byte preserved FIFO order (got 0x%02h)",
                             first_tx_byte));

    $display("TC8 overflow policy observed: %s", overflow_policy);
    testcase_end();
  end
endtask
