task automatic tc16(output int p, output int f);
  int num_txn = $urandom_range(50, 100);
  bit [7:0] mem_model[0:65535];
  bit [15:0] addr;
  bit [7:0] data8;
  p = 0;
  f = 0;

  repeat (num_txn) begin
    addr  = $urandom_range(0, 65535);
    data8 = $urandom_range(0, 255);

    repeat ($urandom_range(0, 5)) @(posedge clk_i);

    if ($urandom_range(0, 1)) begin
      write_8(addr, data8);
      mem_model[addr] = data8;
    end else begin
      read_8(addr, data8);
      check(data8 === mem_model[addr], p, f);
    end
  end
endtask