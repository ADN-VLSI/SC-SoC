// tc7.sv — TC7: TOHOST / FROMHOST Independence
//
// Verifies:
//   1. TOHOST (0x060) and FROMHOST (0x068) store values independently.
//   2. Sideband outputs (tohost_o / fromhost_o) match AXI readbacks.
//   3. Writing to one register does not alter the other.
// -----------------------------------------------------------------------------
task automatic tc7(inout int p, inout int f);
  logic [31:0] rdata_th, rdata_fh;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC7: TOHOST / FROMHOST Independence --");

  // -------------------------------------------------------------------
  // Round 1 — write distinct values to both registers
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_TOHOST_OFFSET),   32'hCAFE_BABE, resp);
  check(resp === 2'b00, p, f, "TOHOST write[0] resp=OKAY");

  write_32(reg_addr(CTRL_FROMHOST_OFFSET), 32'hDEAD_BEEF, resp);
  check(resp === 2'b00, p, f, "FROMHOST write[0] resp=OKAY");

  @(posedge clk_i);

  // Readback both
  read_32(reg_addr(CTRL_TOHOST_OFFSET),   rdata_th, resp);
  check(resp     === 2'b00,         p, f, "TOHOST read[0] resp=OKAY");
  check(rdata_th === 32'hCAFE_BABE, p, f,
        $sformatf("TOHOST readback[0]=0x%0h (exp 0xCAFEBABE)", rdata_th));

  read_32(reg_addr(CTRL_FROMHOST_OFFSET), rdata_fh, resp);
  check(resp     === 2'b00,         p, f, "FROMHOST read[0] resp=OKAY");
  check(rdata_fh === 32'hDEAD_BEEF, p, f,
        $sformatf("FROMHOST readback[0]=0x%0h (exp 0xDEADBEEF)", rdata_fh));

  // Sideband checks
  check(tohost_o   === rdata_th, p, f,
        $sformatf("tohost_o sideband[0]=0x%0h", tohost_o));
  check(fromhost_o === rdata_fh, p, f,
        $sformatf("fromhost_o sideband[0]=0x%0h", fromhost_o));

  // No cross-contamination
  check(rdata_th !== rdata_fh, p, f, "TOHOST != FROMHOST (no cross-contamination)");

  // -------------------------------------------------------------------
  // Round 2 — update TOHOST only; FROMHOST must be unchanged
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_TOHOST_OFFSET), 32'h1111_2222, resp);
  check(resp === 2'b00, p, f, "TOHOST write[1] resp=OKAY");

  @(posedge clk_i);

  read_32(reg_addr(CTRL_TOHOST_OFFSET),   rdata_th, resp);
  check(rdata_th === 32'h1111_2222, p, f,
        $sformatf("TOHOST updated[1]=0x%0h (exp 0x11112222)", rdata_th));

  read_32(reg_addr(CTRL_FROMHOST_OFFSET), rdata_fh, resp);
  check(rdata_fh === 32'hDEAD_BEEF, p, f,
        $sformatf("FROMHOST unchanged after TOHOST write: 0x%0h", rdata_fh));

  // -------------------------------------------------------------------
  // Round 3 — update FROMHOST only; TOHOST must be unchanged
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_FROMHOST_OFFSET), 32'h3333_4444, resp);
  check(resp === 2'b00, p, f, "FROMHOST write[1] resp=OKAY");

  @(posedge clk_i);

  read_32(reg_addr(CTRL_TOHOST_OFFSET),   rdata_th, resp);
  check(rdata_th === 32'h1111_2222, p, f,
        $sformatf("TOHOST unchanged after FROMHOST write: 0x%0h", rdata_th));

  read_32(reg_addr(CTRL_FROMHOST_OFFSET), rdata_fh, resp);
  check(rdata_fh === 32'h3333_4444, p, f,
        $sformatf("FROMHOST updated[1]=0x%0h (exp 0x33334444)", rdata_fh));

  // Final sideband checks
  check(tohost_o   === rdata_th, p, f,
        $sformatf("tohost_o sideband[1]=0x%0h", tohost_o));
  check(fromhost_o === rdata_fh, p, f,
        $sformatf("fromhost_o sideband[1]=0x%0h", fromhost_o));

endtask