// tc9.sv - UART_STAT empty/full flags and count fields
task automatic tc9(inout int p, inout int f);
  logic [31:0] stat;
  p = 0; f = 0;

  $display("TC9: UART_STAT empty/full and count fields");

  // Case A: counts = 0 -> tx_empty=1, rx_empty=1, tx_full=0, rx_full=0
  tx_data_cnt_i.count = 10'd0;
  rx_data_cnt_i.count = 10'd0;
  @(posedge clk_i);
  read_32(UART_STAT_OFFSET, stat, 1000);
  $display("  STAT (counts=0) = 0x%0h", stat);
  if (stat[9:0]  == 10'd0   && stat[19:10] == 10'd0 &&
      stat[20]   == 1'b1    && stat[22]    == 1'b1   &&
      stat[21]   == 1'b0    && stat[23]    == 1'b0) begin
    $display("  STAT empty flags OK"); p++;
  end else begin
    $display("  STAT empty flags FAIL (tx_cnt=%0d rx_cnt=%0d tx_empty=%0b rx_empty=%0b tx_full=%0b rx_full=%0b)",
             stat[9:0], stat[19:10], stat[20], stat[22], stat[21], stat[23]);
    f++;
  end

  // Case B: counts = 512 -> tx_full=1, rx_full=1
  tx_data_cnt_i.count = 10'd512;
  rx_data_cnt_i.count = 10'd512;
  @(posedge clk_i);
  read_32(UART_STAT_OFFSET, stat, 1000);
  $display("  STAT (counts=512) = 0x%0h", stat);
  if (stat[9:0]  == 10'd512 && stat[19:10] == 10'd512 &&
      stat[21]   == 1'b1    && stat[23]    == 1'b1) begin
    $display("  STAT full flags OK"); p++;
  end else begin
    $display("  STAT full flags FAIL (tx_cnt=%0d rx_cnt=%0d tx_full=%0b rx_full=%0b)",
             stat[9:0], stat[19:10], stat[21], stat[23]);
    f++;
  end

endtask