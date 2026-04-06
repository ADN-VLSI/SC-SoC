// tc0.sv - Reset & defaults
// Driver NOT running for TEST=0 — uses direct intf tasks only.
task automatic tc0(inout int p, inout int f);
  logic [31:0] data32;
  p = 0; f = 0;

  $display("TC0: Reset & defaults");

  // CFG reset default = 0x0003_405B
  read_32(UART_CFG_OFFSET, data32, 1000);
  $display("  CFG = 0x%0h", data32);
  if (data32 === 32'h0003_405B) p++;
  else begin $display("  CFG mismatch (got 0x%0h)", data32); f++; end

  // STAT smoke — any valid read accepted
  read_32(UART_STAT_OFFSET, data32, 1000);
  $display("  STAT = 0x%0h", data32);
  p++;

endtask