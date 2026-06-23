`timescale 1ns / 1ps
//==============================================================================
// tb_plic.sv
//
// Self-checking testbench for `plic`.
//
// Bus protocol notes (reverse-engineered from the RTL, not a standard bus):
//   Write : drive waddr_i/wdata_i/wstrb_i/wnsecure_i, hold wenable_i=1 across
//           one posedge clk_i. werror_o is combinational on
//           {wnsecure_i,waddr_i,wstrb_i} and is valid as soon as those are
//           driven (no wait needed to sample it). The register only updates
//           on the clk edge if wenable_i & ~werror_o.
//   Read  : drive raddr_i/rnsecure_i, rdata_o/rerror_o are pure combinational
//           outputs (no clock needed).
//
// This TB intentionally mixes:
//   - Black-box checks through the register interface + ei_o/eiid_o
//   - White-box checks via hierarchical refs (dut.<signal>) to root-cause
//     mismatches down to the exact internal node, and force/release to
//     isolate the priority encoder from upstream bugs.
//
// Result tagging:
//   [PASS]        - behaved as the RISC-V-PLIC-style spec / register map intends
//   [FAIL]        - unexpected mismatch, not previously characterized
//   [BUG]         - mismatch matches a bug already root-caused below (see header
//                   comment block before each TC)
//   [BUG-FIXED?]  - a bug_expected check unexpectedly matched -> DUT changed,
//                   re-audit this TC
//==============================================================================

module plic_testbench;

  //----------------------------------------------------------------
  // Mirrors of the DUT's fixed localparams (can't be overridden at
  // instantiation since the DUT declares them as localparam in the
  // parameter port list)
  //----------------------------------------------------------------
  localparam int ADDR_WIDTH = 22;
  localparam int DATA_WIDTH = 32;
  localparam int NUM_CORES = 2;
  localparam int MAX_PRIORITY = 7;
  localparam int NUM_INTERRUPTS = 33;
  localparam int PLIC_ADDR_WIDTH = 6;  // $clog2(33)
  localparam int PRIO_BITS = 3;  // $clog2(MAX_PRIORITY+1)

  // Register map addresses (from the spec table)
  localparam logic [21:0] ADDR_RESERVED = 22'h000000;
  // Plain array (not localparam) populated in an initial block below -
  // some SV-2012 toolchains are inconsistent about unpacked-array literal
  // assignment inside a localparam declaration, so this sidesteps that.
  logic [21:0] ADDR_PRIO[1:32];
  localparam logic [21:0] ADDR_EN_3100_C0 = 22'h002000;
  localparam logic [21:0] ADDR_EN_6332_C0 = 22'h002004;
  localparam logic [21:0] ADDR_EN_3100_C1 = 22'h002080;
  localparam logic [21:0] ADDR_EN_6332_C1 = 22'h002084;
  localparam logic [21:0] ADDR_THRESH_C0 = 22'h200000;
  localparam logic [21:0] ADDR_CLAIM_C0 = 22'h200004;
  localparam logic [21:0] ADDR_THRESH_C1 = 22'h201000;
  localparam logic [21:0] ADDR_CLAIM_C1 = 22'h201004;

  // dut.sv: `werror_o = (wstrb_i == '1)` for every mapped register - this is
  // an INVERTED polarity bug. A fully-enabled strobe (4'hF, the value any
  // normal 32-bit-aligned CPU store would use) is flagged as an ERROR and
  // the write is dropped; any NON-full strobe pattern is accepted instead.
  // There is also no per-byte masking anywhere in the write-update block -
  // an accepted write always commits the entire 32-bit wdata_i regardless
  // of which strobe bits were set, including wstrb_i==4'h0. See TC2B below,
  // which characterizes this directly and is the single highest-impact bug
  // in this design: it silently drops every "normal" full-word register
  // write a real bus master would issue.
  //
  // STRB_FULL    = the spec-correct value ordinary stores would use (rejected by the bug)
  // STRB_WORKING = a non-full pattern this AS-BUILT DUT actually accepts
  // All setup writes elsewhere in this TB use STRB_WORKING and call that out
  // inline; STRB_FULL is used only where a test is specifically checking
  // strobe handling.
  localparam logic [3:0] STRB_FULL = 4'hF;
  localparam logic [3:0] STRB_WORKING = 4'hE;

  //----------------------------------------------------------------
  // DUT I/O
  //----------------------------------------------------------------
  logic arst_ni;
  logic clk_i;

  logic [ADDR_WIDTH-1:0] waddr_i;
  logic wnsecure_i;
  logic [DATA_WIDTH-1:0] wdata_i;
  logic [DATA_WIDTH/8-1:0] wstrb_i;
  logic wenable_i;
  logic werror_o;

  logic [ADDR_WIDTH-1:0] raddr_i;
  logic rnsecure_i;
  logic [DATA_WIDTH-1:0] rdata_o;
  logic rerror_o;

  logic [NUM_INTERRUPTS-1:0] irq_i;

  logic [NUM_CORES-1:0][PLIC_ADDR_WIDTH-1:0] eiid_o;
  logic [NUM_CORES-1:0] ei_o;
  // Shared scratch var for tasks that don't need their error result
  logic dummy_err;

  //----------------------------------------------------------------
  // DUT instantiation
  //----------------------------------------------------------------
  plic dut (
      .arst_ni(arst_ni),
      .clk_i  (clk_i),

      .waddr_i   (waddr_i),
      .wnsecure_i(wnsecure_i),
      .wdata_i   (wdata_i),
      .wstrb_i   (wstrb_i),
      .wenable_i (wenable_i),
      .werror_o  (werror_o),

      .raddr_i   (raddr_i),
      .rnsecure_i(rnsecure_i),
      .rdata_o   (rdata_o),
      .rerror_o  (rerror_o),

      .irq_i(irq_i),

      .eiid_o(eiid_o),
      .ei_o  (ei_o)
  );

  initial begin
    ADDR_PRIO[1] = 22'h000004;
    ADDR_PRIO[2] = 22'h000008;
    ADDR_PRIO[3] = 22'h00000C;
    ADDR_PRIO[4] = 22'h000010;
    ADDR_PRIO[5] = 22'h000014;
    ADDR_PRIO[6] = 22'h000018;
    ADDR_PRIO[7] = 22'h00001C;
    ADDR_PRIO[8] = 22'h000020;
    ADDR_PRIO[9] = 22'h000024;
    ADDR_PRIO[10] = 22'h000028;
    ADDR_PRIO[11] = 22'h00002C;
    ADDR_PRIO[12] = 22'h000030;
    ADDR_PRIO[13] = 22'h000034;
    ADDR_PRIO[14] = 22'h000038;
    ADDR_PRIO[15] = 22'h00003C;
    ADDR_PRIO[16] = 22'h000040;
    ADDR_PRIO[17] = 22'h000044;
    ADDR_PRIO[18] = 22'h000048;
    ADDR_PRIO[19] = 22'h00004C;
    ADDR_PRIO[20] = 22'h000050;
    ADDR_PRIO[21] = 22'h000054;
    ADDR_PRIO[22] = 22'h000058;
    ADDR_PRIO[23] = 22'h00005C;
    ADDR_PRIO[24] = 22'h000060;
    ADDR_PRIO[25] = 22'h000064;
    ADDR_PRIO[26] = 22'h000068;
    ADDR_PRIO[27] = 22'h00006C;
    ADDR_PRIO[28] = 22'h000070;
    ADDR_PRIO[29] = 22'h000074;
    ADDR_PRIO[30] = 22'h000078;
    ADDR_PRIO[31] = 22'h00007C;
    ADDR_PRIO[32] = 22'h000080;
  end

  //----------------------------------------------------------------
  // Clock
  //----------------------------------------------------------------
  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;  // 100MHz

  //----------------------------------------------------------------
  // Scoreboard / pass-fail bookkeeping
  //----------------------------------------------------------------
  int pass_cnt = 0;
  int fail_cnt = 0;
  int bug_confirmed_cnt = 0;
  int bug_fixed_cnt = 0;

  task automatic check(string name, logic [31:0] exp, logic [31:0] act, bit bug_expected = 0);
    if (exp === act) begin
      if (bug_expected) begin
        bug_fixed_cnt++;
        $display("[BUG-FIXED?] %-62s exp=0x%08h act=0x%08h  <- previously-known-bad case now matches; re-audit", name, exp, act);
      end else begin
        pass_cnt++;
        $display("[PASS]       %-62s exp=0x%08h act=0x%08h", name, exp, act);
      end
    end else begin
      if (bug_expected) begin
        bug_confirmed_cnt++;
        $display("[BUG]        %-62s exp=0x%08h act=0x%08h  <- matches known DUT bug", name, exp, act);
      end else begin
        fail_cnt++;
        $display("[FAIL]       %-62s exp=0x%08h act=0x%08h", name, exp, act);
      end
    end
  endtask

  task automatic print_summary();
    $display("==============================================================");
    $display(" PASS=%0d  FAIL=%0d  BUG-CONFIRMED=%0d  BUG-FIXED?=%0d", pass_cnt,
              fail_cnt, bug_confirmed_cnt, bug_fixed_cnt);
    $display("==============================================================");
    if (fail_cnt != 0) $display("RESULT: UNEXPECTED FAILURES PRESENT");
    else $display("RESULT: only known-bug confirmations (if any) - see [BUG] lines above");
  endtask

  //----------------------------------------------------------------
  // BFM tasks
  //----------------------------------------------------------------
  task automatic reset_dut();
    arst_ni = 1'b0;
    wenable_i = 1'b0;
    waddr_i = '0;
    wdata_i = '0;
    wstrb_i = '0;
    wnsecure_i = 1'b0;
    raddr_i = '0;
    rnsecure_i = 1'b0;
    irq_i = '0;
    repeat (3) @(posedge clk_i);
    @(negedge clk_i);
    arst_ni = 1'b1;
    @(posedge clk_i);
  endtask

  // Returns werror_o sampled at drive time (combinational, before the edge
  // that performs the actual update).
  task automatic plic_write(input logic [21:0] addr, input logic [31:0] data,
                             input logic [3:0] strb = 4'hF, input logic nsecure = 1'b0,
                             output logic err);
    @(negedge clk_i);
    waddr_i = addr;
    wdata_i = data;
    wstrb_i = strb;
    wnsecure_i = nsecure;
    wenable_i = 1'b1;
    #1;
    err = werror_o;
    @(posedge clk_i);
    #1;
    wenable_i = 1'b0;
  endtask

  task automatic plic_read(input logic [21:0] addr, input logic nsecure = 1'b0,
                            output logic [31:0] data, output logic err);
    raddr_i = addr;
    rnsecure_i = nsecure;
    #1;
    data = rdata_o;
    err = rerror_o;
  endtask

  // Forces a rising edge on irq_i[idx] so the per-bit gateway latch
  // (dut: always_ff @(posedge irq_i[i] or posedge irq_claim[i] ...)) fires.
  task automatic pulse_irq_rise(input int idx);
    irq_i[idx] = 1'b0;
    #1;
    irq_i[idx] = 1'b1;
    #1;
  endtask

  //==============================================================
  // TC1 - Reset defaults: every mapped register reads back 0, no errors
  //==============================================================
  task automatic tc1_reset_defaults();
    logic [31:0] data;
    logic err;
    $display("\n--- TC1: reset defaults ---");
    reset_dut();
    for (int i = 1; i <= 32; i++) begin
      plic_read(ADDR_PRIO[i], 1'b0, data, err);
      check($sformatf("TC1 intr_src_%0d_prio reset value", i), 32'h0, data);
      check($sformatf("TC1 intr_src_%0d_prio reset err", i), 1'b0, err);
    end
    plic_read(ADDR_EN_3100_C0, 1'b0, data, err);
    check("TC1 enable_src3100_core_0 reset value", 32'h0, data);
    plic_read(ADDR_EN_6332_C0, 1'b0, data, err);
    check("TC1 enable_src6332_core_0 reset value", 32'h0, data);
    plic_read(ADDR_EN_3100_C1, 1'b0, data, err);
    check("TC1 enable_src3100_core_1 reset value", 32'h0, data);
    plic_read(ADDR_EN_6332_C1, 1'b0, data, err);
    check("TC1 enable_src6332_core_1 reset value", 32'h0, data);
    plic_read(ADDR_THRESH_C0, 1'b0, data, err);
    check("TC1 core_0_threshold reset value", 32'h0, data);
    plic_read(ADDR_CLAIM_C0, 1'b0, data, err);
    check("TC1 claim_id_core_0 reset value", 32'h0, data);
    plic_read(ADDR_THRESH_C1, 1'b0, data, err);
    check("TC1 core_1_threshold reset value", 32'h0, data);
    plic_read(ADDR_CLAIM_C1, 1'b0, data, err);
    check("TC1 claim_id_core_1 reset value", 32'h0, data);
  endtask

  //==============================================================
  // TC2 - Reserved address 0x000000: read and write both error
  //==============================================================
  task automatic tc2_reserved_addr();
    logic [31:0] data;
    logic err;
    $display("\n--- TC2: reserved offset 0x000000 ---");
    reset_dut();
    plic_read(ADDR_RESERVED, 1'b0, data, err);
    check("TC2 read 0x000000 rerror_o", 1'b1, err);
    check("TC2 read 0x000000 rdata_o", 32'h0, data);
    plic_write(ADDR_RESERVED, 32'hDEAD_BEEF, 4'hF, 1'b0, err);
    check("TC2 write 0x000000 werror_o", 1'b1, err);
  endtask

  //==============================================================
  // TC2B - BUG: write-strobe error polarity is inverted (see header comment
  //   above STRB_FULL/STRB_WORKING). This is checked FIRST, before any other
  //   TC relies on writes succeeding, so the rest of this file can use
  //   STRB_WORKING deliberately and explain why.
  //==============================================================
  task automatic tc2b_strobe_polarity_bug();
    logic [31:0] data;
    logic err;
    $display("\n--- TC2B [BUG HUNT]: write-strobe werror_o polarity ---");
    reset_dut();
    // Spec-correct expectation: a full strobe (all bytes valid) succeeds.
    plic_write(ADDR_PRIO[1], 32'h0000_0005, STRB_FULL, 1'b0, err);
    check("TC2B full strobe (4'hF) werror_o", 1'b0, err, 1'b1);  // expect bug: err=1
    plic_read(ADDR_PRIO[1], 1'b0, data, err);
    check("TC2B register unchanged after rejected full-strobe write", 32'h5, data,
          1'b1);  // expect bug: stays 0

    // The same write succeeds if any single strobe bit is dropped.
    plic_write(ADDR_PRIO[1], 32'h0000_0005, STRB_WORKING, 1'b0, err);
    check("TC2B near-full strobe (4'hE) werror_o", 1'b0, err);
    plic_read(ADDR_PRIO[1], 1'b0, data, err);
    check("TC2B register updated by near-full-strobe write", 32'h5, data);

    // No per-byte masking exists in the write-update logic at all: even a
    // ZERO strobe is "accepted" (werror_o low) and still commits the full
    // word, because the update path never looks at wstrb_i.
    plic_write(ADDR_PRIO[2], 32'h0000_0003, 4'h0, 1'b0, err);
    check("TC2B zero strobe (4'h0) werror_o", 1'b0, err);
    plic_read(ADDR_PRIO[2], 1'b0, data, err);
    check("TC2B register updated by zero-strobe write (no byte masking exists)", 32'h3, data);
  endtask

  //==============================================================
  // TC3/TC4 - Priority registers: full address sweep + 3-bit truncation
  //   Storage is `logic [PRIO_BITS-1:0] intr_src_XX_prio` (3 bits, since
  //   MAX_PRIORITY=7) fed directly by `wdata_i` (32 bits) -> upper 29 bits
  //   are silently dropped on write. This is by construction, not a bug,
  //   but firmware needs to know writes alias modulo 8.
  //==============================================================
  task automatic tc3_priority_sweep();
    logic [31:0] data;
    logic err;
    $display("\n--- TC3: priority register address sweep ---");
    reset_dut();
    for (int i = 1; i <= 32; i++) begin
      plic_write(ADDR_PRIO[i], i[2:0], STRB_WORKING, 1'b0, err);  // STRB_FULL is rejected, see TC2B
      check($sformatf("TC3 write intr_src_%0d_prio werror_o", i), 1'b0, err);
    end
    for (int i = 1; i <= 32; i++) begin
      plic_read(ADDR_PRIO[i], 1'b0, data, err);
      check($sformatf("TC3 readback intr_src_%0d_prio", i), {29'b0, i[2:0]}, data);
    end
  endtask

  task automatic tc4_priority_truncation();
    logic [31:0] data;
    logic err;
    $display("\n--- TC4: priority register truncation (3-bit storage) ---");
    reset_dut();
    plic_write(ADDR_PRIO[1], 32'hFFFF_FFFF, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_PRIO[1], 1'b0, data, err);
    check("TC4 intr_src_01_prio write 0xFFFFFFFF -> readback", 32'h0000_0007, data);
    plic_write(ADDR_PRIO[1], 32'h0000_0008, STRB_WORKING, 1'b0, err);  // bit3 set, bits[2:0]=0
    plic_read(ADDR_PRIO[1], 1'b0, data, err);
    check("TC4 intr_src_01_prio write 0x8 -> readback (wraps to 0)", 32'h0000_0000, data);
  endtask

  //==============================================================
  // TC5 - Enable registers: full 32-bit storage, no truncation expected
  //==============================================================
  task automatic tc5_enable_sweep();
    logic [31:0] data;
    logic err;
    $display("\n--- TC5: enable register read/write (full width) ---");
    reset_dut();
    plic_write(ADDR_EN_3100_C0, 32'hA5A5_A5A5, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_EN_3100_C0, 1'b0, data, err);
    check("TC5 enable_src3100_core_0 readback", 32'hA5A5_A5A5, data);

    plic_write(ADDR_EN_6332_C0, 32'h5A5A_5A5A, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_EN_6332_C0, 1'b0, data, err);
    check("TC5 enable_src6332_core_0 readback", 32'h5A5A_5A5A, data);

    plic_write(ADDR_EN_3100_C1, 32'hFFFF_FFFF, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_EN_3100_C1, 1'b0, data, err);
    check("TC5 enable_src3100_core_1 readback", 32'hFFFF_FFFF, data);

    plic_write(ADDR_EN_6332_C1, 32'h0000_0001, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_EN_6332_C1, 1'b0, data, err);
    check("TC5 enable_src6332_core_1 readback", 32'h0000_0001, data);
  endtask

  //==============================================================
  // TC6 - BUG: enabled_irq_core_X width mismatch
  //   dut: enabled_irq_core_0 = irq_q & {enable_src6332_core_0, enable_src3100_core_0}
  //   irq_q is 33 bits; the concat on the RHS is 64 bits. SV self-determines
  //   the AND's width as 64, zero-extends irq_q, then the 64-bit result is
  //   truncated to 33 bits on assignment. Net effect: enable_src3100_core_0
  //   gates sources [31:0] as intended, but only BIT 0 of
  //   enable_src6332_core_0 has any effect at all (it happens to land on
  //   source 32); bits [31:1] of enable_src6332_core_0 are dead - they can
  //   be written/read back fine but never gate anything.
  //==============================================================
  task automatic tc6_enable_dead_bits_bug();
    logic [31:0] data;
    logic err;
    $display("\n--- TC6 [BUG HUNT]: enable_src6332_core_0 dead-bit truncation ---");
    reset_dut();
    // Source 32 pending, gate it with enable_src6332_core_0 bit 0 only.
    plic_write(ADDR_EN_6332_C0, 32'h0000_0001, STRB_WORKING, 1'b0, err);
    pulse_irq_rise(32);
    #1;
    check("TC6 dut.irq_q[32] latched", 1'b1, dut.irq_q[32]);
    check("TC6 dut.enabled_irq_core_0[32] (bit0 of en6332 gates src32)", 1'b1,
          dut.enabled_irq_core_0[32]);

    // Now set every OTHER bit of enable_src6332_core_0 (bits 31:1) and clear
    // bit 0. Per the spec's intent these upper bits don't correspond to any
    // real source (only 33 sources exist), so nothing should ever gate on
    // them - confirm they are functionally inert, not just "unused by name".
    plic_write(ADDR_EN_6332_C0, 32'hFFFF_FFFE, STRB_WORKING, 1'b0, err);
    #1;
    check("TC6 dut.enabled_irq_core_0[32] after bit0 cleared (other 31 bits set)", 1'b0,
          dut.enabled_irq_core_0[32]);
  endtask

  //==============================================================
  // TC7 - Threshold register truncation (same 3-bit storage as priority)
  //==============================================================
  task automatic tc7_threshold_truncation();
    logic [31:0] data;
    logic err;
    $display("\n--- TC7: threshold register truncation ---");
    reset_dut();
    plic_write(ADDR_THRESH_C0, 32'hFFFF_FFFF, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_THRESH_C0, 1'b0, data, err);
    check("TC7 core_0_threshold write 0xFFFFFFFF -> readback", 32'h0000_0007, data);

    plic_write(ADDR_THRESH_C1, 32'hFFFF_FFFF, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_THRESH_C1, 1'b0, data, err);
    check("TC7 core_1_threshold write 0xFFFFFFFF -> readback", 32'h0000_0007, data);
  endtask

  //==============================================================
  // TC8 - Non-secure access: the case-decode keys on {nsecure,addr} but the
  //   case items never set the nsecure bit, so EVERY non-secure access to
  //   an otherwise-valid address falls to default -> always errors.
  //   Flagging this rather than assuming intent - confirm this is the
  //   desired security partition before relying on it.
  //==============================================================
  task automatic tc8_nonsecure_access();
    logic [31:0] data;
    logic err;
    $display("\n--- TC8: non-secure access to a valid address (confirm intent) ---");
    reset_dut();
    plic_write(ADDR_PRIO[1], 32'h0000_0003, STRB_WORKING, 1'b0, err);
    check("TC8 secure write to intr_src_01_prio werror_o", 1'b0, err);
    plic_read(ADDR_PRIO[1], 1'b0, data, err);
    check("TC8 secure read intr_src_01_prio rerror_o", 1'b0, err);
    check("TC8 secure read intr_src_01_prio data", 32'h3, data);

    plic_read(ADDR_PRIO[1], 1'b1, data, err);
    check("TC8 NON-secure read intr_src_01_prio rerror_o (same addr)", 1'b1, err);
    plic_write(ADDR_PRIO[2], 32'h0000_0003, STRB_WORKING, 1'b1, err);
    check("TC8 NON-secure write intr_src_02_prio werror_o", 1'b1, err);
    plic_read(ADDR_PRIO[2], 1'b0, data, err);
    check("TC8 intr_src_02_prio unchanged after blocked non-secure write", 32'h0, data);
  endtask

  //==============================================================
  // TC9 - No per-byte write masking exists anywhere in the update path.
  //   Any single-byte strobe pattern that the bug accepts (i.e. anything
  //   other than 4'hF) still commits the FULL wdata_i word, not just the
  //   strobed byte(s). Demonstrated on a full 32-bit-wide register
  //   (enable_src3100_core_0) so byte boundaries are actually meaningful,
  //   unlike the 3-bit priority/threshold/claim registers.
  //==============================================================
  task automatic tc9_no_byte_masking();
    logic [31:0] data;
    logic err;
    $display("\n--- TC9 [BUG HUNT]: no per-byte write masking ---");
    reset_dut();
    plic_write(ADDR_EN_3100_C0, 32'hAAAA_AAAA, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_EN_3100_C0, 1'b0, data, err);
    check("TC9 baseline enable_src3100_core_0", 32'hAAAA_AAAA, data);

    // Only byte 0's strobe bit is set; a real byte-enabled bus would only
    // change bits [7:0]. Expect (per spec intent) bits[31:8] to stay
    // 0xAAAAAA; the AS-BUILT DUT instead overwrites the whole word.
    plic_write(ADDR_EN_3100_C0, 32'h1111_1111, 4'b0001, 1'b0, err);
    plic_read(ADDR_EN_3100_C0, 1'b0, data, err);
    check("TC9 single-byte strobe (4'b0001) only changes byte 0", 32'hAAAA_AA11, data,
          1'b1);  // expect bug: whole word becomes 0x11111111

    // Try the opposite end of the word too (byte 3 strobe bit only) to
    // confirm it's not an off-by-one in this TB - same result either way.
    plic_write(ADDR_EN_3100_C0, 32'hAAAA_AAAA, STRB_WORKING, 1'b0, err);  // reset baseline
    plic_write(ADDR_EN_3100_C0, 32'h2222_2222, 4'b1000, 1'b0, err);
    plic_read(ADDR_EN_3100_C0, 1'b0, data, err);
    check("TC9 single-byte strobe (4'b1000) only changes byte 3", 32'h22AA_AAAA, data,
          1'b1);  // expect bug: whole word becomes 0x22222222
  endtask

  //==============================================================
  // TC10 - Unmapped "hole" addresses between register blocks
  //==============================================================
  task automatic tc10_unmapped_holes();
    logic [21:0] holes[7];
    logic [31:0] data;
    logic err;
    $display("\n--- TC10: unmapped address holes ---");
    reset_dut();
    holes[0] = 22'h000084;  // just past last priority reg
    holes[1] = 22'h001FFC;  // just before enable block
    holes[2] = 22'h002008;  // just past enable_src6332_core_0
    holes[3] = 22'h002088;  // just past enable_src6332_core_1
    holes[4] = 22'h1FFFFC;  // just before core_0 threshold block
    holes[5] = 22'h200008;  // just past claim_id_core_0
    holes[6] = 22'h201008;  // just past claim_id_core_1
    foreach (holes[i]) begin
      plic_read(holes[i], 1'b0, data, err);
      check($sformatf("TC10 read hole 0x%06h rerror_o", holes[i]), 1'b1, err);
      plic_write(holes[i], 32'hFFFF_FFFF, 4'hF, 1'b0, err);
      check($sformatf("TC10 write hole 0x%06h werror_o", holes[i]), 1'b1, err);
    end
  endtask

  //==============================================================
  // TC11 - BUG: interrupt delivery is dead on arrival for core 0
  //   dut: above_threshold_irq_core_0[k] = enabled_irq_core_0 & (prio_k > thr)
  //   enabled_irq_core_0 is a 33-bit vector; the comparison is 1 bit. SV
  //   self-determines the AND as 33 bits (zero-extending the comparison),
  //   so the only bit of enabled_irq_core_0 that can ever survive into a
  //   1-bit target is bit [0] - which is the reserved/non-existent source 0
  //   and is permanently 0. Every above_threshold_irq_core_0[k] for k=1..32
  //   therefore collapses to enabled_irq_core_0[0] & (...) == 0, always.
  //   Net effect: ei_o[0] can never assert, eiid_o[0] can never leave 0,
  //   no matter what priority/enable/threshold is programmed.
  //   This is traced step by step below: the bug is isolated to the
  //   enabled_irq_core_0 -> above_threshold_irq_core_0 boundary specifically
  //   (irq_q latching and the enable AND itself are both correct).
  //==============================================================
  task automatic tc11_irq_delivery_core0_bug();
    logic [31:0] data;
    logic err;
    $display("\n--- TC11 [BUG HUNT]: core 0 interrupt delivery ---");
    reset_dut();
    plic_write(ADDR_PRIO[5], 32'h0000_0003, STRB_WORKING, 1'b0, err);  // source 5, prio 3
    plic_write(ADDR_THRESH_C0, 32'h0000_0000, STRB_WORKING, 1'b0, err);  // threshold 0
    plic_write(ADDR_EN_3100_C0, 32'h0000_0020, STRB_WORKING, 1'b0, err);  // enable bit5
    pulse_irq_rise(5);
    #1;
    // Step 1: gateway latch - should be correct
    check("TC11 step1 dut.irq_q[5] latched", 1'b1, dut.irq_q[5]);
    // Step 2: enable gating - should be correct
    check("TC11 step2 dut.enabled_irq_core_0[5]", 1'b1, dut.enabled_irq_core_0[5]);
    // Step 3: threshold compare into above_threshold - expected 1, BUG makes it 0
    check("TC11 step3 dut.above_threshold_irq_core_0[5]", 1'b1, dut.above_threshold_irq_core_0[5],
          1'b1);
    // Step 4 (consequence): ei_o/eiid_o never reflect the pending, enabled,
    // above-threshold interrupt.
    check("TC11 step4 ei_o[0]", 1'b1, ei_o[0], 1'b1);
    check("TC11 step4 eiid_o[0]", 32'd5, {26'b0, eiid_o[0]}, 1'b1);
  endtask

  //==============================================================
  // TC12 - Same bug class, core 1 path (above_threshold_irq_core_1)
  //==============================================================
  task automatic tc12_irq_delivery_core1_bug();
    $display("\n--- TC12 [BUG HUNT]: core 1 interrupt delivery (same root cause) ---");
    reset_dut();
    plic_write(ADDR_PRIO[9], 32'h0000_0004, STRB_WORKING, 1'b0, dummy_err);
    plic_write(ADDR_THRESH_C1, 32'h0000_0000, STRB_WORKING, 1'b0, dummy_err);
    plic_write(ADDR_EN_3100_C1, 32'h0000_0200, STRB_WORKING, 1'b0, dummy_err);  // enable bit9
    pulse_irq_rise(9);
    #1;
    check("TC12 dut.irq_q[9]", 1'b1, dut.irq_q[9]);
    check("TC12 dut.enabled_irq_core_1[9]", 1'b1, dut.enabled_irq_core_1[9]);
    check("TC12 dut.above_threshold_irq_core_1[9]", 1'b1, dut.above_threshold_irq_core_1[9], 1'b1);
    check("TC12 ei_o[1]", 1'b1, ei_o[1], 1'b1);
    check("TC12 eiid_o[1]", 32'd9, {26'b0, eiid_o[1]}, 1'b1);
  endtask

  //==============================================================
  // TC13 - BUG: claim_id_core_0/1 storage is only PRIO_BITS (3) wide
  //   (should be PLIC_ADDR_WIDTH=6 to hold IDs up to 32). IDs 0-7 round-trip
  //   fine; IDs 8-32 alias modulo 8 on readback.
  //==============================================================
  task automatic tc13_claim_id_truncation_bug();
    logic [31:0] data;
    logic err;
    $display("\n--- TC13 [BUG HUNT]: claim_id_core_0/1 register width (3 bits, not 6) ---");
    reset_dut();
    plic_write(ADDR_CLAIM_C0, 32'd5, STRB_WORKING, 1'b0, err);  // in-range, should round-trip
    plic_read(ADDR_CLAIM_C0, 1'b0, data, err);
    check("TC13 claim_id_core_0 readback for ID=5 (fits in 3 bits)", 32'd5, data);

    plic_write(ADDR_CLAIM_C0, 32'd15, STRB_WORKING, 1'b0, err);  // ID=15 needs 4 bits
    plic_read(ADDR_CLAIM_C0, 1'b0, data, err);
    check("TC13 claim_id_core_0 readback for ID=15", 32'd15, data, 1'b1);  // expect bug: 7

    plic_write(ADDR_CLAIM_C1, 32'd32, STRB_WORKING, 1'b0, err);  // max ID
    plic_read(ADDR_CLAIM_C1, 1'b0, data, err);
    check("TC13 claim_id_core_1 readback for ID=32 (max)", 32'd32, data, 1'b1);  // expect bug: 0
  endtask

  //==============================================================
  // TC14 - BUG: core 1 claim/complete indexes irq_claim[wdata_i + 32], but
  //   irq_claim is only [NUM_INTERRUPTS-1:0] = [32:0] (33 bits). For any
  //   claimed ID != 0 the index (ID+32) is out of range -> the non-blocking
  //   assignment to an out-of-range bit-select is a no-op per IEEE1800, so
  //   the pending bit is never actually cleared for core 1. ID=0 happens to
  //   alias to bit 32 (source 32) by coincidence, which is not a meaningful
  //   "complete" in any case since source 0 doesn't exist.
  //   Core 0's claim path (irq_claim[wdata_i], no offset) does not have
  //   this bug - used here as the working reference.
  //==============================================================
  task automatic tc14_core1_claim_oob_bug();
    logic [31:0] data;
    logic err;
    $display("\n--- TC14 [BUG HUNT]: core 1 claim/complete out-of-range index ---");
    reset_dut();

    // Reference: core 0 claim correctly clears irq_q for a mid-range ID.
    pulse_irq_rise(5);
    #1;
    check("TC14 ref dut.irq_q[5] pending before claim", 1'b1, dut.irq_q[5]);
    plic_write(ADDR_CLAIM_C0, 32'd5, STRB_WORKING, 1'b0, err);
    #1;
    check("TC14 ref dut.irq_q[5] cleared by CORE0 claim (correct path)", 1'b0, dut.irq_q[5]);

    // Core 1 claim of a mid-range ID: should also clear irq_q[id], but the
    // +32 offset pushes the index out of range -> expect no effect.
    pulse_irq_rise(9);
    #1;
    check("TC14 dut.irq_q[9] pending before claim", 1'b1, dut.irq_q[9]);
    plic_write(ADDR_CLAIM_C1, 32'd9, STRB_WORKING, 1'b0, err);
    #1;
    check("TC14 dut.irq_q[9] cleared by CORE1 claim", 1'b0, dut.irq_q[9], 1'b1);  // expect bug: stays 1

    // ID=0 "coincidence" case: index becomes 0+32=32, a real (if
    // meaningless) bit -> source 32's pending bit gets cleared instead.
    pulse_irq_rise(32);
    #1;
    check("TC14 dut.irq_q[32] pending before claim", 1'b1, dut.irq_q[32]);
    plic_write(ADDR_CLAIM_C1, 32'd0, STRB_WORKING, 1'b0, err);
    #1;
    $display("[INFO]       TC14 claiming ID=0 on core1 aliases to irq_claim[32] -> clears source 32's pending bit (dut.irq_q[32]=%0b), not a real 'ID 0' complete",
              dut.irq_q[32]);
  endtask

  //==============================================================
  // TC15 - Priority encoder arbitration order (isolated via force/release
  //   on the internal above_threshold vector, bypassing the TC11/TC12 bug
  //   so the encoder itself can be exercised directly).
  //   RISC-V PLIC spec requires: highest priority wins; ties broken by
  //   lowest source ID. This encoder ignores priority value entirely once
  //   a source is in the above_threshold set - it just keeps overwriting
  //   eiid_o with every set bit in increasing index order, so the HIGHEST
  //   index above-threshold source always wins, never the highest priority
  //   / lowest-ID tie-break.
  //==============================================================
  task automatic tc15_arbitration_order_isolated();
    $display("\n--- TC15 [BUG HUNT, isolated]: eiid_o arbitration order ---");
    reset_dut();
    force dut.above_threshold_irq_core_0 = '0;
    #1;
    // Sources 3 and 30 both "above threshold" simultaneously, regardless of
    // their actual relative priority - spec-correct behavior would need the
    // higher-priority one (or lowest ID on a tie); this encoder always picks
    // the higher INDEX.
    // Set bits 3 and 30 together (33-bit vector) rather than forcing bit-selects
    force dut.above_threshold_irq_core_0 = 33'h40000008;
    #1;
    check("TC15 eiid_o[0] with sources {3,30} both above threshold", 32'd3,
          {26'b0, eiid_o[0]}, 1'b1);  // spec: lowest-ID tie-break -> expect 3; bug gives highest ID (30)
    release dut.above_threshold_irq_core_0;
  endtask

  //==============================================================
  // TC16 - Asynchronous reset mid-operation: registers clear immediately on
  //   arst_ni falling, without waiting for a clk edge.
  //==============================================================
  task automatic tc16_async_reset_midop();
    logic [31:0] data;
    logic err;
    $display("\n--- TC16: asynchronous reset mid-operation ---");
    reset_dut();
    plic_write(ADDR_PRIO[7], 32'h0000_0005, STRB_WORKING, 1'b0, err);
    plic_read(ADDR_PRIO[7], 1'b0, data, err);
    check("TC16 intr_src_07_prio set before async reset", 32'h5, data);

    @(negedge clk_i);  // land mid-cycle, away from any posedge
    #2;
    arst_ni = 1'b0;  // assert reset asynchronously
    #1;  // do NOT wait for a clk edge
    plic_read(ADDR_PRIO[7], 1'b0, data, err);
    check("TC16 intr_src_07_prio cleared immediately by async reset (no clk edge waited)",
          32'h0, data);
    arst_ni = 1'b1;
    @(posedge clk_i);
  endtask

  //==============================================================
  // TC17 - Randomized regression
  //   Scoreboard intentionally mirrors the DUT's AS-BUILT storage widths
  //   (3-bit priority/threshold/claim, full 32-bit enables) since the goal
  //   here is regression stability and X-propagation safety under random
  //   traffic, not bug-hunting - TC4/TC7/TC13 already characterize the
  //   truncation bugs directly.
  //==============================================================
  task automatic tc17_random_regression(int num_iters = 300);
    logic [31:0] data, exp_data;
    logic err, exp_err;
    int unsigned pick;
    logic [21:0] addr;
    logic [31:0] wval;
    logic [3:0] strb;
    bit is_valid;
    int rand_irq;

    // Scoreboard storage (as-built widths)
    logic [2:0] sb_prio[1:32];
    logic [31:0] sb_en3100_0 = 0, sb_en6332_0 = 0, sb_en3100_1 = 0, sb_en6332_1 = 0;
    logic [2:0] sb_thr0 = 0, sb_thr1 = 0;

    $display("\n--- TC17: randomized regression (%0d iterations) ---", num_iters);
    reset_dut();
    for (int i = 1; i <= 32; i++) sb_prio[i] = 3'h0;

    for (int it = 0; it < num_iters; it++) begin
      // 70% chance of hitting a valid address, 30% an invalid one.
      if ($urandom_range(0, 9) < 7) begin
        pick = $urandom_range(0, 37);
        if (pick < 32) addr = ADDR_PRIO[pick+1];
        else if (pick == 32) addr = ADDR_EN_3100_C0;
        else if (pick == 33) addr = ADDR_EN_6332_C0;
        else if (pick == 34) addr = ADDR_EN_3100_C1;
        else if (pick == 35) addr = ADDR_EN_6332_C1;
        else if (pick == 36) addr = ADDR_THRESH_C0;
        else addr = ADDR_THRESH_C1;
        is_valid = 1'b1;
      end else begin
        // A handful of representative invalid addresses (reserved + holes).
        pick = $urandom_range(0, 4);
        case (pick)
          0: addr = 22'h000000;
          1: addr = 22'h000084;
          2: addr = 22'h002008;
          3: addr = 22'h1FFFFC;
          default: addr = 22'h3FFFFF;
        endcase
        is_valid = 1'b0;
      end

      wval = $urandom();
      strb = $urandom_range(0, 1) ? 4'hF : 4'(1 << $urandom_range(0, 3));  // sometimes partial

      plic_write(addr, wval, strb, 1'b0, err);
      // AS-BUILT behavior (see TC2B): werror_o = !is_valid || (strb == 4'hF) -
      // a full strobe is rejected even to a valid register.
      exp_err = !is_valid || (strb == 4'hF);
      check($sformatf("TC17[%0d] write 0x%06h strb=%0h werror_o", it, addr, strb),
            {31'b0, exp_err}, {31'b0, err});

      if (is_valid && strb != 4'hF) begin
        // Update scoreboard to match as-built storage widths/behavior: the
        // write commits whenever accepted, full word, no byte masking.
        if (addr == ADDR_EN_3100_C0) sb_en3100_0 = wval;
        else if (addr == ADDR_EN_6332_C0) sb_en6332_0 = wval;
        else if (addr == ADDR_EN_3100_C1) sb_en3100_1 = wval;
        else if (addr == ADDR_EN_6332_C1) sb_en6332_1 = wval;
        else if (addr == ADDR_THRESH_C0) sb_thr0 = wval[2:0];
        else if (addr == ADDR_THRESH_C1) sb_thr1 = wval[2:0];
        else begin
          for (int i = 1; i <= 32; i++)
          if (addr == ADDR_PRIO[i]) sb_prio[i] = wval[2:0];
        end
      end

      // Randomly toggle an interrupt source and confirm no X propagates to
      // the externally visible interrupt status outputs.
      rand_irq = $urandom_range(1, 32);
      if ($urandom_range(0, 1)) pulse_irq_rise(rand_irq);
      else irq_i[rand_irq] = 1'b0;
      #1;
      if ($isunknown(ei_o) || $isunknown(eiid_o)) begin
        fail_cnt++;
        $display("[FAIL]       TC17[%0d] X propagated to ei_o/eiid_o (ei_o=%b eiid_o=%p)", it,
                  ei_o, eiid_o);
      end

      // Spot-check readback every few iterations to keep runtime reasonable.
      if (it % 10 == 0) begin
        plic_read(addr, 1'b0, data, err);
        if (is_valid) begin
          if (addr == ADDR_EN_3100_C0) exp_data = sb_en3100_0;
          else if (addr == ADDR_EN_6332_C0) exp_data = sb_en6332_0;
          else if (addr == ADDR_EN_3100_C1) exp_data = sb_en3100_1;
          else if (addr == ADDR_EN_6332_C1) exp_data = sb_en6332_1;
          else if (addr == ADDR_THRESH_C0) exp_data = {29'b0, sb_thr0};
          else if (addr == ADDR_THRESH_C1) exp_data = {29'b0, sb_thr1};
          else begin
            exp_data = 32'h0;
            for (int i = 1; i <= 32; i++)
            if (addr == ADDR_PRIO[i]) exp_data = {29'b0, sb_prio[i]};
          end
          check($sformatf("TC17[%0d] readback 0x%06h vs scoreboard", it, addr), exp_data, data);
        end
      end
    end
  endtask

  

  //----------------------------------------------------------------
  // Test sequence
  //----------------------------------------------------------------
  initial begin
    tc1_reset_defaults();
    tc2_reserved_addr();
    tc2b_strobe_polarity_bug();
    tc3_priority_sweep();
    tc4_priority_truncation();
    tc5_enable_sweep();
    tc6_enable_dead_bits_bug();
    tc7_threshold_truncation();
    tc8_nonsecure_access();
    tc9_no_byte_masking();
    tc10_unmapped_holes();
    tc11_irq_delivery_core0_bug();
    tc12_irq_delivery_core1_bug();
    tc13_claim_id_truncation_bug();
    tc14_core1_claim_oob_bug();
    tc15_arbitration_order_isolated();
    tc16_async_reset_midop();
    tc17_random_regression(300);

    print_summary();
    $finish;
  end

  // Safety timeout
  initial begin
    #1_000_000;
    $display("[FAIL] TIMEOUT - simulation did not finish in time");
    $finish;
  end

endmodule