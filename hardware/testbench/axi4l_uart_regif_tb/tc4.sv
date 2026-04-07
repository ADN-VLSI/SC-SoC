// tc4.sv - TX ID queue: push via TXR, peek via TXGP, pop via TXG
task automatic tc4(inout int p, inout int f);
  logic [31:0] r32;
  logic [7:0]  id;
  p = 0; f = 0;

  id = 8'h5A;
  $display("TC4: TX ID queue (TXR push -> TXGP peek -> TXG pop)");

  write_32(UART_TXR_OFFSET, {24'd0, id}, 1000);
  @(posedge clk_i);

  // Peek — should not consume
  read_32(UART_TXGP_OFFSET, r32, 1000);
  $display("  TXGP read = 0x%0h", r32[7:0]);
  if (r32[7:0] === id) begin $display("  TXGP peek OK"); p++; end
  else begin $display("  TXGP peek FAIL"); f++; end

  // Pop — should consume
  read_32(UART_TXG_OFFSET, r32, 1000);
  $display("  TXG read = 0x%0h", r32[7:0]);
  if (r32[7:0] === id) begin $display("  TXG pop OK"); p++; end
  else begin $display("  TXG pop FAIL"); f++; end

endtask