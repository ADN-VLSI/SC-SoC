// TC14: Back-to-Back Write Transactions
// 4 consecutive writes with no dead cycles, then read back to verify data.
task automatic tc14(output int p, output int f);
    axi4l_rsp_item q[$];

    bit [ADDR_WIDTH-1:0] addr [4];
    bit [DATA_WIDTH-1:0] data [4];

    p = 0;
    f = 0;

    addr[0] = 'h0000;  data[0] = 'hCAFE_0001;
    addr[1] = 'h0004;  data[1] = 'hCAFE_0002;
    addr[2] = 'h0008;  data[2] = 'hCAFE_0003;
    addr[3] = 'h000C;  data[3] = 'hCAFE_0004;

    // Queue 4 writes back-to-back
    for (int i = 0; i < 4; i++)
    write_seq(addr[i], data[i], {(DATA_WIDTH/8){1'b1}});

    // Check all 4 write responses
    collect(q);
    foreach (q[i]) check(q[i].resp === 2'b00, p, f);
    q.delete();

    // Read back each address
    for (int i = 0; i < 4; i++)
    read_seq(addr[i]);

    // Verify data at each address
    collect(q);
    for (int i = 0; i < 4; i++) begin
    check(q[i].resp === 2'b00,   p, f);
    check(q[i].data === data[i], p, f);
    end
endtask

