// tc1.sv — TC1: RO Constant Reads
//
// Verifies SOC_ID (0x000) and REV_ID (0x004) always return their fixed
// values regardless of how many times they are read.
// -----------------------------------------------------------------------------
task automatic tc1(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC1: RO Constant Reads --");

  // SOC_ID — read #1
  read_32(reg_addr(CTRL_SOC_ID_OFFSET), rdata, resp);
  $display("  SOC_ID (1st read) = 0x%08h  resp=%0b", rdata, resp);
  check(resp  === 2'b00,          p, f, "SOC_ID[0] resp=OKAY");
  check(rdata === 32'h4467_0931,  p, f,
        $sformatf("SOC_ID[0]=0x%0h (exp 0x44670931)", rdata));

  // SOC_ID — read #2 (must be identical)
  read_32(reg_addr(CTRL_SOC_ID_OFFSET), rdata, resp);
  $display("  SOC_ID (2nd read) = 0x%08h  resp=%0b", rdata, resp);
  check(resp  === 2'b00,          p, f, "SOC_ID[1] resp=OKAY");
  check(rdata === 32'h4467_0931,  p, f,
        $sformatf("SOC_ID[1]=0x%0h (exp 0x44670931)", rdata));

  // REV_ID — read #1
  read_32(reg_addr(CTRL_REV_ID_OFFSET), rdata, resp);
  $display("  REV_ID (1st read) = 0x%08h  resp=%0b", rdata, resp);
  check(resp  === 2'b00,          p, f, "REV_ID[0] resp=OKAY");
  check(rdata === 32'h0000_0001,  p, f,
        $sformatf("REV_ID[0]=0x%0h (exp 0x00000001)", rdata));

  // REV_ID — read #2 (must be identical)
  read_32(reg_addr(CTRL_REV_ID_OFFSET), rdata, resp);
  $display("  REV_ID (2nd read) = 0x%08h  resp=%0b", rdata, resp);
  check(resp  === 2'b00,          p, f, "REV_ID[1] resp=OKAY");
  check(rdata === 32'h0000_0001,  p, f,
        $sformatf("REV_ID[1]=0x%0h (exp 0x00000001)", rdata));

endtask