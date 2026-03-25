// TC3: 4 consecutive 32-bit writes followed by 4 reads using VIP driver
task automatic tc3(output int p, output int f);
  axi4l_seq_item item;
  axi4l_rsp_item q[$];
  p = 0;
  f = 0;

  // Queue 4 write transactions to word-aligned addresses 0x00..0x0C
  for (int i = 0; i < 4; i++) write_seq(i * 4, 32'hA0 + i, 4'b1111);
  collect(q);

  // Check write responses
  foreach (q[i]) check(q[i].resp === 2'b00, p, f);
  q.delete();

  // Queue 4 read transactions to same addresses
  for (int i = 0; i < 4; i++) read_seq(i * 4);
  collect(q);

  // verify both OKAY response and read-back data against written values;
  // confirmed the memory actually returned the correct data
  foreach (q[i]) begin
    check(q[i].resp === 2'b00, p, f);  // read OKAY
    check(q[i].data === 32'hA0 + i, p, f);  // data matches written value
  end
endtask
