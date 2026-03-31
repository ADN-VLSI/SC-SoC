task automatic tc0(output int p, output int f);
  p = 0;
  f = 0;

  // Force asynchronous reset and keep asserted for 5 cycles.
  arst_ni <= 0;
  intf.req_reset();
  intf.rsp_reset();
  repeat (5) @(posedge clk_i);

  // During reset all DUT ready/valid outputs must be 0.
  check(intf.rsp.aw_ready == 0, p, f);
  check(intf.rsp.w_ready  == 0, p, f);
  check(intf.rsp.ar_ready == 0, p, f);
  check(intf.rsp.b_valid  == 0, p, f);
  check(intf.rsp.r_valid  == 0, p, f);

  // No responses should be observed during reset window.
  check(mon.mbx.num() == 0, p, f);

  // Release reset and allow the DUT to stabilize.
  arst_ni <= 1;
  repeat (10) @(posedge clk_i);

  // After reset, ready signals should be asserted for idle slave.
  check(intf.rsp.aw_ready == 1, p, f);
  check(intf.rsp.w_ready  == 1, p, f);
  check(intf.rsp.ar_ready == 1, p, f);

  // Still no outstanding responses in the scoreboarding mailbox.
  check(mon.mbx.num() == 0, p, f);

  $display("TC0 complete");
endtask
