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

task automatic tc8_read_stat(output uart_stat_reg_t stat);
  logic [31:0] stat_word;
  logic [1:0]  rresp;

  begin
    tc8_read_32(UART_STAT_OFFSET, stat_word, rresp);
    if (rresp !== 2'b00) begin
      $fatal(1, "TC8 failed to read UART_STAT, RRESP=%0b", rresp);
    end
    stat = stat_word;
  end
endtask

task automatic tc8_wait_for_tx_level(
  input int expected_level,
  input int timeout_cycles = 5000
);
  uart_stat_reg_t stat;

  begin
    repeat (timeout_cycles) begin
      tc8_read_stat(stat);
      if ((stat.tx_cnt == expected_level[9:0]) &&
          (stat.tx_empty == (expected_level == 0))) begin
        return;
      end
      @(posedge clk_i);
    end

    $fatal(1,
           "TC8 timeout waiting for TX level=%0d (last seen tx_cnt=%0d tx_full=%0b tx_empty=%0b)",
           expected_level, stat.tx_cnt, stat.tx_full, stat.tx_empty);
  end
endtask

task automatic tc8(); // TX FIFO Full test
  uart_stat_reg_t stat;
  logic [1:0]     bresp;
  logic [7:0]     first_tx_byte;
  logic           first_tx_parity;
  string          overflow_policy;

  begin
    $display("TC8: UART Subsystem - TX FIFO Full Test");

    reset_dut();

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);
    if (bresp !== 2'b00) begin
      $fatal(1, "TC8 failed to disable UART TX/RX, BRESP=%0b", bresp);
    end

    tc8_write_32(UART_CFG_OFFSET, 32'h0003_41B0, bresp);
    if (bresp !== 2'b00) begin
      $fatal(1, "TC8 failed to program UART_CFG, BRESP=%0b", bresp);
    end
    repeat (8) @(posedge clk_i);

    tc8_read_stat(stat);
    if (stat.tx_cnt !== 10'd0 || !stat.tx_empty || stat.tx_full) begin
      $fatal(1,
             "TC8 expected empty TX FIFO before fill, got tx_cnt=%0d tx_empty=%0b tx_full=%0b",
             stat.tx_cnt, stat.tx_empty, stat.tx_full);
    end

    for (int i = 0; i < FIFO_DEPTH; i++) begin
      tc8_write_32(UART_TXD_OFFSET, {24'h0, i[7:0]}, bresp);
      if (bresp !== 2'b00) begin
        $fatal(1, "TC8 fill write %0d failed with BRESP=%0b", i, bresp);
      end
    end

    tc8_read_stat(stat);
    if (stat.tx_cnt !== FIFO_DEPTH[9:0]) begin
      $fatal(1, "TC8 STATUS.TX_CNT expected %0d after fill, got %0d", FIFO_DEPTH, stat.tx_cnt);
    end
    if (!stat.tx_full) begin
      $fatal(1,
             "TC8 STATUS.TX_FULL did not assert at FIFO depth=%0d (tx_cnt=%0d). This suggests a full-threshold bug.",
             FIFO_DEPTH, stat.tx_cnt);
    end
    if (stat.tx_empty) begin
      $fatal(1, "TC8 STATUS.TX_EMPTY remained asserted after filling TX FIFO");
    end

    tc8_write_32(UART_TXD_OFFSET, 32'h0000_00FF, bresp);
    case (bresp)
      2'b10: overflow_policy = "drop-new with SLVERR";
      2'b00: overflow_policy = "silent drop with OKAY";
      default: begin
        $fatal(1, "TC8 overflow write returned unexpected BRESP=%0b", bresp);
      end
    endcase

    tc8_read_stat(stat);
    if (stat.tx_cnt !== FIFO_DEPTH[9:0]) begin
      $fatal(1, "TC8 overflow write changed TX level: expected %0d got %0d", FIFO_DEPTH, stat.tx_cnt);
    end

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0008, bresp);
    if (bresp !== 2'b00) begin
      $fatal(1, "TC8 failed to enable TX for drain, BRESP=%0b", bresp);
    end

    u_uart_if.recv_rx(first_tx_byte, first_tx_parity, BAUD_RATE, 1'b0, 1'b0, 1'b0, 8);

    tc8_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);
    if (bresp !== 2'b00) begin
      $fatal(1, "TC8 failed to disable TX after one drain, BRESP=%0b", bresp);
    end

    tc8_wait_for_tx_level(FIFO_DEPTH - 1);
    tc8_read_stat(stat);
    if (stat.tx_full) begin
      $fatal(1, "TC8 STATUS.TX_FULL did not deassert after one byte drained");
    end

    if (first_tx_byte !== 8'h00) begin
      $fatal(1, "TC8 first transmitted byte mismatch: got 0x%02h expected 0x00", first_tx_byte);
    end

    $display("TC8 overflow policy observed: %s", overflow_policy);
    $display("TC8 completed successfully");
  end
endtask
