task automatic tc11(output int p, output int f);
  bit [31:0] exp_data;
  bit [31:0] rdata;
  bit [1:0] resp;
  p = 0;
  f = 0;

  // Scenario 1: W before AW
  exp_data = 32'h0000_00A5;
  fork
    intf.send_w({exp_data, 4'b0001});
    intf.send_aw({16'h2000, 3'h0});
    intf.recv_b(resp);
  join
  check(resp === 2'b00, p, f);

  fork
    intf.send_ar({16'h2000, 3'h0});
    intf.recv_r({rdata, resp});
  join
  check(resp === 2'b00, p, f);
  check(rdata[7:0] === exp_data[7:0], p, f);

  // Scenario 2: AW before W
  exp_data = 32'h0000_005A;
  fork
    intf.send_aw({16'h2004, 3'h0});
    intf.send_w({exp_data, 4'b0001});
    intf.recv_b(resp);
  join
  check(resp === 2'b00, p, f);

  fork
    intf.send_ar({16'h2004, 3'h0});
    intf.recv_r({rdata, resp});
  join
  check(resp === 2'b00, p, f);
  check(rdata[7:0] === exp_data[7:0], p, f);
endtask
