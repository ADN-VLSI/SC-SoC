// =============================================================================
//   DATA FLOW SUMMARY:
//   testbench drives clk_i/arst_ni/ext_irq_i -> axi4l_if (bus-functional model)
//     -> u_dut (axi4l_clint wrapper, DUT under test) -> internally forwards to
//     axi4l_clint_regif (not instantiated directly here -- this TB only sees
//     the wrapper's external ports) -> DUT outputs (irq_o, msip_irq_o,
//     timer_irq_o, mtime_o, mtimecmp_o) are checked via the check() task.
//
//   Unlike axi4l_clint_regif_tb (which tests the register file in isolation),
//   this testbench validates the axi4l_clint WRAPPER specifically: that bus
//   reads/writes still reach the underlying registers correctly through the
//   wrapper, AND that the three interrupt sources (msip_irq_o, timer_irq_o,
//   ext_irq_i) get packed into the right bit positions of irq_o.
// =============================================================================
// MODULE: axi4l_clint_tb
// PURPOSE: Self-checking testbench for axi4l_clint (the top-level wrapper
//          around axi4l_clint_regif). Exercises:
//            - irq_o bit-packing: msip->bit3, timer->bit7, ext_irq_i->bit11
//            - all three interrupt sources asserting simultaneously
//            - register read/write access still working correctly when routed
//              through the wrapper (not just the regif directly)
// =============================================================================

