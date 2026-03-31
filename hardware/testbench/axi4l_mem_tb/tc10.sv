task automatic tc10(output int p, output int f);
  bit [31:0] read_data;
  bit [1:0]  resp;

  p = 0;
  f = 0;

  // Preload data for read verification
  write_32(16'h0200, 32'hA5A5A5A5);

  // Simple read path to avoid hold-aware deadlock in interface helper
  intf.req.r_ready = 1;
  read_32(16'h0200, read_data);

  check(read_data == 32'hA5A5A5A5, p, f);

  $display("TC10: PASS=%0d FAIL=%0d", p, f);
endtask
