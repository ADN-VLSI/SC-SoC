// tc3.sv - Inject RX byte and read RXD offset
// rx_data_valid_i must remain high during the read cycle so DUT returns data.
task automatic tc3(inout int p, inout int f);
  logic [7:0]  inject;
  logic [31:0] read_back;
  p = 0; f = 0;

  $display("TC3: Inject RX byte and read RXD offset");

  inject = 8'h7A;

  rx_data_i.data       = inject;
  rx_data_valid_i      = 1'b1;
  rx_data_cnt_i.count  = 10'd1;
  @(posedge clk_i);

  // Read while valid still asserted — DUT returns the byte combinationally
  read_32(UART_RXD_OFFSET, read_back, 1000);

  rx_data_valid_i     = 1'b0;
  rx_data_cnt_i.count = '0;

  $display("  RXD read = 0x%0h (expected 0x%0h)", read_back[7:0], inject);
  if (read_back[7:0] === inject) begin
    $display("  RXD read OK"); p++;
  end else begin
    $display("  RXD read FAIL"); f++;
  end

endtask