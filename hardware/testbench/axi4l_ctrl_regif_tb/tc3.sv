// tc3.sv — TC3: CORE_CLK_RST Bit-Fields
//
// Writes 0x1, 0x2, 0x3, 0x0, 0xFFFF_FFFF to CORE_CLK_RST (0x028) in sequence.
// After each write:
//   - Reads back and verifies the written value
//   - Checks core_rst_en_o (bit 0) and core_clk_en_o (bit 1) sideband signals
//   - Verifies reserved bits [31:2] remain zero in readback
// -----------------------------------------------------------------------------
task automatic tc3(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC3: CORE_CLK_RST Bit-Fields --");

  // Helper: write → wait → read → check
  // Inline steps for each value to keep display context clear.

  // -------------------------------------------------------------------
  // Step 1: write 0x0000_0001  →  rst_en=1, clk_en=0
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), 32'h0000_0001, resp);
  check(resp === 2'b00, p, f, "CORE_CLK_RST write(0x1) resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  $display("  CORE_CLK_RST after write(0x1) = 0x%08h", rdata);
  check(resp              === 2'b00,  p, f, "CORE_CLK_RST read(0x1) resp=OKAY");
  check(rdata             === 32'h1,  p, f, "CORE_CLK_RST readback=0x1");
  check(core_rst_en_o     === 1'b1,   p, f, "core_rst_en_o=1 after write(0x1)");
  check(core_clk_en_o     === 1'b0,   p, f, "core_clk_en_o=0 after write(0x1)");
  check(rdata[31:2]       === 30'h0,  p, f, "reserved bits[31:2]=0 after write(0x1)");

  // -------------------------------------------------------------------
  // Step 2: write 0x0000_0002  →  rst_en=0, clk_en=1
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), 32'h0000_0002, resp);
  check(resp === 2'b00, p, f, "CORE_CLK_RST write(0x2) resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  $display("  CORE_CLK_RST after write(0x2) = 0x%08h", rdata);
  check(resp              === 2'b00,  p, f, "CORE_CLK_RST read(0x2) resp=OKAY");
  check(rdata             === 32'h2,  p, f, "CORE_CLK_RST readback=0x2");
  check(core_rst_en_o     === 1'b0,   p, f, "core_rst_en_o=0 after write(0x2)");
  check(core_clk_en_o     === 1'b1,   p, f, "core_clk_en_o=1 after write(0x2)");
  check(rdata[31:2]       === 30'h0,  p, f, "reserved bits[31:2]=0 after write(0x2)");

  // -------------------------------------------------------------------
  // Step 3: write 0x0000_0003  →  rst_en=1, clk_en=1
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), 32'h0000_0003, resp);
  check(resp === 2'b00, p, f, "CORE_CLK_RST write(0x3) resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  $display("  CORE_CLK_RST after write(0x3) = 0x%08h", rdata);
  check(resp              === 2'b00,  p, f, "CORE_CLK_RST read(0x3) resp=OKAY");
  check(rdata             === 32'h3,  p, f, "CORE_CLK_RST readback=0x3");
  check(core_rst_en_o     === 1'b1,   p, f, "core_rst_en_o=1 after write(0x3)");
  check(core_clk_en_o     === 1'b1,   p, f, "core_clk_en_o=1 after write(0x3)");
  check(rdata[31:2]       === 30'h0,  p, f, "reserved bits[31:2]=0 after write(0x3)");

  // -------------------------------------------------------------------
  // Step 4: write 0x0000_0000  →  rst_en=0, clk_en=0
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), 32'h0000_0000, resp);
  check(resp === 2'b00, p, f, "CORE_CLK_RST write(0x0) resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  $display("  CORE_CLK_RST after write(0x0) = 0x%08h", rdata);
  check(resp              === 2'b00,  p, f, "CORE_CLK_RST read(0x0) resp=OKAY");
  check(rdata             === 32'h0,  p, f, "CORE_CLK_RST readback=0x0");
  check(core_rst_en_o     === 1'b0,   p, f, "core_rst_en_o=0 after write(0x0)");
  check(core_clk_en_o     === 1'b0,   p, f, "core_clk_en_o=0 after write(0x0)");
  check(rdata[31:2]       === 30'h0,  p, f, "reserved bits[31:2]=0 after write(0x0)");

  // -------------------------------------------------------------------
  // Step 5: write 0xFFFF_FFFF  →  implemented bits set, reserved bits mask to zero
  // -------------------------------------------------------------------
  write_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), 32'hFFFF_FFFF, resp);
  check(resp === 2'b00, p, f, "CORE_CLK_RST write(0xFFFF_FFFF) resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_CORE_CLK_RST_OFFSET), rdata, resp);
  $display("  CORE_CLK_RST after write(0xFFFF_FFFF) = 0x%08h", rdata);
  check(resp              === 2'b00,        p, f, "CORE_CLK_RST read(0xFFFF_FFFF) resp=OKAY");
  check(rdata             === 32'h0000_0003, p, f, "CORE_CLK_RST masks reserved bits after all-ones write");
  check(core_rst_en_o     === 1'b1,         p, f, "core_rst_en_o=1 after write(0xFFFF_FFFF)");
  check(core_clk_en_o     === 1'b1,         p, f, "core_clk_en_o=1 after write(0xFFFF_FFFF)");
  check(rdata[31:2]       === 30'h0,        p, f, "reserved bits[31:2]=0 after write(0xFFFF_FFFF)");

endtask
