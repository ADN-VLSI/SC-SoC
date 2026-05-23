// tc9.sv — TC9: Unmapped Address Handling
//
// Reads and writes to four unmapped offsets within the CTRL aperture must
// return SLVERR safely.  Read data from unmapped addresses must be 0x0.
//
// Offsets under test:
//   0x008 — hole between REV_ID (0x004) and CORE_BOOT_ADDR (0x020)
//   0x050 — hole between PLL_CFG (0x040) and TOHOST (0x060)
//   0x064 — interior hole between TOHOST (0x060) and FROMHOST (0x068)
//   0x0F0 — beyond all defined registers
// -----------------------------------------------------------------------------
task automatic tc9(inout int p, inout int f);
  logic [31:0] offsets [4] = '{
    32'h008,
    32'h050,
    32'h064,
    32'h0F0
  };

  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC9: Unmapped Address Handling --");

  foreach (offsets[i]) begin : unmapped_loop
    automatic logic [31:0] off  = offsets[i];
    automatic logic [31:0] addr = reg_addr(off);
    automatic logic [1:0]  w_resp, r_resp;
    automatic logic [31:0] r_data;

    // ------- Write -------
    fork
      send_aw_w(addr, 32'hFFFF_FFFF, 4'b1111);
      intf.recv_b(w_resp);
    join
    $display("  offset=0x%03h  write resp=0b%02b", off, w_resp);
    check(w_resp === 2'b10, p, f,
          $sformatf("unmapped write (0x%03h) resp=SLVERR", off));

    // ------- Read -------
    read_32(addr, r_data, r_resp);
    $display("  offset=0x%03h  read  resp=0b%02b  data=0x%08h", off, r_resp, r_data);
    check(r_resp === 2'b10,   p, f,
          $sformatf("unmapped read  (0x%03h) resp=SLVERR", off));
    check(r_data === 32'h0,   p, f,
          $sformatf("unmapped read  (0x%03h) data=0x0 (got 0x%0h)", off, r_data));
  end

endtask