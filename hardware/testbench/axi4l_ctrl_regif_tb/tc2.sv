// tc2.sv — TC2: RW Write / Readback
//
// Verifies CORE_BOOT_ADDR (0x020) and CORE_HART_ID (0x024):
//   - Write returns OKAY
//   - AXI readback matches written value
//   - Sideband outputs (core_boot_addr_o / core_hart_id_o) match readback
//   - A second distinct write + readback cycle confirms update
// -----------------------------------------------------------------------------
task automatic tc2(inout int p, inout int f);
  logic [31:0] wdata, rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC2: RW Write / Readback --");

  // -----------------------------------------------------------------------
  // Round 1 — initial distinct values
  // -----------------------------------------------------------------------
  wdata = 32'hDEAD_C0DE;

  // Write CORE_BOOT_ADDR
  write_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), wdata, resp);
  check(resp === 2'b00, p, f, "CORE_BOOT_ADDR write[0] resp=OKAY");

  // One cycle pipeline delay for register output update
  @(posedge clk_i);

  // AXI readback
  read_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), rdata, resp);
  $display("  CORE_BOOT_ADDR readback[0] = 0x%08h", rdata);
  check(resp  === 2'b00, p, f, "CORE_BOOT_ADDR read[0] resp=OKAY");
  check(rdata === wdata,  p, f,
        $sformatf("CORE_BOOT_ADDR AXI match[0]: 0x%0h vs 0x%0h", rdata, wdata));

  // Sideband
  check(core_boot_addr_o === rdata, p, f,
        $sformatf("core_boot_addr_o sideband[0]: 0x%0h", core_boot_addr_o));

  // Write CORE_HART_ID
  wdata = 32'h0000_0042;
  write_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), wdata, resp);
  check(resp === 2'b00, p, f, "CORE_HART_ID write[0] resp=OKAY");

  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), rdata, resp);
  $display("  CORE_HART_ID readback[0] = 0x%08h", rdata);
  check(resp  === 2'b00, p, f, "CORE_HART_ID read[0] resp=OKAY");
  check(rdata === wdata,  p, f,
        $sformatf("CORE_HART_ID AXI match[0]: 0x%0h vs 0x%0h", rdata, wdata));
  check(core_hart_id_o === rdata, p, f,
        $sformatf("core_hart_id_o sideband[0]: 0x%0h", core_hart_id_o));

  // -----------------------------------------------------------------------
  // Round 2 — different values to confirm update
  // -----------------------------------------------------------------------
  wdata = 32'hBAAD_F00D;
  write_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), wdata, resp);
  check(resp === 2'b00, p, f, "CORE_BOOT_ADDR write[1] resp=OKAY");

  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), rdata, resp);
  $display("  CORE_BOOT_ADDR readback[1] = 0x%08h", rdata);
  check(resp  === 2'b00, p, f, "CORE_BOOT_ADDR read[1] resp=OKAY");
  check(rdata === wdata,  p, f,
        $sformatf("CORE_BOOT_ADDR AXI match[1]: 0x%0h vs 0x%0h", rdata, wdata));
  check(core_boot_addr_o === rdata, p, f,
        $sformatf("core_boot_addr_o sideband[1]: 0x%0h", core_boot_addr_o));

  wdata = 32'h0000_0001;
  write_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), wdata, resp);
  check(resp === 2'b00, p, f, "CORE_HART_ID write[1] resp=OKAY");

  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), rdata, resp);
  $display("  CORE_HART_ID readback[1] = 0x%08h", rdata);
  check(resp  === 2'b00, p, f, "CORE_HART_ID read[1] resp=OKAY");
  check(rdata === wdata,  p, f,
        $sformatf("CORE_HART_ID AXI match[1]: 0x%0h vs 0x%0h", rdata, wdata));
  check(core_hart_id_o === rdata, p, f,
        $sformatf("core_hart_id_o sideband[1]: 0x%0h", core_hart_id_o));

endtask