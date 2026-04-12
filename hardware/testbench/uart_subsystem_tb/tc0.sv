/*
task automatic tc0();
    logic [31:0] rdata;
    int i;

    $display("TC0: Power-On Reset");

    // Re-apply power-on reset inside the testcase so uart_subsystem_tb.sv stays unchanged.
    arst_ni = 1'b0;
    req_i   = '0;

    // Hold reset low long enough to guarantee all flops capture reset.
    for (i = 0; i < 10; i++) begin
        @(posedge clk_i);
        check(u_uart_if.rx === 1'b1,
              $sformatf("TC0: tx_o idle high during reset cycle %0d", i));
        check(^resp_o.r.data !== 1'bx,
              $sformatf("TC0: AXI RDATA known during reset cycle %0d", i));
        check(^resp_o.r.resp !== 1'bx,
              $sformatf("TC0: AXI RRESP known during reset cycle %0d", i));
        check(^resp_o.b.resp !== 1'bx,
              $sformatf("TC0: AXI BRESP known during reset cycle %0d", i));
    end

    // Release reset and allow logic to settle.
    arst_ni = 1'b1;
    repeat (2) @(posedge clk_i);

    // CTRL reset value
    axi_read(UART_CTRL_OFFSET, rdata);
    check(rdata == 32'h0000_0000,
          $sformatf("TC0: CTRL reset value is 0x00000000 (got 0x%08h)", rdata));

    // CFG reset value from RTL
    axi_read(UART_CFG_OFFSET, rdata);
    check(rdata == 32'h0003_405B,
          $sformatf("TC0: CFG reset value is 0x0003405B (got 0x%08h)", rdata));

    // STATUS after reset: empty flags set, full flags clear, counts zero.
    axi_read(UART_STAT_OFFSET, rdata);
    check(rdata[20] == 1'b1,
          $sformatf("TC0: STATUS.TX_EMPTY asserted after reset (STAT=0x%08h)", rdata));
    check(rdata[21] == 1'b0,
          $sformatf("TC0: STATUS.TX_FULL deasserted after reset (STAT=0x%08h)", rdata));
    check(rdata[22] == 1'b1,
          $sformatf("TC0: STATUS.RX_EMPTY asserted after reset (STAT=0x%08h)", rdata));
    check(rdata[23] == 1'b0,
          $sformatf("TC0: STATUS.RX_FULL deasserted after reset (STAT=0x%08h)", rdata));
    check(rdata[9:0] == 10'd0,
          $sformatf("TC0: STATUS.TX count is 0 after reset (STAT=0x%08h)", rdata));
    check(rdata[19:10] == 10'd0,
          $sformatf("TC0: STATUS.RX count is 0 after reset (STAT=0x%08h)", rdata));

    // RX data register should read back a defined default when empty.
    axi_read(UART_RXD_OFFSET, rdata);
    check(rdata == 32'h0000_0000,
          $sformatf("TC0: RX_DATA default read is 0x00000000 (got 0x%08h)", rdata));

    // Stay idle and make sure TX line remains high.
    for (i = 0; i < 20; i++) begin
        @(posedge clk_i);
        check(u_uart_if.rx === 1'b1,
              $sformatf("TC0: tx_o remains idle high after reset cycle %0d", i));
    end

    // Restore normal post-reset configuration for any later tests.
    configure_uart();
endtask
*/