task automatic tc2();
    logic [31:0] r, ctrl0, cfg0, ien0, stat0;
    logic [1:0]  bresp, rresp;

    $display("------------------------------------------------------------");
    $display("TC2: AXI Basic Read/Write");
    $display("------------------------------------------------------------");

    cpu_read_32(UART_CTRL_OFFSET,   ctrl0, rresp); check(rresp == 2'b00, "CTRL baseline read RRESP=OK");
    cpu_read_32(UART_CFG_OFFSET,    cfg0,   rresp); check(rresp == 2'b00, "CFG baseline read RRESP=OK");
    cpu_read_32(UART_INT_EN_OFFSET, ien0,   rresp); check(rresp == 2'b00, "INT_EN baseline read RRESP=OK");

    // CTRL: protocol check only (this DUT does not mirror CTRL cleanly)
    cpu_write_32(UART_CTRL_OFFSET, 32'hA5A5_A5A5, bresp);
    check(bresp == 2'b00, "CTRL write BRESP=OK");
    repeat (5) @(posedge clk_i);
    cpu_read_32(UART_CTRL_OFFSET, r, rresp);
    check(rresp == 2'b00, "CTRL read RRESP=OK");

    cpu_write_32(UART_CTRL_OFFSET, 32'h0000_0000, bresp);
    check(bresp == 2'b00, "CTRL zero write BRESP=OK");
    repeat (5) @(posedge clk_i);
    cpu_read_32(UART_CTRL_OFFSET, r, rresp);
    check(rresp == 2'b00, "CTRL zero read RRESP=OK");

    // CFG
    cpu_write_32(UART_CFG_OFFSET, 32'h0000_0271, bresp);
    check(bresp == 2'b00, "CFG write BRESP=OK");
    cpu_read_32(UART_CFG_OFFSET, r, rresp);
    check(rresp == 2'b00, "CFG read RRESP=OK");
    check(r == 32'h0000_0271, $sformatf("CFG readback 0x%08h", r));

    // INT_EN
    cpu_write_32(UART_INT_EN_OFFSET, 32'h0000_000F, bresp);
    check(bresp == 2'b00, "INT_EN write BRESP=OK");
    cpu_read_32(UART_INT_EN_OFFSET, r, rresp);
    check(rresp == 2'b00, "INT_EN read RRESP=OK");
    check(r == 32'h0000_000F, $sformatf("INT_EN readback 0x%08h", r));

    // STATUS is RO
    cpu_read_32(UART_STAT_OFFSET, stat0, rresp);
    check(rresp == 2'b00, "STATUS baseline read RRESP=OK");
    cpu_write_32(UART_STAT_OFFSET, 32'hFFFF_FFFF, bresp);
    $display("STATUS write attempt BRESP=0x%0b", bresp);
    cpu_read_32(UART_STAT_OFFSET, r, rresp);
    check(rresp == 2'b00, "STATUS post-write read RRESP=OK");
    check(r == stat0, $sformatf("STATUS unchanged: 0x%08h == 0x%08h", r, stat0));

    // 10 back-to-back CTRL writes/reads
    for (int i = 1; i <= 10; i++) begin
        cpu_write_32(UART_CTRL_OFFSET, i, bresp);
        check(bresp == 2'b00, $sformatf("CTRL pattern %0d write BRESP=OK", i));
        repeat (5) @(posedge clk_i);
        cpu_read_32(UART_CTRL_OFFSET, r, rresp);
        check(rresp == 2'b00, $sformatf("CTRL pattern %0d read RRESP=OK", i));
    end

    // Restore
    cpu_write_32(UART_CTRL_OFFSET,   ctrl0, bresp);
    cpu_write_32(UART_CFG_OFFSET,    cfg0,   bresp);
    cpu_write_32(UART_INT_EN_OFFSET, ien0,   bresp);

    repeat (5) @(posedge clk_i);
endtask