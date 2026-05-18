////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Continuous Sequential RX Reception (TC11)
//
//    Description : This testbench verifies the UART receiver's ability to correctly
//                  capture, buffer, and drain a gapless stream of 16 sequential data
//                  frames without loss, corruption, or ordering violation. The test
//                  drives bytes back-to-back at 115741 baud with no idle gap between
//                  frames, stressing the RX FIFO's ability to absorb continuous input
//                  while the AXI host has not yet begun reading.
//
//    Test Flow   :
//                  1. Assert FIFO flush via UART_CTRL to guarantee a clean initial
//                     state, followed by RX/TX enable with adequate settling delay.
//                  2. Drive 16 bytes (0x00, 0x11 ... 0xFF) serially back-to-back
//                     through the UART interface at the configured baud rate with
//                     no inter-frame idle cycles.
//                  3. Poll UART_STAT[19:10] (RX_FIFO_LEVEL) until the count reaches
//                     16, with a 500,000-cycle watchdog timeout to detect stalls.
//                  4. Validate post-reception STATUS flags: RX_FIFO_LEVEL == 16,
//                     RX_EMPTY deasserted, and RX_FULL asserted.
//                  5. Drain all 16 bytes via AXI reads from UART_RXD, verifying each
//                     byte matches the transmitted sequence and RX_EMPTY is not
//                     prematurely asserted; a 2-cycle delay is inserted after every
//                     4th read to model realistic software read latency.
//                  6. Confirm complete buffer drainage: RX_FIFO_LEVEL returns to 0
//                     and RX_EMPTY is asserted after the final AXI read transaction.
//
//
//    Author      : Samir, Motasim Faiyaz & Sheikh Shuparna Haque
//
//    Date        : April 13, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////
task automatic tc11();
    logic [31:0] stat;
    logic [31:0] rx_val;
    int          error_count;
    int          i;

    // Fixed sequence as specified in the test plan
    logic [7:0] tx_seq [16] = '{
        8'h00, 8'h11, 8'h22, 8'h33,
        8'h44, 8'h55, 8'h66, 8'h77,
        8'h88, 8'h99, 8'hAA, 8'hBB,
        8'hCC, 8'hDD, 8'hEE, 8'hFF
    };

    localparam int RX_BAUD = 115741;

    error_count = 0;

    $display("TC11: Continuous Sequential RX Test");

    // ----------------------------------------------------------------
    // Step 0 — ensure clean state (precondition: reset + configure)
    // ----------------------------------------------------------------
    axi_write(UART_CTRL_OFFSET, 32'h0000_0006);   // flush TX + RX FIFOs
    repeat(100) @(posedge clk_i);
    axi_write(UART_CTRL_OFFSET, 32'h0000_0018);   // enable RX + TX
    repeat(100) @(posedge clk_i);

    // ----------------------------------------------------------------
    // Step 1 — Drive 16 bytes back-to-back (no idle gap between frames)
    // ----------------------------------------------------------------
    for (i = 0; i < 16; i++) begin
        u_uart_if.send_tx(tx_seq[i], RX_BAUD);
        // No repeat() here — gapless stream as spec requires
    end

    // ----------------------------------------------------------------
    // Step 2 — Monitor RX_FIFO_LEVEL during / after reception
    //          Poll until all 16 bytes are in the FIFO
    // ----------------------------------------------------------------
    begin
        int timeout = 0;
        do begin
            axi_read(UART_STAT_OFFSET, stat);
            @(posedge clk_i);
            timeout++;
            if (timeout > 500000) begin
                $display("  [FAIL] TC11: Timeout waiting for RX FIFO to fill");
                check(0, "TC11: RX FIFO fill timeout");
                return;
            end
        end while (stat[19:10] < 10'd16);  // wait until LEVEL == 16
    end

    // ----------------------------------------------------------------
    // Step 3 — Check STATUS: RX_FIFO_LEVEL = 16, no error flags
    // ----------------------------------------------------------------
    axi_read(UART_STAT_OFFSET, stat);

    check(stat[19:10] == 10'd16,
          $sformatf("TC11: RX_FIFO_LEVEL = 16 after reception (got %0d)",
                    stat[19:10]));
    check(stat[22] == 1'b0,
          $sformatf("TC11: RX_EMPTY deasserted when FIFO has 16 bytes (STAT=0x%08h)",
                    stat));
    check(stat[23] == 1'b1,
          $sformatf("TC11: RX_FULL asserted when FIFO has 16 bytes (STAT=0x%08h)",
                    stat));

    // ----------------------------------------------------------------
    // Step 4 — Read all 16 bytes and compare to expected sequence
    //          Insert a 2-cycle AXI delay every 4th byte (spec note)
    // ----------------------------------------------------------------
    for (i = 0; i < 16; i++) begin

        // Confirm FIFO is not empty before each read
        axi_read(UART_STAT_OFFSET, stat);
        check(stat[22] == 1'b0,
              $sformatf("TC11: RX_EMPTY not set before read %0d", i));

        axi_read(UART_RXD_OFFSET, rx_val);

        check(rx_val[7:0] === tx_seq[i],
              $sformatf("TC11: Byte[%0d] expected=0x%02h received=0x%02h",
                        i, tx_seq[i], rx_val[7:0]));

        if (rx_val[7:0] !== tx_seq[i])
            error_count++;

        // Spec: 2-cycle delay after every 4th byte to simulate SW latency
        if ((i % 4) == 3)
            repeat(2) @(posedge clk_i);
    end

    // ----------------------------------------------------------------
    // Step 5 — Confirm RX_FIFO_LEVEL = 0 and RX_EMPTY after drain
    // ----------------------------------------------------------------
    axi_read(UART_STAT_OFFSET, stat);

    check(stat[19:10] == 10'd0,
          $sformatf("TC11: RX_FIFO_LEVEL = 0 after drain (got %0d)",
                    stat[19:10]));
    check(stat[22] == 1'b1,
          $sformatf("TC11: RX_EMPTY asserted after drain (STAT=0x%08h)",
                    stat));

    // ----------------------------------------------------------------
    // Summary
    // ----------------------------------------------------------------
    $display("------------------------------------------------------------");
    if (error_count == 0)
        $display(" RESULT: TC11 PASSED — all 16 bytes received in order");
    else
        $display(" RESULT: TC11 FAILED — %0d byte mismatches detected", error_count);
    $display("------------------------------------------------------------");

    check(error_count == 0, "TC11: Sequential RX stream integrity");

endtask