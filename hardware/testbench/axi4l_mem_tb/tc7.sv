// TC7: VIP write + response check + readback
task automatic tc7(output int p, output int f);
  axi4l_seq_item item;
  axi4l_rsp_item q[$];
  bit [31:0] rd;
  bit [15:0] addr;
  bit [31:0] exp;
  p    = 0;
  f    = 0;
  addr = 16'h0100;
  exp  = 32'hDEAD_BEEF;

  // Drain any stale responses before starting
  while (mon.mbx.num()) begin
    axi4l_rsp_item tmp;
    mon.mbx.get(tmp);
  end

  item          = new();
  item.is_write = 1'b1;
  item.addr     = addr;
  item.data     = exp;
  item.strb     = 4'b1111;
  dvr_mbx.put(item);

  collect(q);
  foreach (q[i]) check(q[i].resp === 2'b00, p, f);

  read_32(addr, rd);
  check(rd === exp, p, f);
  if (rd !== exp)
    $display("TC7 DATA MISMATCH: addr=0x%04h exp=0x%08h got=0x%08h", addr, exp, rd);
endtask