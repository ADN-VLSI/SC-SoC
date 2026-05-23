// tc0.sv — TC0: Reset Behaviour
//
// Verifies:
//   1. AXI ready/valid lines are deasserted during reset.
//   2. Sideband outputs hold documented reset values while arst_ni = 0.
//   3. All RW registers read back their reset defaults after reset release.
// -----------------------------------------------------------------------------
task automatic tc0(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC0: Reset Behaviour --");

  // -------------------------------------------------------------------------
  // Phase 1 — drive reset, sample DUT outputs immediately
  // -------------------------------------------------------------------------
  arst_ni <= 1'b0;
  intf.req_reset();
  repeat (5) @(posedge clk_i);

  // AXI ready signals must be deasserted during reset
  check(dut_resp.aw_ready === 1'b0, p, f, "aw_ready deasserted during reset");
  check(dut_resp.w_ready  === 1'b0, p, f, "w_ready  deasserted during reset");
  check(dut_resp.ar_ready === 1'b0, p, f, "ar_ready deasserted during reset");
  check(dut_resp.b_valid  === 1'b0, p, f, "b_valid  deasserted during reset");
  check(dut_resp.r_valid  === 1'b0, p, f, "r_valid  deasserted during reset");

  // Sideband outputs during reset
  check(core_boot_addr_o === 32'h4000_0000, p, f,
        $sformatf("core_boot_addr_o=0x%0h during reset (exp 0x40000000)", core_boot_addr_o));
  check(core_hart_id_o   === 32'h0000_0000, p, f,
        $sformatf("core_hart_id_o=0x%0h during reset (exp 0)", core_hart_id_o));
  check(tohost_o         === 32'h0000_0000, p, f,
        $sformatf("tohost_o=0x%0h during reset (exp 0)", tohost_o));
  check(fromhost_o       === 32'h0000_0000, p, f,
        $sformatf("fromhost_o=0x%0h during reset (exp 0)", fromhost_o));
  check(core_rst_en_o    === 1'b0,          p, f, "core_rst_en_o=0 during reset");
  check(core_clk_en_o    === 1'b0,          p, f, "core_clk_en_o=0 during reset");

  // -------------------------------------------------------------------------
  // Phase 2 — release reset, wait for DUT to stabilise
  // -------------------------------------------------------------------------
  arst_ni <= 1'b1;
  repeat (5) @(posedge clk_i);

  // -------------------------------------------------------------------------
  // Phase 3 — read back every RW register; compare to documented reset values
  // -------------------------------------------------------------------------

  // CORE_BOOT_ADDR: reset = 0x4000_0000
  read_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00,          p, f, "CORE_BOOT_ADDR read resp=OKAY");
  check(rdata === 32'h4000_0000,  p, f,
        $sformatf("CORE_BOOT_ADDR=0x%0h (exp 0x40000000)", rdata));

  // CORE_HART_ID: reset = 0x0000_0000
  read_32(reg_addr(CTRL_CORE_HART_ID_OFFSET), rdata, resp);
  check(resp  === 2'b00,         p, f, "CORE_HART_ID read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f,
        $sformatf("CORE_HART_ID=0x%0h (exp 0)", rdata));

  // CORE_CLK_RST: reset = 0x0000_0000
  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  check(resp  === 2'b00,         p, f, "CORE_CLK_RST read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f,
        $sformatf("CORE_CLK_RST=0x%0h (exp 0)", rdata));

  // TOHOST: reset = 0x0000_0000
  read_32(reg_addr(CTRL_TOHOST_OFFSET), rdata, resp);
  check(resp  === 2'b00,         p, f, "TOHOST read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f,
        $sformatf("TOHOST=0x%0h (exp 0)", rdata));

  // FROMHOST: reset = 0x0000_0000
  read_32(reg_addr(CTRL_FROMHOST_OFFSET), rdata, resp);
  check(resp  === 2'b00,         p, f, "FROMHOST read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f,
        $sformatf("FROMHOST=0x%0h (exp 0)", rdata));

endtask