  // TC8: Single 32-bit write, idle delay before checking response
  task automatic tc8(output int p, output int f);
    axi4l_seq_item item;
    axi4l_rsp_item q[$];
    p             = 0;
    f             = 0;

    item          = new();
    item.is_write = 1;
    item.addr     = 32'h100;
    item.data     = 32'hDEAD_BEEF;
    item.strb     = 4'b1111;
    dvr_mbx.put(item);

    repeat (5) @(posedge clk_i);  // idle gap
    collect(q);

    foreach (q[i]) check(q[i].resp === 2'b00, p, f);
  endtask
