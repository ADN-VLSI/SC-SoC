////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Mid-Operation Reset Handling (TC1)
//
//    Description : This testbench verifies the UART subsystem’s robustness when an asynchronous
//                  reset is asserted during an active transmission. It ensures that the transmitter
//                  halts immediately, the TX line returns to idle, all FIFOs are cleared, and the
//                  system recovers to a clean state after reset deassertion. It also validates that
//                  normal operation resumes correctly with a fresh transmission.
//
//    Test Flow   :
//                  1. Preload TX FIFO with multiple data bytes via AXI writes.
//                  2. Monitor UART TX line (rx signal in loopback) and wait for start bit detection,
//                     confirming that transmission has begun.
//                  3. Assert asynchronous reset (arst_ni = 0) during active transmission.
//                  4. On the next clock cycle, verify that TX immediately returns to idle (logic HIGH).
//                  5. Hold reset for a fixed number of clock cycles.
//                  6. Deassert reset (arst_ni = 1) and allow the system to stabilize.
//                  7. Read STATUS register and verify:
//                     - TX FIFO is empty
//                     - RX FIFO is empty
//                     - FIFO counters are cleared
//                  8. Reconfigure UART settings after reset.
//                  9. Perform new AXI writes to initiate a fresh transmission.
//                 10. Verify that transmission starts correctly within a timeout period.
//
//    Key Focus   :
//                  - Asynchronous reset behavior during active UART transmission
//                  - Immediate TX line recovery to idle state
//                  - FIFO and status register reset integrity
//                  - System recovery and reconfiguration after reset
//                  - Clean restart of transmission without residual state
//
//    Author      : Sheikh Shuparna Haque
//
//    Date        : April 15, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////

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
    arst_ni = 1'b0;
    req_i   = '0;
    resp_o  = '0; 

    //reset_dut();
    @(posedge clk_i);
    check((u_uart_if.rx === 1'b1), "TC1: TX returns to idle immediately after reset");

    // Hold reset
    #5ns; // Hold reset for a fixed duration
    // Deassert reset
    arst_ni = 1'b1;
    
    #20ns; // Allow time for system to stabilize after reset deassertion
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