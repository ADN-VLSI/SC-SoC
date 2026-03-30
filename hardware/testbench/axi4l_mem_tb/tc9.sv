// TC9: W-Channel Back-Pressure
// Push W beats into FIFO while aw_valid=0 and b_ready=0.
// w_ready de-asserts after 4 beats (FIFO full) — back-pressure observed.
// Drain by supplying 4 AW beats. All B responses must be OKAY.
// Readback confirms data intact.
task automatic tc9(output int p, output int f);
    int  accepted = 0;
    bit  went_low = 0;
    axi4l_rsp_item q[$];

    localparam bit [DATA_WIDTH-1:0] W_DATA  = 'hA5A5_5A5A;
    localparam bit [ADDR_WIDTH-1:0] WR_ADDR = 'h0000;

    p = 0;
    f = 0;
    //--------------------------------------------------------------------
    // Phase 1: Fill W FIFO
    // Run 5 cycles: 4 accepted + 1 back-pressure observed
    //--------------------------------------------------------------------
    repeat (5) begin
    @(negedge clk_i);
    if (intf.rsp.w_ready) begin
        intf.req.w.data  <= W_DATA;
        intf.req.w.strb  <= {(DATA_WIDTH/8){1'b1}};
        intf.req.w_valid <= 1;
        @(posedge clk_i);
        accepted++;
        @(negedge clk_i);
        intf.req.w_valid <= 0;  // safe — w_ready was 1
    end else begin
        went_low = 1;
        @(posedge clk_i);
    end
    end

    repeat (2) @(posedge clk_i);

    //--------------------------------------------------------------------
    // Phase 2: Drain — 4 AW beats to match 4 buffered W beats
    //--------------------------------------------------------------------
    intf.req.b_ready <= 1;

    repeat (4) begin
    @(negedge clk_i);
    intf.req.aw.addr  <= WR_ADDR;
    intf.req.aw.prot  <= 3'b000;
    intf.req.aw_valid <= 1;
    do @(posedge clk_i); while (!intf.rsp.aw_ready);
    @(negedge clk_i);
    intf.req.aw_valid <= 0;
    do @(posedge clk_i); while (!intf.rsp.b_valid);
    check(intf.rsp.b.resp === 2'b00, p, f);
    end

    @(negedge clk_i);
    intf.req.b_ready <= 0;
    repeat (3) @(posedge clk_i);

    //--------------------------------------------------------------------
    // Phase 3: Checks
    //--------------------------------------------------------------------
    check(went_low === 1, p, f);
    check(accepted  == 4, p, f);

    // Read back using VIP — works for any DATA_WIDTH
    read_seq(WR_ADDR);
    collect(q);
    check(q[0].resp === 2'b00,   p, f);
    check(q[0].data === W_DATA,  p, f);
endtask