`include "package/clint_pkg.sv"

module axi4l_clint_tb;
  import clint_pkg::*;                  // import all names from clint_pkg

  // ===========================================================================
  // STEP 1: Clock / reset / control / external-irq signals driven into the DUT
  // ===========================================================================
  logic clk_i;                          // system clock, generated below (10ns period)
  logic arst_ni;                        // ASYNC, ACTIVE-LOW reset, driven by reset_dut()
  logic timer_en_i;                     // 1 = mtime auto-increments; 0 = frozen
  logic ext_irq_i;                      // external interrupt source, fed straight into the wrapper

  // ===========================================================================
  // STEP 2: DUT output observability signals
  // WHY: these mirror the wrapper's output ports so test cases can assert on
  //      the packed irq_o vector AND the individual interrupt lines/timer
  //      values that pass through from the inner regif.
  // ===========================================================================
  logic [31:0] irq_o;                   // packed interrupt vector: bit3=msip, bit7=timer, bit11=ext
  logic        msip_irq_o;              // software interrupt line, passthrough from inner regif
  logic        timer_irq_o;             // timer interrupt line, passthrough from inner regif
  logic [63:0] mtime_o;                 // current time counter value, passthrough from inner regif
  logic [63:0] mtimecmp_o;              // current alarm/compare value, passthrough from inner regif

  // ===========================================================================
  // STEP 3: Test bookkeeping
  // ===========================================================================
  int pass_count;                       // running count of passed checks
  int fail_count;                       // running count of failed checks

  // ===========================================================================
  // STEP 4: AXI4-Lite bus-functional model
  // WHY: axi4l_if implements the low-level AXI handshaking (AW/W/B/AR/R
  //      channels) so test cases can issue simple task calls instead of
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
  // STEP 5: DUT instantiation (the WRAPPER, axi4l_clint -- not the regif directly)
  // WHY: req_i/resp_o are connected to the bus-functional model's req/resp
  //      signals (intf.req / intf.resp); ext_irq_i is driven directly by this
  //      testbench to verify it correctly reaches irq_o[11].
  // ===========================================================================
  axi4l_clint #(
      .axil_req_t (clint_axil_req_t),
      .axil_resp_t(clint_axil_resp_t)
  ) u_dut (
      .clk_i       (clk_i),
      .arst_ni     (arst_ni),
      .timer_en_i  (timer_en_i),
      .axi4l_req_i (intf.req),          // DUT's AXI request comes from the BFM
      .axi4l_resp_o(intf.resp),         // DUT's AXI response goes back to the BFM
      .ext_irq_i   (ext_irq_i),         // external interrupt stimulus, driven by test cases
      .irq_o       (irq_o),
      .msip_irq_o  (msip_irq_o),
      .timer_irq_o (timer_irq_o),
      .mtime_o     (mtime_o),
      .mtimecmp_o  (mtimecmp_o)
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
  //      (Only full-word writes are needed here -- this TB doesn't exercise
  //      partial-strobe/error paths, which are already covered by
  //      axi4l_clint_regif_tb; this TB focuses on the wrapper-specific logic.)
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
  //      intf.req_reset(), de-asserts ext_irq_i so the irq_o vector starts
  //      clean, then releases reset and waits for things to settle.
  // ===========================================================================
  task automatic reset_dut();
    timer_en_i <= 1'b0;                 // timer disabled during reset
    ext_irq_i  <= 1'b0;                 // external interrupt low during reset
    arst_ni    <= 1'b0;                 // assert reset (active-low)
    intf.req_reset();                   // put the bus-functional model into a known idle state
    repeat (4) @(posedge clk_i);        // hold reset for 4 clock cycles
    arst_ni <= 1'b1;                    // de-assert reset
    repeat (4) @(posedge clk_i);        // allow 4 cycles for the DUT to settle post-reset
  endtask

  // ===========================================================================
  // STEP 9: Test case -- IRQ vector packing
  // CHECKS: irq_o resets to zero; MSIP write asserts irq_o[3] (and only that
  //         bit); ext_irq_i asserts irq_o[11]; timer reaching mtimecmp
  //         asserts irq_o[7]; all three sources can be high simultaneously,
  //         confirming the bit-packing logic in Step 2 of axi4l_clint
  //         (irq_o[3]=msip, irq_o[7]=timer, irq_o[11]=ext) is correct.
  // ===========================================================================
  task automatic tc_irq_vector_packing();
    logic [1:0] resp;

    check(irq_o == 32'h0000_0000, "IRQ vector resets low");

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0001, resp);
    check(resp == 2'b00, "MSIP write through wrapper returns OKAY");
    check(msip_irq_o && irq_o[3], "MSIP maps to irq_o[3]");
    check(!irq_o[7] && !irq_o[11], "timer and external IRQ bits remain low");

    ext_irq_i <= 1'b1;                  // assert external interrupt input
    #1;                                 // small delta to let combinational packing logic settle
    check(irq_o[11], "external interrupt input maps to irq_o[11]");

    write_32(CLINT_MTIME_LO_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIME_HI_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0001, resp);  // set alarm to fire almost immediately
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0000, resp);
    timer_en_i <= 1'b1;                 // enable auto-increment so mtime can reach mtimecmp
    repeat (1) @(posedge clk_i);
    #1;
    check(timer_irq_o && irq_o[7], "timer interrupt maps to irq_o[7]");
    check(irq_o[3] && irq_o[7] && irq_o[11], "wrapper can present MSIP, MTIP, and MEIP together");
  endtask

  // ===========================================================================
  // STEP 10: Test case -- register access routed through the wrapper
  // CHECKS: clearing MSIP through the wrapper correctly clears irq_o[3];
  //         64-bit MTIMECMP writes through the wrapper correctly assemble on
  //         the mtimecmp_o passthrough output; reads routed through the
  //         wrapper return the same data that was written -- confirming the
  //         wrapper doesn't interfere with the underlying regif's bus logic.
  // ===========================================================================
  task automatic tc_register_access_through_wrapper();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0000, resp);
    check(resp == 2'b00 && !irq_o[3], "clearing MSIP through wrapper clears irq_o[3]");

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'hCAFE_BABE, resp);
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0002, resp);
    check(mtimecmp_o == 64'h0000_0002_CAFE_BABE, "wrapper exposes 64-bit MTIMECMP output");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hCAFE_BABE, "wrapper forwards CLINT register reads");
  endtask

  // ===========================================================================
  // STEP 11: Clock generator
  // WHY: free-running 10ns-period clock (5ns high, 5ns low) drives the whole
  //      testbench and DUT for the entire simulation.
  // ===========================================================================
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  // ===========================================================================
  // STEP 12: Main test sequence
  // WHY: single top-level initial block that resets the DUT, runs every test
  //      case in order, then reports a pass/fail summary and ends the sim
  //      with $fatal if anything failed (so CI/regression flows can detect it).
  // ===========================================================================
  initial begin
    pass_count = 0;
    fail_count = 0;

    $timeformat(-9, 1, " ns", 20);              // display times as e.g. "12.3 ns"
    $dumpfile("axi4l_clint_tb.vcd");            // waveform dump for debugging
    $dumpvars(0, axi4l_clint_tb);

    reset_dut();
    tc_irq_vector_packing();
    tc_register_access_through_wrapper();

    $display("axi4l_clint_tb summary: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count != 0) $fatal(1, "axi4l_clint_tb failed");
    $finish;
  end

endmodule