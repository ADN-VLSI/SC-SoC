task automatic tc1();
    logic [31:0] status;
    int timeout;

    // Preload TX FIFO
    axi_write(UART_TXD_OFFSET, 32'h000000A5);
    axi_write(UART_TXD_OFFSET, 32'h0000005A);
    axi_write(UART_TXD_OFFSET, 32'h000000FF);
    axi_write(UART_TXD_OFFSET, 32'h000000C3);

    // Wait for transmission to begin with timeout
    timeout = 0;
    while ((u_uart_if.rx !== 1'b0) && (timeout < 5000)) begin
        @(posedge clk_i);
        timeout++;
    end
    check((timeout < 5000), "TC1: start bit detected before timeout");

    // Assert reset mid-frame
    @(posedge clk_i);
    arst_ni = 1'b0;
    req_i   = '0;
    resp_o  = '0; 

    //reset_dut();
    @(posedge clk_i);
    check((u_uart_if.rx === 1'b1), "TC1: TX returns to idle immediately after reset");

    // Hold reset
    repeat (5) @(posedge clk_i);

    // Deassert reset
    arst_ni = 1'b1;
    repeat (20) @(posedge clk_i);

    // Check reset state
    axi_read(UART_STAT_OFFSET, status);
    check((status[20] == 1'b1), "TC1: TX_EMPTY after reset");
    check((status[22] == 1'b1), "TC1: RX_EMPTY after reset");
    check((status[9:0]   == 10'd0), "TC1: TX count is 0 after reset");
    check((status[19:10] == 10'd0), "TC1: RX count is 0 after reset");

    // Reconfigure UART after reset so transmission can start again
    configure_uart();

    // Fresh transmission after reset
    axi_write(UART_TXD_OFFSET, 32'h000000C3);
    axi_write(UART_TXD_OFFSET, 32'h000000FF);
    axi_write(UART_TXD_OFFSET, 32'h000000C3);

    timeout = 0;
    
    while ((u_uart_if.rx !== 1'b0) && (timeout < 15000)) begin
        @(posedge clk_i);
        timeout++;
    end
    check((timeout < 15000), "TC1: fresh transmission starts after reset");
endtask