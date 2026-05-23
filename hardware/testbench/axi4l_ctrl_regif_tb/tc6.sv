// tc6.sv — TC6: BOOTMODE RO Write Protection + Live Sideband
//
// Verifies:
//   1. A write to BOOTMODE (0x080) returns SLVERR.
//   2. A read reflects the live value of bootmode_i on bit[0],
//      with bits[31:1] always zero.
//   3. Toggling bootmode_i and re-reading without any write updates the value.
// -----------------------------------------------------------------------------
task automatic tc6(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  p = 0; f = 0;

  $display("\n-- TC6: BOOTMODE Live Sideband + Write Protection --");

  // -------------------------------------------------------------------
  // Phase 1 — bootmode_i = 1: write attempt + live read
  // -------------------------------------------------------------------
  bootmode_i = 1'b1;
  @(posedge clk_i);  // allow sideband to propagate

  // Write attempt — must return SLVERR
  fork
    send_aw_w(reg_addr(CTRL_BOOTMODE_OFFSET), 32'hFFFF_FFFF, 4'b1111);
    intf.recv_b(resp);
  join
  $display("  BOOTMODE write resp  = 0b%02b", resp);
  check(resp === 2'b10, p, f, "BOOTMODE write resp=SLVERR");

  // Read — must reflect bootmode_i = 1
  read_32(reg_addr(CTRL_BOOTMODE_OFFSET), rdata, resp);
  $display("  BOOTMODE read (bootmode_i=1) = 0x%08h  resp=%0b", rdata, resp);
  check(resp       === 2'b00, p, f, "BOOTMODE read resp=OKAY (bootmode_i=1)");
  check(rdata[0]   === 1'b1,  p, f, "BOOTMODE[0]=1 matches bootmode_i=1");
  check(rdata[31:1]=== 31'h0, p, f, "BOOTMODE[31:1]=0 (reserved) when bootmode_i=1");

  // -------------------------------------------------------------------
  // Phase 2 — toggle bootmode_i to 0, re-read (no write in between)
  // -------------------------------------------------------------------
  bootmode_i = 1'b0;
  @(posedge clk_i);  // allow combinational read path to update

  read_32(reg_addr(CTRL_BOOTMODE_OFFSET), rdata, resp);
  $display("  BOOTMODE read (bootmode_i=0) = 0x%08h  resp=%0b", rdata, resp);
  check(resp       === 2'b00, p, f, "BOOTMODE read resp=OKAY (bootmode_i=0)");
  check(rdata[0]   === 1'b0,  p, f, "BOOTMODE[0]=0 matches bootmode_i=0");
  check(rdata[31:1]=== 31'h0, p, f, "BOOTMODE[31:1]=0 (reserved) when bootmode_i=0");

endtask