task automatic tc4();
    logic [31:0] rd_data;
    logic [31:0] status;

    $display("=== TC4: Back-to-Back AXI Transactions ===");

    // 16 consecutive writes
    for (int i = 0; i < 16; i++) begin
        fork
            axi_write(UART_TXD_OFFSET, i);
        join_none
        #1ns;
    end

    axi_write(-1, -1);

    axi_read(UART_STAT_OFFSET, status);
    check(status[9:0] == 16, "TX_FIFO_LEVEL=16 after writes");

    // 16 consecutive reads
    for (int i = 0; i < 16; i++) begin
        fork
            axi_read(UART_CTRL_OFFSET, rd_data);
        join_none
        check(rd_data == 32'h00000018, "CTRL readback OK");
        #1ns;
    end

    // Interleaved sequence
    for (int i = 0; i < 10; i++) begin
        fork
            begin
                axi_write(UART_TXD_OFFSET, 32'hABCD0000 + i);
                axi_read(UART_CTRL_OFFSET, rd_data);
                check(rd_data == 32'h00000018, "CTRL readback during interleave OK");
            end
        join_none
        #1ns;
    end

    $display("=== TC4 Completed ===");
endtask