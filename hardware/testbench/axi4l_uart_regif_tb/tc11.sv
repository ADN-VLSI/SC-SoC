// tc11.sv - Concurrent AW/W and AR (overlap) - ensure both responses complete
task automatic tc11(output int p, output int f);
  bit [31:0] rdata;
  bit [1:0]  rresp;
  bit [1:0]  bresp;
  p = 0; f = 0;

  $display("TC11: Concurrent AW/W (TXD) and AR (STAT) overlap test");

  // Ensure TX path ready and counts cleared
  tx_data_ready_i = 1'b1;
  tx_data_cnt_i.count = 10'd0;
  rx_data_cnt_i.count = 10'd0;
  @(posedge clk_i);

  fork
    begin
      // Issue a TXD write (AW+W) and wait for B
      intf.send_aw({UART_TXD_OFFSET, 3'h0});
      intf.send_w({32'h0000_AA55, 4'b1111});
      intf.recv_b(bresp);
      $display("  TXD write B.resp = %0b", bresp);
    end
    begin
      // Issue AR for STAT concurrently and wait for R
      // small offset so AR starts slightly after AW to increase overlap chance
      @(posedge clk_i);
      intf.send_ar({UART_STAT_OFFSET, 3'h0});
      intf.recv_r({rdata, rresp});
      $display("  STAT read R.resp = %0b data=0x%0h", rresp, rdata);
    end
  join

  // Check both responses are OKAY (2'b00). If timing caused one to be SLVERR it's still a protocol issue, mark fail.
  if (bresp == 2'b00) begin
    $display("  TXD B.resp OKAY");
    p++;
  end else begin
    $display("  TXD B.resp not OKAY");
    f++;
  end

  if (rresp == 2'b00) begin
    $display("  STAT R.resp OKAY");
    p++;
  end else begin
    $display("  STAT R.resp not OKAY");
    f++;
  end

endtask