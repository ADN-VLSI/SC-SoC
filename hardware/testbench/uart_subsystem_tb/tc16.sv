task automatic tc16();
  logic [31:0] ctrl0, cfg0, rdata;
  logic [1:0]  bresp, rresp;
  bit          ok;

  localparam int NUM_BYTES = 8;
  localparam int RX_TIMEOUT_CYCLES = 10000; // much safer than 200

  logic [7:0] tx_pat [0:NUM_BYTES-1] = '{
    8'h00, 8'hFF, 8'h55, 8'hAA, 8'hA5, 8'h5A, 8'h01, 8'hFE
  };

  $display("------------------------------------------------------------");
  $display("TC16: LOOPBACK");
  $display("------------------------------------------------------------");

  // Save current config
  cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);
  check(rresp == 2'b00, "tc16: read UART_CTRL");
  cpu_read_32(UART_CFG_OFFSET, cfg0, rresp);
  check(rresp == 2'b00, "tc16: read UART_CFG");

  // Reset / configure
  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  check(bresp == 2'b00, "tc16: write UART_CTRL reset");
  repeat (20) @(posedge clk_i);

  cpu_write_32(UART_CFG_OFFSET, 32'h000341B0, bresp);
  check(bresp == 2'b00, "tc16: write UART_CFG");
  repeat (20) @(posedge clk_i);

  // NOTE: replace 32'h18 with the correct loopback/enable bits for your UART
  cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);
  check(bresp == 2'b00, "tc16: enable UART/loopback");
  repeat (STABILISE_CYCLES) @(posedge clk_i);

  for (int i = 0; i < NUM_BYTES; i++) begin
    cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);
    check(bresp == 2'b00,
          $sformatf("tc16: TX write failed idx %0d (0x%02h)", i, tx_pat[i]));

    // Wait for RX data to show up
    ok = 0;
    for (int t = 0; t < RX_TIMEOUT_CYCLES; t++) begin
      cpu_read_32(UART_RXD_OFFSET, rdata, rresp);
      if (rresp == 2'b00) begin
        ok = 1;
        break;
      end
      @(posedge clk_i);
    end

    check(ok, $sformatf("tc16: timeout waiting for RX byte idx %0d", i));
    if (ok) begin
      check(rdata[7:0] == tx_pat[i],
            $sformatf("tc16: loopback mismatch idx %0d got=0x%02h exp=0x%02h",
                      i, rdata[7:0], tx_pat[i]));
    end
  end

  // Restore original config
  cpu_write_32(UART_CFG_OFFSET, cfg0, bresp);
  check(bresp == 2'b00, "tc16: restore UART_CFG");
  cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);
  check(bresp == 2'b00, "tc16: restore UART_CTRL");

  $display("TC16 DONE");
endtask