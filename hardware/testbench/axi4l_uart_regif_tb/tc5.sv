// tc5.sv - RX ID queue: push via RXR, peek via RXGP, pop via RXG
task automatic tc5(inout int p, inout int f);
  logic [31:0] r32;
  logic [7:0]  id;
  p = 0; f = 0;

  id = 8'h3C;
  $display("TC5: RX ID queue (RXR push -> RXGP peek -> RXG pop)");

  write_32(UART_RXR_OFFSET, {24'd0, id}, 1000);
  @(posedge clk_i);

  // Peek
  read_32(UART_RXGP_OFFSET, r32, 1000);
  $display("  RXGP = 0x%0h", r32[7:0]);
  if (r32[7:0] === id) p++; else f++;

  // Pop
  read_32(UART_RXG_OFFSET, r32, 1000);
  $display("  RXG = 0x%0h", r32[7:0]);
  if (r32[7:0] === id) p++; else f++;

endtask