////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : Testbench for Power-On Reset (TC0)
//
//    Description : This testbench verifies the UART subsystem's behaviour across the full
//                  power-on reset sequence. It confirms that all output signals are driven to
//                  known logic values while reset is asserted, that register reset values match
//                  RTL-specified defaults upon deassertion, and that the TX line maintains the
//                  UART idle-high (mark) state throughout.
//
//    Test Flow   :
//                  1. Assert arst_ni and hold req_i at zero, then sample 10 consecutive rising
//                     clock edges to confirm the TX line idles high and all AXI response buses
//                     carry no unknown (X) bits during reset.
//                  2. Deassert arst_ni and wait two clock cycles for combinational logic and
//                     synchroniser stages to settle.
//                  3. Read the CTRL register and verify the reset value is 0x00000000.
//                  4. Read the CFG register and verify the reset value matches the RTL default
//                     of 0x0003405B.
//                  5. Read the STATUS register and confirm TX_EMPTY and RX_EMPTY are asserted,
//                     TX_FULL and RX_FULL are deasserted, and both FIFO occupancy counts are zero.
//                  6. Read the RXD register and confirm it returns 0x00000000 when the RX FIFO
//                     is empty.
//                  7. Sample 20 additional rising clock edges to verify the TX line remains
//                     idle-high once normal operation begins.
//                  8. Call configure_uart() to restore standard configuration for subsequent
//                     test cases.
//
//    Author      : Dhruba
//
//    Date        : April 13, 2026
//
///////////////////////////////////////////////////////////////////////////////////////////////////
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
