// ============================================================================
// TC13 : TX Backpressure Handling
// Assigned : Adnan
// Priority : P1
//
// Verify AXI rejects writes when TX FIFO is full:
//   Fill FIFO → TX_FULL=1 → overflow write → SLVERR
//   No corruption → AXI recovers → TX_FULL deasserts after drain
// ============================================================================

task automatic tc13();
    logic [1:0]  resp;
    logic [31:0] stat;
    logic [31:0] ctrl_before;
    logic [31:0] ctrl_after;

    $display("[TC13] TX Backpressure Handling");

    // Step 1: Disable TX so FIFO does not drain during fill
    axi_write(UART_CTRL_OFFSET, 32'h0000_0010); // rx_en=1, tx_en=0
    repeat(10) @(posedge clk_i);

    // Step 2: Fill TX FIFO with exactly FIFO_DEPTH bytes
    for (int i = 0; i < FIFO_DEPTH; i++) begin
        cpu_write_32(UART_TXD_OFFSET, 32'(i), resp);
        check(resp === 2'b00,
              $sformatf("[TC13] fill[%0d] BRESP=OKAY", i));
    end

    // Step 3: Verify TX_FULL=1
    axi_read(UART_STAT_OFFSET, stat);
    check(stat[21] === 1'b1,
          $sformatf("[TC13] TX_FULL=1 after filling (STAT=0x%08h)", stat));

    // Step 4: Snapshot CTRL before overflow
    axi_read(UART_CTRL_OFFSET, ctrl_before);

    // Step 5: Overflow write — expect SLVERR
    cpu_write_32(UART_TXD_OFFSET, 32'h0000_00FF, resp);
    check(resp === 2'b10,
          $sformatf("[TC13] overflow write SLVERR resp=%02b (expect 10)",
                    resp));

    // Step 6: TX_FULL still 1 — no corruption
    axi_read(UART_STAT_OFFSET, stat);
    check(stat[21] === 1'b1,
          "[TC13] TX_FULL still 1 after overflow — no corruption");

    // Step 7: AXI recovers — INT_EN write succeeds after SLVERR
    axi_write(UART_INT_EN_OFFSET, 32'h0000_0000);
    axi_read(UART_INT_EN_OFFSET, stat);
    check(stat === 32'h0000_0000,
          "[TC13] AXI recovers — INT_EN write OK after SLVERR");

    // Step 8: CTRL unchanged by overflow
    axi_read(UART_CTRL_OFFSET, ctrl_after);
    check(ctrl_after === ctrl_before,
          $sformatf("[TC13] CTRL unchanged 0x%08h after overflow",
                    ctrl_after));

    // Step 9: Re-enable TX, drain, verify flags
    axi_write(UART_CTRL_OFFSET, 32'h0000_0018);
    wait_tx_done();
    repeat(200) @(posedge clk_i);

    axi_read(UART_STAT_OFFSET, stat);
    check(stat[21] === 1'b0,
          $sformatf("[TC13] TX_FULL=0 after drain (STAT=0x%08h)", stat));
    check(stat[20] === 1'b1,
          $sformatf("[TC13] TX_EMPTY=1 after drain (STAT=0x%08h)", stat));

    // Step 10: New write accepted after drain
    cpu_write_32(UART_TXD_OFFSET, 32'h0000_00AB, resp);
    check(resp === 2'b00,
          "[TC13] new write OKAY after FIFO drained");

    wait_tx_done();
    repeat(200) @(posedge clk_i);

    $display("[TC13] done");
endtask
