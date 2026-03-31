task automatic tc2(output int p, output int f);
  axi4l_rsp_item q[$];
  bit [31:0] rd_data;

  p = 0;
  f = 0;

  collect(q); q.delete();

  // Highest aligned address for ADDR_WIDTH=16, DATA_WIDTH=32
  write_seq(16'hFFFC, 32'hA5000000, 4'b1000);
  collect(q);

  check(q.size() > 0, p, f);
  if (q.size() > 0) begin
    check(q[0].is_write, p, f);
    check(q[0].resp == 2'b00, p, f);
  end

  q.delete();
  read_seq(16'hFFFC);
  collect(q);

  check(q.size() > 0, p, f);
  if (q.size() > 0) begin
    check(!q[0].is_write, p, f);
    check(q[0].resp == 2'b00, p, f);
    rd_data = q[0].data[3:0];
    check(rd_data[31:24] == 8'hA5, p, f);
  end
endtask