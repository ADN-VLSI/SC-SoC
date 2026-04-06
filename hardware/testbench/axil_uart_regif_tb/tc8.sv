// tc8.sv - UART_INT_EN write and readback
task automatic tc8(inout int p, inout int f);
  logic [31:0] rdata;
  logic [31:0] wr_val;
  p = 0; f = 0;

  wr_val = 32'h0000_000F;
  $display("TC8: UART_INT_EN write and readback");

  write_32(UART_INT_EN_OFFSET, wr_val, 1000);
  @(posedge clk_i);

  read_32(UART_INT_EN_OFFSET, rdata, 1000);
  $display("  INT_EN read = 0x%0h (expected 0x%0h)", rdata, wr_val);
  if (rdata === wr_val) begin $display("  INT_EN readback OK"); p++; end
  else begin $display("  INT_EN readback FAIL"); f++; end

endtask