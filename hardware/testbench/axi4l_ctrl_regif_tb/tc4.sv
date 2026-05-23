// tc4.sv — TC4: PLL_CFG Bit-Field Assembly
//
// PLL_CFG (offset 0x040) is a read-only register that returns the constant
// CTRL_PLL_CFG_RESET = 32'h0000_0C90.
//
// Bit-field layout (from ctrl_reg.md):
//   [4:0]   REF_DIV  = 5'h10  (16 decimal)
//   [18:5]  FB_DIV   = 14'h3E8 (1000 decimal)
//   [31:19] RESERVED = 0
//
// The test reads PLL_CFG twice and verifies:
//   - Both reads return OKAY and the constant
//   - bits [4:0]   match expected REF_DIV  (5'h10)
//   - bits [18:5]  match expected FB_DIV   (14'h3E8)
//   - bits [31:19] are always zero
// -----------------------------------------------------------------------------
task automatic tc4(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;

  // Expected field values derived from the constant 0x00000C90
  localparam logic [4:0]  EXP_REF_DIV  = 5'h10;
  localparam logic [13:0] EXP_FB_DIV   = 14'h3E8;

  p = 0; f = 0;

  $display("\n-- TC4: PLL_CFG Bit-Field Assembly --");

  // -------------------------------------------------------------------
  // Read #1
  // -------------------------------------------------------------------
  read_32(reg_addr(CTRL_PLL_CFG_OFFSET), rdata, resp);
  $display("  PLL_CFG read[0] = 0x%08h  resp=%0b", rdata, resp);

  check(resp            === 2'b00,        p, f, "PLL_CFG read[0] resp=OKAY");
  check(rdata           === 32'h0000_0C90, p, f,
        $sformatf("PLL_CFG read[0] full value: 0x%0h (exp 0x00000C90)", rdata));
  check(rdata[4:0]      === EXP_REF_DIV,  p, f,
        $sformatf("PLL_CFG[4:0]  REF_DIV=0x%0h (exp 0x%0h)", rdata[4:0], EXP_REF_DIV));
  check(rdata[18:5]     === EXP_FB_DIV,   p, f,
        $sformatf("PLL_CFG[18:5] FB_DIV=0x%0h (exp 0x%0h)", rdata[18:5], EXP_FB_DIV));
  check(rdata[31:19]    === 13'h0,         p, f, "PLL_CFG[31:19] reserved=0 read[0]");

  // -------------------------------------------------------------------
  // Read #2 — result must be identical (idempotent constant register)
  // -------------------------------------------------------------------
  read_32(reg_addr(CTRL_PLL_CFG_OFFSET), rdata, resp);
  $display("  PLL_CFG read[1] = 0x%08h  resp=%0b", rdata, resp);

  check(resp            === 2'b00,        p, f, "PLL_CFG read[1] resp=OKAY");
  check(rdata[4:0]      === EXP_REF_DIV,  p, f,
        $sformatf("PLL_CFG[4:0]  REF_DIV=0x%0h (exp 0x%0h)", rdata[4:0], EXP_REF_DIV));
  check(rdata[18:5]     === EXP_FB_DIV,   p, f,
        $sformatf("PLL_CFG[18:5] FB_DIV=0x%0h (exp 0x%0h)", rdata[18:5], EXP_FB_DIV));
  check(rdata[31:19]    === 13'h0,         p, f, "PLL_CFG[31:19] reserved=0 read[1]");

endtask