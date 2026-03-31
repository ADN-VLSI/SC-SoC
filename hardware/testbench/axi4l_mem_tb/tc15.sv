task automatic tc15(output int p, output int f);
  p = 0;
  f = 0;

  // Preload deterministic data so back-to-back reads are predictable.
  for (int i = 0; i < 8; i++) begin
    write_32(i * 4, 32'h1000 + i);
  end

  // Drive 8 back-to-back reads using read_32 and inline compare.
  for (int i = 0; i < 8; i++) begin
    bit [31:0] got;
    read_32(i * 4, got);
    check(got == (32'h1000 + i), p, f);
  end

  // Wait for all responses to retire
  mon.wait_for_idle();

  // Verify returned responses
  while (mon.mbx.num() > 0) begin
    axi4l_rsp_item rsp;
    mon.mbx.get(rsp);
    check(rsp.resp == 2'b00, p, f);
    check(rsp.data == (32'h1000 + rsp.addr[15:2]), p, f);
  end

  //$display("TC15: PASS=%0d FAIL=%0d", p, f);
endtask
