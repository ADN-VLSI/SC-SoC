// tc10.sv - Reads from empty queues/data should return SLVERR
task automatic tc10(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  rresp;
  p = 0; f = 0;

  $display("TC10: Read TXGP/TXG/RXGP/RXG/RXD when empty (expect SLVERR)");

  rx_data_valid_i     = 1'b0;
  tx_data_cnt_i.count = 10'd0;
  rx_data_cnt_i.count = 10'd0;
  @(posedge clk_i);

  // TXGP
  fork begin
    intf.send_ar({UART_TXGP_OFFSET[15:0], 3'h0});
    recv_r_with_timeout(rdata, rresp, 1000);
  end join
  $display("  TXGP resp=%0b", rresp);
  if (rresp == 2'b10) p++; else f++;

  // TXG
  fork begin
    intf.send_ar({UART_TXG_OFFSET[15:0], 3'h0});
    recv_r_with_timeout(rdata, rresp, 1000);
  end join
  $display("  TXG resp=%0b", rresp);
  if (rresp == 2'b10) p++; else f++;

  // RXGP
  fork begin
    intf.send_ar({UART_RXGP_OFFSET[15:0], 3'h0});
    recv_r_with_timeout(rdata, rresp, 1000);
  end join
  $display("  RXGP resp=%0b", rresp);
  if (rresp == 2'b10) p++; else f++;

  // RXG
  fork begin
    intf.send_ar({UART_RXG_OFFSET[15:0], 3'h0});
    recv_r_with_timeout(rdata, rresp, 1000);
  end join
  $display("  RXG resp=%0b", rresp);
  if (rresp == 2'b10) p++; else f++;

  // RXD (no rx_data_valid_i)
  fork begin
    intf.send_ar({UART_RXD_OFFSET[15:0], 3'h0});
    recv_r_with_timeout(rdata, rresp, 1000);
  end join
  $display("  RXD resp=%0b", rresp);
  if (rresp == 2'b10) p++; else f++;

endtask