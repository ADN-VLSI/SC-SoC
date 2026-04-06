// tc6.sv - Partial write should be rejected (SLVERR)
// Uses write_32 indirectly — but we need the raw bresp, so drive intf directly.
// Driver IS running; use write_32 and rely on DUT returning SLVERR in B.
// To capture bresp we use a low-level fork inside this task.
task automatic tc6(inout int p, inout int f);
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic [1:0]  bresp;
  p = 0; f = 0;

  $display("TC6: Partial write rejection (strb != 4'b1111 -> SLVERR)");

  wdata = 32'hDEAD_BEEF;
  wstrb = 4'b0011;   // partial strobe

  fork
    begin
      intf.send_aw({UART_CTRL_OFFSET[15:0], 3'h0});
      intf.send_w({wdata, wstrb});
      recv_b_with_timeout(bresp, 1000);
    end
  join

  $display("  B.resp = %0b", bresp);
  if (bresp == 2'b10) begin $display("  SLVERR as expected"); p++; end
  else begin $display("  Unexpected B.resp"); f++; end

  @(posedge clk_i);
endtask