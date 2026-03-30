// TC4: Read-After-Write (Same Address)
// Pre-load known value → write new value → read 1 cycle later (before B arrives)
// → verify both responses OKAY → second read confirms write committed
task automatic tc4(output int p, output int f);
    axi4l_rsp_item q[$];
    p = 0;
    f = 0;

    // Pre-initialize address to avoid X on first read
    write_seq('h0010, 'hCAFE_BABE, {(DATA_WIDTH/8){1'b1}});
    collect(q);
    q.delete();

    // Write then 1 cycle later read — before B response arrives
    fork
    begin
        write_seq('h0010, 'hDEAD_BEEF, {(DATA_WIDTH/8){1'b1}});
        @(posedge clk_i);
        read_seq('h0010);
    end
    join_none

    // Collect write B-response + first read R-response
    collect(q);
    check(q[0].resp === 2'b00, p, f);  // write resp OKAY
    check(q[1].resp === 2'b00, p, f);  // first read resp OKAY
    // first read data may be old or new — both acceptable, no data check here
    q.delete();

    // Second read — write must have committed by now
    read_seq('h0010);
    collect(q);
    check(q[0].resp === 2'b00,       p, f);  // read resp OKAY
    check(q[0].data === 'hDEAD_BEEF, p, f);  // data must match written value

endtask
