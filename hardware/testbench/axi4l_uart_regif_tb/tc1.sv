// tc1.sv - Write UART_CTRL and readback
task automatic tc1(inout int p, inout int f);
  logic [31:0] rdata;
  p = 0; f = 0;

  $display("TC1: CTRL write/readback");

  write_32(UART_CTRL_OFFSET, 32'hA5A5_F00D, 1000);
  @(posedge clk_i);

  read_32(UART_CTRL_OFFSET, rdata, 1000);
  $display("  CTRL read = 0x%0h", rdata);
  if (rdata === 32'hA5A5_F00D) p++;
  else begin $display("  CTRL readback fail (got 0x%0h)", rdata); f++; end

endtask