// ============================================================================
// TC10 : Parity Flag Check
// Assigned : Adnan
//
// Objective:
//   Verify uart_tx generates correct parity bit on tx_o for both even and
//   odd parity modes across 4 data patterns: 0x55, 0xAA, 0xFF, 0x00.
//
// How:
//   Part A — Even parity (CFG_EVEN = 0x000741B0, pen=1 ptp=0):
//     1. Flush FIFOs, write CFG, enable TX+RX
//     2. Write byte to TXD
//     3. Wait for TX_EMPTY=1 (frame transmitted)
//     4. Wait for start bit on tx_o
//     5. Skip start + 8 data bits (9 * BITCY cycles)
//     6. Sample parity bit — check against ^tx_pat[i] (even XOR)
//
//   Part B — Odd parity (CFG_ODD = 0x000F41B0, pen=1 ptp=1):
//     Same flow, parity expected = ~(^tx_pat[i])
//
//   Restore original CFG and CTRL at end.
//
// Parity bit timing (at BITCY=864 cycles per bit):
//   start(1) + data(8) + parity(1) + stop(1) = 11 bits total
//   Parity bit sampled at: BITCY/2 + 9*BITCY after start bit negedge
// ============================================================================

task automatic tc10();
  logic [31:0] ctrl0, cfg0, stat, rdata;
  logic [1:0]  bresp, rresp;
  bit ok;
  int timeout;

  localparam int BITCY = 864;
  localparam int FRAME = 11; // 8E1/8O1: start + 8 data + parity + stop

  logic [7:0] tx_pat [4] = '{8'h55, 8'hAA, 8'hFF, 8'h00};

  localparam logic [31:0] CFG_EVEN = 32'h0007_41B0; // 8E1
  localparam logic [31:0] CFG_ODD  = 32'h000F_41B0; // 8O1

  $display("------------------------------------------------------------");
  $display("TC10: PARITY FLAG CHECK");
  $display("------------------------------------------------------------");

  cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);
  cpu_read_32(UART_CFG_OFFSET,  cfg0,  rresp);

  ////////////////////////////////////////////////////////////////////////////
  // part a: even parity
  ////////////////////////////////////////////////////////////////////////////

  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h6, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CFG_OFFSET, CFG_EVEN, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);
  repeat (BITCY * 4) @(posedge clk_i);

  for (int i = 0; i < 4; i++) begin
    cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);
    check(bresp == 2'b00, $sformatf("tc10 even tx[%0d]=0x%02h BRESP=OK", i, tx_pat[i]));

    // check tx_o level via u_uart_if.rx — parity bit is second-to-last bit
    // instead: verify parity bit on the wire by sampling at the right time
    // sample parity bit: start detected, wait start+data bits, sample parity
    // simpler: just verify data received correctly via RX loopback not available
    // so verify TX waveform directly
    // wait for start bit
  
    timeout = BITCY * FRAME * 2;
    while (timeout > 0 && u_uart_if.rx !== 1'b0) begin
      @(posedge clk_i);
      timeout--;
    end

    if (!timeout) begin
      check(0, $sformatf("tc10 odd no start[%0d]", i));
      continue;
    end

    // advance to mid-start
    repeat (BITCY / 2) @(posedge clk_i);
    // skip 8 data bits
    repeat (9 * BITCY) @(posedge clk_i);
    //$display("tc10 even parity sample[%0d] at %0t", i, $time);
    // now at mid-parity bit
    begin
      logic parity_got, parity_exp;
      parity_got = u_uart_if.rx;
      parity_exp = ^tx_pat[i]; // even parity
      check(parity_got === parity_exp,
            $sformatf("tc10 even parity[%0d] got=%0b exp=%0b",
                      i, parity_got, parity_exp));
    end

    // wait for stop bit + inter-frame gap
    repeat (BITCY * 2) @(posedge clk_i);
  end

  ////////////////////////////////////////////////////////////////////////////
  // part b: odd parity
  ////////////////////////////////////////////////////////////////////////////

  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h6, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CFG_OFFSET, CFG_ODD, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);
  repeat (BITCY * 4) @(posedge clk_i);

  for (int i = 0; i < 4; i++) begin
    cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);
    check(bresp == 2'b00, $sformatf("tc10 odd tx[%0d]=0x%02h BRESP=OK", i, tx_pat[i]));

    // wait for start bit
    timeout = BITCY * FRAME * 2;
    while (timeout > 0 && u_uart_if.rx !== 1'b0) begin
      @(posedge clk_i);
      timeout--;
    end

    if (!timeout) begin
      check(0, $sformatf("tc10 odd no start[%0d]", i));
      continue;
    end

    // advance to mid-start
    repeat (BITCY / 2) @(posedge clk_i);
    // skip 8 data bits
    repeat (9 * BITCY) @(posedge clk_i);
    // now at mid-parity bit
    begin
      logic parity_got, parity_exp;
      parity_got = u_uart_if.rx;
      parity_exp = ~(^tx_pat[i]); // odd parity
      check(parity_got === parity_exp,
            $sformatf("tc10 odd parity[%0d] got=%0b exp=%0b",
                      i, parity_got, parity_exp));
    end

    // wait for stop bit + inter-frame gap
    repeat (BITCY * 2) @(posedge clk_i);
  end

  ////////////////////////////////////////////////////////////////////////////
  // restore
  ////////////////////////////////////////////////////////////////////////////

  cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);
  repeat (20) @(posedge clk_i);
  cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp);
  cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);

endtask
