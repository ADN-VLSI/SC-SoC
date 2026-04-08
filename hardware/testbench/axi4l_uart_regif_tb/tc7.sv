// tc7.sv - CFG write constraints and TX backpressure
task automatic tc7(inout int p, inout int f);
  logic [31:0] wdata;
  logic [1:0]  bresp;
  p = 0; f = 0;

  $display("TC7: CFG write constraints and TX backpressure");

  // Part A: CFG write rejected when tx_count != 0
  tx_data_cnt_i.count = 10'd1;
  rx_data_cnt_i.count = 10'd0;
  @(posedge clk_i);
  fork
    begin
      intf.send_aw({UART_CFG_OFFSET[15:0], 3'h0});
      intf.send_w({32'h0000_1234, 4'b1111});
      recv_b_with_timeout(bresp, 1000);
    end
  join
  $display("  CFG write (tx_count!=0) B.resp = %0b", bresp);
  if (bresp == 2'b10) p++;
  else begin $display("  CFG write allowed unexpectedly"); f++; end

  // Part B: CFG write accepted when both counts are zero
  tx_data_cnt_i.count = 10'd0;
  rx_data_cnt_i.count = 10'd0;
  @(posedge clk_i);
  fork
    begin
      intf.send_aw({UART_CFG_OFFSET[15:0], 3'h0});
      intf.send_w({32'h0000_5678, 4'b1111});
      recv_b_with_timeout(bresp, 1000);
    end
  join
  $display("  CFG write (counts=0) B.resp = %0b", bresp);
  if (bresp == 2'b00) p++;
  else begin $display("  CFG write rejected unexpectedly"); f++; end

  // Part C: TXD write with tx_data_ready_i=0 -> SLVERR
  tx_data_ready_i = 1'b0;
  @(posedge clk_i);
  fork
    begin
      intf.send_aw({UART_TXD_OFFSET[15:0], 3'h0});
      intf.send_w({32'h0000_00AB, 4'b1111});
      recv_b_with_timeout(bresp, 1000);
    end
  join
  $display("  TXD write (ready=0) B.resp = %0b", bresp);
  if (bresp == 2'b10) p++;
  else begin $display("  TXD accepted despite backpressure"); f++; end

  tx_data_ready_i = 1'b1;
  @(posedge clk_i);

endtask