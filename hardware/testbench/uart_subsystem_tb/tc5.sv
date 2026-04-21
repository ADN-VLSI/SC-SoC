////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Concurrent AXI Transactions (TC5)
//
//    Description : This testbench verifies the UART subsystem's ability to handle simultaneous
//                  AXI write and read operations without causing deadlocks, data corruption,
//                  or AXI protocol violations. It ensures that concurrent access to the TX and
//                  RX paths through the shared AXI interface does not compromise the integrity
//                  of either the data path or the status reporting logic.
//
//    Test Flow   :
//                  1. Perform 4 concurrent AXI write transactions to the TX_DATA register and
//                     verify that the TX FIFO has accepted the bytes by confirming TX_EMPTY
//                     is deasserted.
//                  2. Issue 4 rounds of simultaneous AXI writes to TX_DATA and AXI reads from
//                     RX_DATA using fork/join_none to create true concurrent bus activity.
//                  3. Verify that the STATUS register remains fully defined (no X bits) after
//                     all concurrent accesses complete.
//                  4. Execute a maximum FIFO fill stress test by spawning 10 concurrent write
//                     and read pairs to hammer the AXI bus simultaneously, then confirm STATUS
//                     register integrity after the storm.
//                  5. Wait for the TX FIFO to fully drain and confirm TX_EMPTY is asserted,
//                     ensuring no deadlock occurred during or after concurrent access.
//
//    Author      : Sheikh Shuparna Haque & Adnan Sami Anirban
//
//    Date        : April 21, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////

task automatic tc5();
    logic [31:0] rd_data;
    logic [31:0] status;
    uart_stat_reg_t stat;

    logic [7:0] preload [4] = '{8'h11, 8'h22, 8'h33, 8'h44};
    logic [7:0] tx_data [4] = '{8'hAA, 8'hBB, 8'hCC, 8'hDD};


    $display("=== TC5: Concurrent AXI Access ===");

    // Pre-load TX FIFO with 4 bytes and verify they are queued
    for (int i = 0; i < 4; i++) begin
        fork
            axi_write(UART_TXD_OFFSET, {24'h0, preload[i]});
        join_none
        #1ns;
    end
    axi_write(-1, -1); // barrier

    // Verify TX FIFO has accepted the bytes (tx_cnt or tx_empty deasserted)
    axi_read(UART_STAT_OFFSET, rd_data);
    stat = uart_stat_reg_t'(rd_data);
    check(stat.tx_empty == 1'b0,
          $sformatf("TX active after preload writes (tx_cnt=%0d)", stat.tx_cnt));

    // Concurrent TX writes and RX reads — 4 rounds
    for (int i = 0; i < 4; i++) begin
        fork
            axi_write(UART_TXD_OFFSET, {24'h0, tx_data[i]});
            axi_read(UART_RXD_OFFSET, rd_data);
        join_none
        #1ns;
    end

    fork
        axi_write(-1, -1);
        axi_read(UART_RXD_OFFSET, rd_data);
    join
    check(^rd_data !== 1'bx, "RX data valid during concurrent access");

    axi_read(UART_STAT_OFFSET, rd_data);
    stat = uart_stat_reg_t'(rd_data);
    check(^rd_data !== 1'bx, "STATUS defined after concurrent accesses");

    // Max FIFO fill stress
    for (int i = 0; i < 10; i++) begin
        fork
            axi_write(UART_TXD_OFFSET, 32'hABCD0000 + i);
            axi_read(UART_RXD_OFFSET, rd_data);
        join_none
        #1ns;
    end
    fork
        axi_write(-1, -1);
        axi_read(UART_STAT_OFFSET, rd_data);
    join
    stat = uart_stat_reg_t'(rd_data);
    check(^rd_data !== 1'bx, "STATUS valid after max-fill stress");

    // Drain TX and confirm TX_EMPTY
    wait_tx_done();
    axi_read(UART_STAT_OFFSET, rd_data);
    stat = uart_stat_reg_t'(rd_data);
    check(stat.tx_empty == 1'b1, "TX_EMPTY asserted after drain");

    $display("=== TC5 Completed ===");
endtask