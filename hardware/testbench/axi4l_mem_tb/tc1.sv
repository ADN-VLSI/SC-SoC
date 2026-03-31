task automatic tc1(output int p, output int f);
  bit [7:0] expected = 8'hA5;
  bit [31:0] rdata;
  bit [1:0] resp;
  p = 0;
  f = 0;

  fork
    intf.send_aw({16'h0000, 3'h0});
    intf.send_w({expected, 4'b0001});
    intf.recv_b(resp);
  join
  check(resp === 2'b00, p, f);

  fork
    intf.send_ar({16'h0000, 3'h0});
    intf.recv_r({rdata, resp});
  join
  check(resp === 2'b00, p, f);
  check(rdata[7:0] === expected, p, f);
endtask
