// TC13: Preload write → concurrent write + read → response check
task automatic tc13(output int p, output int f);
  axi4l_seq_item item_wr;  // dedicated handle for write branch
  axi4l_seq_item item_rd;  // dedicated handle for read branch
  axi4l_rsp_item q                                             [$];
  p                = 0;
  f                = 0;

  // Preload: single write
  item_wr          = new();
  item_wr.is_write = 1;
  item_wr.addr     = 32'h200;
  item_wr.data     = 32'hAAAA_AAAA;
  item_wr.strb     = 4'b1111;
  dvr_mbx.put(item_wr);
  collect(q);
  check(q[0].resp === 2'b00, p, f);

  q.delete();  // clear the queue

  // Concurrent write + read
  fork
    begin
      item_wr          = new();
      item_wr.is_write = 1;
      item_wr.addr     = 32'h500;
      item_wr.data     = 32'hDEAD_BEEF;
      item_wr.strb     = 4'b1111;
      dvr_mbx.put(item_wr);
    end
    begin
      item_rd          = new();
      item_rd.is_write = 0;
      item_rd.addr     = 32'h200;
      dvr_mbx.put(item_rd);
    end
  join

  // to fire before bus activity begins; collect() handles sync correctly on its own
  collect(q);

  foreach (q[i]) check(q[i].resp === 2'b00, p, f);
endtask
