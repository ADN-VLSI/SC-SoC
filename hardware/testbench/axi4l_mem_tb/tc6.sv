task automatic tc6(output int p, output int f);
  bit [31:0] data;
  bit [1:0] resp;
  p = 0;
  f = 0;

  // No-op write (all strobes 0 — memory should not be written)
  fork
    intf.send_aw({16'h1000, 3'h0});
    intf.send_w({32'hDEAD_BEEF, 4'b0000});
    intf.recv_b(resp);
  join
  check(resp === 2'b00, p, f);

  read_32(16'h1000, data);
  // With strb=0 nothing written so data should NOT be 0xDEADBEEF
  check(data !== 32'hDEAD_BEEF, p, f);
endtask
