// tc8.sv — TC8: Partial Write Rejection
//
// Any write with strb != 4'b1111 must return SLVERR and leave the target
// register unchanged.  Tests six representative strb patterns against
// CORE_BOOT_ADDR (0x020).
//
// Before the test, CORE_BOOT_ADDR is set to a known canary value so that
// readbacks after rejected writes confirm no modification occurred.
// -----------------------------------------------------------------------------
task automatic tc8(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;

  // Canary value written before each partial-write attempt
  localparam logic [31:0] CANARY = 32'hA5A5_A5A5;

  // Six partial strobe patterns to exercise
  logic [3:0] strb_patterns [6] = '{
    4'b0001,   // byte 0 only
    4'b0011,   // bytes 0-1
    4'b0111,   // bytes 0-2
    4'b1110,   // bytes 1-3
    4'b1100,   // bytes 2-3
    4'b1000    // byte 3 only
  };

  p = 0; f = 0;

  $display("\n-- TC8: Partial Write Rejection --");

  foreach (strb_patterns[i]) begin : partial_write_loop
    automatic logic [3:0] strb    = strb_patterns[i];
    automatic logic [1:0] b_resp;
    automatic logic [1:0] r_resp;

    // Establish canary
    write_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), CANARY, resp);
    if (resp !== 2'b00)
      $display("  [WARN] canary write for strb=0b%04b returned resp=%0b", strb, resp);

    @(posedge clk_i);

    // Partial write
    fork
      send_aw_w(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), 32'hFFFF_FFFF, strb);
      intf.recv_b(b_resp);
    join

    $display("  strb=0b%04b  b.resp=%0b", strb, b_resp);
    check(b_resp === 2'b10, p, f,
          $sformatf("partial write (strb=0b%04b) resp=SLVERR", strb));

    // Readback — must still be CANARY
    read_32(reg_addr(CTRL_CORE_BOOT_ADDR_OFFSET), rdata, r_resp);
    check(rdata === CANARY, p, f,
          $sformatf("CORE_BOOT_ADDR unchanged after strb=0b%04b: 0x%0h", strb, rdata));
  end

endtask