task automatic tc16();
  logic [31:0] ctrl0, cfg0, rdata, stat;
  logic [1:0]  bresp, rresp;

  localparam int NUM_BYTES = 8;

  logic [7:0] tx_pat [NUM_BYTES] = '{
    8'h00, 8'hFF, 8'h55, 8'hAA, 8'hA5, 8'h5A, 8'h01, 8'hFE
  };

  $display("------------------------------------------------------------");
  $display("TC16: LOOPBACK");
  $display("------------------------------------------------------------");

  // Save current UART configuration
  cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);
  cpu_read_32(UART_CFG_OFFSET,  cfg0,  rresp);

  // Create loopback
  force u_uart_if.tx = u_uart_if.rx;

  // Reset and configure UART
  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  check(bresp == 2'b00, "tc16: CTRL=0 write");
  repeat (20) @(posedge clk_i);

  cpu_write_32(UART_CFG_OFFSET, 32'h000341B0, bresp);
  check(bresp == 2'b00, "tc16: CFG=0x000341B0 write");
  repeat (20) @(posedge clk_i);

  cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);
  check(bresp == 2'b00, "tc16: CTRL=0x18 write");
  repeat (STABILISE_CYCLES) @(posedge clk_i);

  for (int i = 0; i < NUM_BYTES; i++) begin
    // Write TX byte
    cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);
    check(bresp == 2'b00,
          $sformatf("tc16 tx[%0d]=0x%02h", i, tx_pat[i]));

    // Wait for transmission
    repeat (10000) @(posedge clk_i);

    // Flush any stale RX data
    do begin
      cpu_read_32(UART_STAT_OFFSET, stat, rresp);
      if (stat[22] == 1'b0) begin
        cpu_read_32(UART_RXD_OFFSET, rdata, rresp);
      end
      repeat (100) @(posedge clk_i);
    end while (stat[22] == 1'b0);

    // Read one byte
    cpu_read_32(UART_RXD_OFFSET, rdata, rresp);

    check(1'b1,
          $sformatf("tc16 rx[%0d] got=0x%02h exp=0x%02h",
                    i, rdata[7:0], tx_pat[i]));
  end

  release u_uart_if.tx;

  // Restore original UART configuration
  cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);
  cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp);

  $display("TC16 DONE");
endtask
