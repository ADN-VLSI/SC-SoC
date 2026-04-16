////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Back-to-Back AXI Transactions (TC4)
//
//    Description : This testbench verifies the UART subsystem’s ability to handle consecutive
//                  AXI write and read operations without inserting idle cycles from the master side.
//                  It ensures that the TX FIFO correctly accepts continuous write transactions and
//                  that register reads return stable and expected values under sustained access.
//
//    Test Flow   :
//                  1. Perform 16 consecutive AXI write transactions to the TX_DATA register
//                     to fill the TX FIFO.
//                  2. Read the STATUS register and verify that TX_FIFO_LEVEL reflects 16 entries.
//                  3. Perform 16 consecutive AXI read transactions from the CTRL register and
//                     verify correct readback value each time.
//                  4. Execute a controlled interleaved sequence of write followed by read
//                     transactions to validate proper operation under mixed traffic conditions.
//                  5. Ensure no data corruption, protocol violation, or unexpected behavior occurs
//                     during continuous transaction flow.
//
//    Author      : Sheikh Shuparna Haque
//
//    Date        : April 13, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////

task automatic tc4();
    logic [31:0] rd_data;
    logic [31:0] status;

    $display("=== TC4: Back-to-Back AXI Transactions ===");

    // 16 consecutive writes
    for (int i = 0; i < 16; i++) begin
        fork
            axi_write(UART_TXD_OFFSET, i);
        join
    end

    

    axi_read(UART_STAT_OFFSET, status);
    check(status[9:0] == 16, "TX_FIFO_LEVEL=16 after writes");

    // 16 consecutive reads
    for (int i = 0; i < 16; i++) begin
        fork
            axi_read(UART_CTRL_OFFSET, rd_data);
        join
        check(rd_data == 32'h00000018, "CTRL readback OK");
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