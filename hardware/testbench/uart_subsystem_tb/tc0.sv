/*task automatic tc0();
    logic [31:0] rdata;

    // Re-apply reset inside TC0 so reset behavior is actually tested
    arst_ni = 1'b0;
    req_i   = '0;
    scoreboard.delete();

    repeat (20) begin
        @(posedge clk_i);
        check((u_uart_if.rx === 1'b1), "TC0: TX line stays idle HIGH during reset");
        check(!$isunknown(u_uart_if.rx), "TC0: TX line is not X/Z during reset");
        check(!$isunknown(resp_o), "TC0: AXI response bus is not X/Z during reset");
        check(!$isunknown(int_en_o), "TC0: interrupt output is not X/Z during reset");
    end

    arst_ni = 1'b1;
    repeat (10) @(posedge clk_i);

    // Reset register defaults
    axi_read(UART_CTRL_OFFSET, rdata);
    check((rdata == 32'h0000_0000),
          $sformatf("TC0: CTRL reset value correct, got 0x%08h", rdata));

    axi_read(UART_CFG_OFFSET, rdata);
    check((rdata == 32'h0003_405B),
          $sformatf("TC0: CFG reset value correct, got 0x%08h", rdata));

    axi_read(UART_INT_EN_OFFSET, rdata);
    check((rdata == 32'h0000_0000),
          $sformatf("TC0: INT_EN reset value correct, got 0x%08h", rdata));

    // STATUS checks
    axi_read(UART_STAT_OFFSET, rdata);
    check((rdata[20] == 1'b1), "TC0: STATUS.tx_empty = 1 after reset");
    check((rdata[22] == 1'b1), "TC0: STATUS.rx_empty = 1 after reset");
    check((rdata[9:0]   == 10'd0), "TC0: TX count = 0 after reset");
    check((rdata[19:10] == 10'd0), "TC0: RX count = 0 after reset");

    // RX FIFO empty check
    axi_read(UART_RXD_OFFSET, rdata);
    check((rdata == 32'h0000_0000),
          $sformatf("TC0: RXD returns 0 when RX FIFO empty, got 0x%08h", rdata));

    // Idle check after reset
    repeat (20) begin
        @(posedge clk_i);
        check((u_uart_if.rx === 1'b1), "TC0: TX line remains idle HIGH after reset");
    end

    // Restore configured state for later testcases
    configure_uart();
endtask
*/