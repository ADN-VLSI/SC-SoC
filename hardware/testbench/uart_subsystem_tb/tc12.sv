////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for RX FIFO Overflow (TC12)
//
//    Description : This testbench verifies the UART receiver's behavior when the RX FIFO is
//                  filled to capacity and an additional byte is transmitted. It ensures that
//                  the FIFO enforces its depth limit by silently dropping overflow bytes,
//                  maintains a stable entry count at maximum capacity, and correctly returns
//                  to an empty state after all valid entries have been drained.
//
//    Test Flow   :
//                  1. Reset the DUT and apply standard UART configuration, then idle the TX
//                     line high for 100 cycles to establish a clean line state.
//                  2. Drive exactly FIFO_DEPTH bytes over u_uart_if.tx using tc12_drive_byte(),
//                     with a 200-cycle inter-byte settling gap after each transmission.
//                  3. Poll UART_STAT[19:10] until the RX count reaches FIFO_DEPTH, with a
//                     300,000-cycle timeout, then verify the count matches FIFO_DEPTH.
//                  4. Transmit one additional byte (0xFF) and after 5,000 settling cycles
//                     confirm the RX count remains unchanged at FIFO_DEPTH.
//                  5. Drain all FIFO_DEPTH entries via cpu_read_32() and verify each read
//                     returns an AXI OKAY response, confirming all ok_reads == FIFO_DEPTH.
//                  6. Poll UART_STAT[19:10] until the RX count returns to 0 within a
//                     50,000-cycle timeout, confirming the FIFO is fully empty.
//
//    Author      : Dhruba
//
//    Date        : 15 April 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////


task automatic tc12_drive_byte(input logic [7:0] d);
    int k;

    // idle
    force u_uart_if.tx = 1'b1;
    repeat (864) @(posedge clk_i);
    release u_uart_if.tx;

    // start
    force u_uart_if.tx = 1'b0;
    repeat (864) @(posedge clk_i);
    release u_uart_if.tx;

    // data bits LSB-first
    for (k = 0; k < 8; k++) begin
        if (d[k]) force u_uart_if.tx = 1'b1;
        else      force u_uart_if.tx = 1'b0;
        repeat (864) @(posedge clk_i);
        release u_uart_if.tx;
    end

    // stop
    force u_uart_if.tx = 1'b1;
    repeat (864) @(posedge clk_i);
    release u_uart_if.tx;
endtask


task automatic tc12();
    logic [31:0] stat, rdata;
    logic [1:0]  resp;
    int i, timeout, ok_reads;

    $display("TC12: RX FIFO Overflow");

    reset_dut();
    configure_uart();

    force u_uart_if.tx = 1'b1;
    repeat (100) @(posedge clk_i);
    release u_uart_if.tx;

    // Fill FIFO with FIFO_DEPTH bytes
    for (i = 0; i < FIFO_DEPTH; i++) begin
        tc12_drive_byte(i[7:0]);
        repeat (200) @(posedge clk_i);
    end

    // Wait until RX count reaches FIFO_DEPTH
    timeout = 0;
    while (timeout < 300000) begin
        axi_read(UART_STAT_OFFSET, stat);
        if (stat[19:10] == FIFO_DEPTH) break;
        @(posedge clk_i);
        timeout++;
    end

    check(timeout < 300000,
          $sformatf("TC12: RX count reached FIFO_DEPTH=%0d", FIFO_DEPTH));
    check(stat[19:10] == FIFO_DEPTH,
          $sformatf("TC12: RX count is FIFO_DEPTH after fill (STAT=0x%08h)", stat));

    // Send one extra byte to cause overflow
    tc12_drive_byte(8'hFF);
    repeat (5000) @(posedge clk_i);

    axi_read(UART_STAT_OFFSET, stat);
    check(stat[19:10] == FIFO_DEPTH,
          $sformatf("TC12: RX count remains FIFO_DEPTH after overflow byte (STAT=0x%08h)", stat));

    // Drain exactly FIFO_DEPTH entries
    ok_reads = 0;
    for (i = 0; i < FIFO_DEPTH; i++) begin
        cpu_read_32(UART_RXD_OFFSET, rdata, resp);
        check(resp == 2'b00,
              $sformatf("TC12: RX read %0d completed OKAY", i));
        if (resp == 2'b00) ok_reads++;
    end

    check(ok_reads == FIFO_DEPTH,
          $sformatf("TC12: exactly %0d RX reads completed after overflow", FIFO_DEPTH));

    // After draining, RX count should return to 0
    timeout = 0;
    while (timeout < 50000) begin
        axi_read(UART_STAT_OFFSET, stat);
        if (stat[19:10] == 0) break;
        @(posedge clk_i);
        timeout++;
    end

    check(stat[19:10] == 0,
          $sformatf("TC12: RX count is 0 after draining FIFO (STAT=0x%08h)", stat));

    force u_uart_if.tx = 1'b1;
    repeat (20) @(posedge clk_i);
    release u_uart_if.tx;
endtask