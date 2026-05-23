// tc5.sv — TC5: RO Write Protection (SOC_ID / REV_ID / PLL_CFG)
//
// Issues a full-word (strb=4'b1111) write to each of the three constant RO
// registers using low-level send_aw_w tasks, records b.resp for each,
// then reads back to confirm values are unchanged.
//
// Expected: every write returns SLVERR (2'b10); every readback is unchanged.
// -----------------------------------------------------------------------------
task automatic tc5(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC5: RO Write Protection (SOC_ID / REV_ID / PLL_CFG) --");

  // -------------------------------------------------------------------
  // SOC_ID at offset 0x000
  // -------------------------------------------------------------------
  // Low-level write: AW + W only (recv_b follows manually)
  fork
    send_aw_w(reg_addr(CTRL_SOC_ID_OFFSET), 32'hFFFF_FFFF, 4'b1111);
    intf.recv_b(resp);
  join
  $display("  SOC_ID write resp = 0b%02b", resp);
  check(resp === 2'b10, p, f, "SOC_ID write resp=SLVERR");

  // Readback must be unchanged
  read_32(reg_addr(CTRL_SOC_ID_OFFSET), rdata, resp);
  $display("  SOC_ID readback   = 0x%08h", rdata);
  check(resp  === 2'b00,          p, f, "SOC_ID readback resp=OKAY");
  check(rdata === 32'h4467_0931,  p, f,
        $sformatf("SOC_ID unchanged: 0x%0h (exp 0x44670931)", rdata));

  // -------------------------------------------------------------------
  // REV_ID at offset 0x004
  // -------------------------------------------------------------------
  fork
    send_aw_w(reg_addr(CTRL_REV_ID_OFFSET), 32'hFFFF_FFFF, 4'b1111);
    intf.recv_b(resp);
  join
  $display("  REV_ID write resp = 0b%02b", resp);
  check(resp === 2'b10, p, f, "REV_ID write resp=SLVERR");

  read_32(reg_addr(CTRL_REV_ID_OFFSET), rdata, resp);
  $display("  REV_ID readback   = 0x%08h", rdata);
  check(resp  === 2'b00,          p, f, "REV_ID readback resp=OKAY");
  check(rdata === 32'h0000_0001,  p, f,
        $sformatf("REV_ID unchanged: 0x%0h (exp 0x00000001)", rdata));

  // -------------------------------------------------------------------
  // PLL_CFG at offset 0x040
  // -------------------------------------------------------------------
  fork
    send_aw_w(reg_addr(CTRL_PLL_CFG_OFFSET), 32'hFFFF_FFFF, 4'b1111);
    intf.recv_b(resp);
  join
  $display("  PLL_CFG write resp= 0b%02b", resp);
  check(resp === 2'b10, p, f, "PLL_CFG write resp=SLVERR");

  read_32(reg_addr(CTRL_PLL_CFG_OFFSET), rdata, resp);
  $display("  PLL_CFG readback  = 0x%08h", rdata);
  check(resp  === 2'b00,           p, f, "PLL_CFG readback resp=OKAY");
  check(rdata === 32'h0000_7D10,   p, f,
        $sformatf("PLL_CFG unchanged: 0x%0h (exp 0x00007D10)", rdata));

endtask