// =============================================================================
//   DATA FLOW SUMMARY:
//   testbench drives clk_i/arst_ni -> axi4l_if (bus-functional model: drives
//     AW/W/B/AR/R channels) -> u_dut (axi4l_clint_regif, DUT under test)
//     -> DUT outputs (msip_irq_o, timer_irq_o, mtime_o, mtimecmp_o) are
//     checked against expected values via the check() task.
//
//   Each tc_* task is a self-contained test case: it drives stimulus through
//   the axi4l_if helper tasks (write_32 / read_32 / write_32_strb), then
//   asserts on the DUT's bus responses and/or its direct output ports.
//   pass_count/fail_count accumulate across all test cases; a single summary
//   line is printed at the end, and $fatal is raised if anything failed.
// =============================================================================
// MODULE: axi4l_clint_regif_tb
// PURPOSE: Self-checking testbench for axi4l_clint_regif. Exercises:
//            - reset values of all registers
//            - MSIP register read/write + interrupt line
//            - 64-bit MTIMECMP / MTIME register read/write (LO/HI halves)
//            - free-running timer count-up, enable/disable, and IRQ firing
//            - error responses: partial-strobe writes, unmapped addresses
// =============================================================================

`include "package/clint_pkg.sv"

module axi4l_clint_regif_tb;
  import clint_pkg::*;                  // import all names from clint_pkg

  // ===========================================================================
  // STEP 1: Clock / reset / control signals driven into the DUT
  // ===========================================================================
  logic clk_i;                          // system clock, generated below (10ns period)
  logic arst_ni;                        // ASYNC, ACTIVE-LOW reset, driven by reset_dut()
  logic timer_en_i;                     // 1 = mtime auto-increments; 0 = frozen

  // ===========================================================================
  // STEP 2: DUT output observability signals
  // WHY: these mirror the DUT's output ports so test cases can assert on the
  //      live interrupt lines and timer values directly, in addition to
  //      checking values returned over the AXI bus.
  // ===========================================================================
  logic        msip_irq_o;              // software interrupt line, from DUT
  logic        timer_irq_o;             // timer interrupt line, from DUT
  logic [63:0] mtime_o;                 // current time counter value, from DUT
  logic [63:0] mtimecmp_o;              // current alarm/compare value, from DUT

  // ===========================================================================
  // STEP 3: Test bookkeeping
  // ===========================================================================
  int pass_count;                       // running count of passed checks
  int fail_count;                       // running count of failed checks

  // ===========================================================================
  // STEP 4: AXI4-Lite bus-functional model
  // WHY: axi4l_if is a reusable interface that implements the low-level AXI
  //      handshaking (AW/W/B/AR/R channels) so test cases can issue simple
  //      task calls (send_aw, send_w, recv_b, send_ar, recv_r) instead of
  //      manually toggling valid/ready signals every cycle.
  // ===========================================================================
  axi4l_if #(
      .req_t (clint_axil_req_t),        // request struct type, matches DUT's axil_req_t
      .resp_t(clint_axil_resp_t)        // response struct type, matches DUT's axil_resp_t
  ) intf (
      .arst_ni(arst_ni),                // shares the same reset as the DUT
      .clk_i  (clk_i)                   // shares the same clock as the DUT
  );

  // ===========================================================================
  // STEP 5: DUT instantiation
  // WHY: req_i/resp_o are connected directly to the bus-functional model's
  //      req/resp signals (intf.req / intf.resp), so every send_*/recv_*
  //      task call on intf is what actually drives the DUT's AXI bus.
  // ===========================================================================
  axi4l_clint_regif #(
      .axil_req_t (clint_axil_req_t),
      .axil_resp_t(clint_axil_resp_t)
  ) u_dut (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),
      .timer_en_i (timer_en_i),
      .req_i      (intf.req),           // DUT's AXI request comes from the BFM
      .resp_o     (intf.resp),          // DUT's AXI response goes back to the BFM
      .msip_irq_o (msip_irq_o),
      .timer_irq_o(timer_irq_o),
      .mtime_o    (mtime_o),
      .mtimecmp_o (mtimecmp_o)
  );

  // ===========================================================================
  // STEP 6: Generic pass/fail check helper
  // WHY: centralizes result logging/counting so every tc_* task can just call
  //      check(condition, "description") instead of duplicating $display logic.
  // ===========================================================================
  task automatic check(input logic ok, input string msg);
    if (ok) begin
      pass_count++;
      $display("  [PASS] %s", msg);     // condition was true -> log PASS
    end else begin
      fail_count++;
      $display("  [FAIL] %s", msg);     // condition was false -> log FAIL
    end
  endtask

  // ===========================================================================
  // STEP 7: Bus access helper tasks
  // WHY: wrap the raw axi4l_if channel tasks into single-call write/read
  //      operations, so test cases read like plain register accesses.
  // ===========================================================================

  // ---- Full-word (all 4 byte-strobes set) 32-bit write ----
  task automatic write_32(
      input  logic [15:0] addr,         // register byte address
      input  logic [31:0] data,         // data to write
      output logic [ 1:0] resp          // AXI write response (OKAY/SLVERR/etc.) returned to caller
  );
    fork
      intf.send_aw({addr, 3'h0});       // drive write-address channel (addr + size field = 0)
      intf.send_w({data, 4'b1111});     // drive write-data channel (data + ALL byte strobes set)
      intf.recv_b(resp);                // capture the write-response channel
    join
  endtask

  // ---- 32-bit write with an EXPLICIT (possibly partial) byte-strobe ----
  // WHY: lets test cases deliberately issue partial writes to verify the
  //      DUT's "full-word writes only" error-detection rule (Step 7 in regif).
  task automatic write_32_strb(
      input  logic [15:0] addr,         // register byte address
      input  logic [31:0] data,         // data to write
      input  logic [ 3:0] strb,         // caller-chosen byte-strobe pattern (may be partial)
      output logic [ 1:0] resp          // AXI write response returned to caller
  );
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({data, strb});        // strobe pattern passed straight through, not forced to all-1
      intf.recv_b(resp);
    join
  endtask

  // ---- 32-bit read ----
  task automatic read_32(
      input  logic [15:0] addr,         // register byte address
      output logic [31:0] data,         // data returned by the DUT
      output logic [ 1:0] resp          // AXI read response returned to caller
  );
    logic [33:0] r_bus;                 // raw R-channel bus: {data[31:0], resp[1:0]}
    fork
      intf.send_ar({addr, 3'h0});       // drive read-address channel (addr + size field = 0)
      intf.recv_r(r_bus);               // capture the read-data channel
    join
    data = r_bus[33:2];                 // unpack: top 32 bits are the read data
    resp = r_bus[1:0];                  // unpack: bottom 2 bits are the response code
  endtask

  // ===========================================================================
  // STEP 8: DUT reset sequencing
  // WHY: holds arst_ni low for several cycles (matches the DUT's async-reset
  //      requirement), resets the bus-functional model's internal state via
  //      intf.req_reset(), then releases reset and waits for things to settle.
  // ===========================================================================
  task automatic reset_dut();
    timer_en_i <= 1'b0;                 // timer disabled during reset
    arst_ni    <= 1'b0;                 // assert reset (active-low)
    intf.req_reset();                   // put the bus-functional model into a known idle state
    repeat (4) @(posedge clk_i);        // hold reset for 4 clock cycles
    arst_ni <= 1'b1;                    // de-assert reset
    repeat (4) @(posedge clk_i);        // allow 4 cycles for the DUT to settle post-reset
  endtask

  // ===========================================================================
  // STEP 9: Test case -- reset values
  // CHECKS: every register reads back its documented reset value, and both
  //         interrupt lines are low immediately after reset.
  // ===========================================================================
  task automatic tc_reset_values();
    logic [31:0] data;
    logic [ 1:0] resp;

    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MSIP resets to zero");
    check(!msip_irq_o, "software interrupt is low after reset");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFFFF_FFFF, "MTIMECMP_LO resets to all ones");

    read_32(CLINT_MTIMECMP_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFFFF_FFFF, "MTIMECMP_HI resets to all ones");

    read_32(CLINT_MTIME_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MTIME_LO resets to zero");

    read_32(CLINT_MTIME_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MTIME_HI resets to zero");
    check(!timer_irq_o, "timer interrupt is low after reset");
  endtask

  // ===========================================================================
  // STEP 10: Test case -- MSIP register behavior
  // CHECKS: write returns OKAY, only bit 0 is stored (upper bits masked),
  //         and msip_irq_o tracks bit 0 exactly (set then clear).
  // ===========================================================================
  task automatic tc_msip();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MSIP_OFFSET, 32'hFFFF_FFFF, resp);
    check(resp == 2'b00, "MSIP write returns OKAY");
    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0001, "MSIP stores only bit 0");
    check(msip_irq_o, "MSIP bit 0 asserts software interrupt");

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0000, resp);
    check(resp == 2'b00, "MSIP clear write returns OKAY");
    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MSIP clears to zero");
    check(!msip_irq_o, "clearing MSIP deasserts software interrupt");
  endtask

  // ===========================================================================
  // STEP 11: Test case -- 64-bit register read/write (MTIMECMP and MTIME)
  // CHECKS: LO/HI halves write independently, the 64-bit output port
  //         correctly assembles {HI, LO}, and both halves read back intact.
  // ===========================================================================
  task automatic tc_64b_register_rw();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h89AB_CDEF, resp);
    check(resp == 2'b00, "MTIMECMP_LO write returns OKAY");
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0123_4567, resp);
    check(resp == 2'b00, "MTIMECMP_HI write returns OKAY");
    check(mtimecmp_o == 64'h0123_4567_89AB_CDEF, "MTIMECMP output is 64-bit assembled value");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h89AB_CDEF, "MTIMECMP_LO reads back");
    read_32(CLINT_MTIMECMP_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0123_4567, "MTIMECMP_HI reads back");

    write_32(CLINT_MTIME_LO_OFFSET, 32'h7654_3210, resp);
    check(resp == 2'b00, "MTIME_LO write returns OKAY");
    write_32(CLINT_MTIME_HI_OFFSET, 32'hFEDC_BA98, resp);
    check(resp == 2'b00, "MTIME_HI write returns OKAY");
    check(mtime_o == 64'hFEDC_BA98_7654_3210, "MTIME output is 64-bit assembled value");

    read_32(CLINT_MTIME_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h7654_3210, "MTIME_LO reads back");
    read_32(CLINT_MTIME_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFEDC_BA98, "MTIME_HI reads back");
  endtask

  // ===========================================================================
  // STEP 12: Test case -- timer counting and interrupt firing
  // CHECKS: mtime stays below mtimecmp until enabled, increments by exactly
  //         1/cycle while timer_en_i is high, freezes when disabled, fires
  //         timer_irq_o the instant mtime reaches mtimecmp, and clears the
  //         interrupt again once mtimecmp is rewritten to a future value.
  // ===========================================================================
  task automatic tc_timer_count_and_irq();
    logic [ 1:0] resp;
    logic [63:0] start_time;            // snapshot of mtime_o used to verify increment amount

    write_32(CLINT_MTIME_LO_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIME_HI_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0003, resp);
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0000, resp);
    check(!timer_irq_o, "future MTIMECMP keeps timer interrupt low");

    start_time = mtime_o;
    timer_en_i <= 1'b1;                 // enable auto-increment
    repeat (3) @(posedge clk_i);        // let mtime count up to meet mtimecmp (=3)
    #1;                                 // small delta to let combinational IRQ logic settle
    check(mtime_o == start_time + 64'd3, "MTIME increments by one per enabled clock");
    check(timer_irq_o, "MTIME reaching MTIMECMP asserts timer interrupt");

    timer_en_i <= 1'b0;                 // disable auto-increment
    start_time = mtime_o;
    repeat (3) @(posedge clk_i);        // mtime should NOT move during these cycles
    #1;
    check(mtime_o == start_time, "MTIME stops when timer_en_i is low");

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0100, resp);  // push compare value far into the future
    check(resp == 2'b00 && !timer_irq_o, "writing a future MTIMECMP clears timer interrupt");
  endtask

  // ===========================================================================
  // STEP 13: Test case -- error responses
  // CHECKS: partial-strobe writes are rejected (SLVERR), writes/reads to an
  //         unmapped address return SLVERR, and unmapped reads return zero data.
  // ===========================================================================
  task automatic tc_error_responses();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32_strb(CLINT_MSIP_OFFSET, 32'h0000_0001, 4'b0001, resp);  // only 1 of 4 byte lanes set
    check(resp == 2'b10, "partial write returns SLVERR");

    write_32(16'h0004, 32'hDEAD_BEEF, resp);   // 0x0004 is not one of the 5 known register offsets
    check(resp == 2'b10, "write to unmapped offset returns SLVERR");

    read_32(16'h0004, data, resp);
    check(resp == 2'b10 && data == 32'h0000_0000, "read from unmapped offset returns SLVERR and zero data");
  endtask

  // ===========================================================================
  // STEP 14: Clock generator
  // WHY: free-running 10ns-period clock (5ns high, 5ns low) drives the whole
  //      testbench and DUT for the entire simulation.
  // ===========================================================================
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  // ===========================================================================
  // STEP 15: Main test sequence
  // WHY: single top-level initial block that resets the DUT, runs every test
  //      case in order, then reports a pass/fail summary and ends the sim
  //      with $fatal if anything failed (so CI/regression flows can detect it).
  // ===========================================================================
  initial begin
    pass_count = 0;
    fail_count = 0;

    $timeformat(-9, 1, " ns", 20);              // display times as e.g. "12.3 ns"
    $dumpfile("axi4l_clint_regif_tb.vcd");      // waveform dump for debugging
    $dumpvars(0, axi4l_clint_regif_tb);

    reset_dut();
    tc_reset_values();
    tc_msip();
    tc_64b_register_rw();
    tc_timer_count_and_irq();
    tc_error_responses();

    $display("axi4l_clint_regif_tb summary: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count != 0) $fatal(1, "axi4l_clint_regif_tb failed");
    $finish;
  end

endmodule