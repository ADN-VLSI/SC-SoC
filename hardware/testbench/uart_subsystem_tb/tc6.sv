// ============================================================================
// TC6  : Single Byte TX
// Assigned : Adnan
//
// Objective:
//   Verify a byte written to UART_TXD appears correctly on tx_o as a valid
//   UART frame. Tested with 4 patterns: 0x55, 0xAA, 0xFF, 0x00.
//
// How:
//   1. Save and reconfigure CFG/CTRL (baud=115741, TX+RX enable)
//   2. Write byte to TXD — retry until FIFO accepts (BRESP=OKAY)
//   3. Wait for start bit (negedge on tx_o) with timeout guard
//   4. Capture full frame using recv_rx
//   5. Check received data, TX_EMPTY=1, tx_cnt=0
//   6. Restore original CFG and CTRL
// ============================================================================

task automatic tc6();
    logic [31:0] ctrl0, cfg0, stat;
    logic [1:0]  bresp, rresp;
    logic [7:0]  rx_byte;
    logic        rx_parity;
    bit          ok;

    logic [7:0] tx_pat [0:3] = '{8'h55, 8'hAA, 8'hFF, 8'h00};

    // clk_i=100MHz, psclr=4, clk_div=432>>3=54, tx_div=4
    // tx_clk period = 4*54*4 = 864 clk_i cycles
    // 1 frame = 10 bits * 864 = 8640 clk_i cycles + margin
    localparam int TX_TIMEOUT_CYCLES  = 10000;
    localparam int FRAME_TIMEOUT_CY   = 100000; // 10x margin for full frame

    $display("------------------------------------------------------------");
    $display("TC6: SINGLE BYTE TX");
    $display("------------------------------------------------------------");

    cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp); check(rresp == 2'b00, "tc6: read CTRL");
    cpu_read_32(UART_CFG_OFFSET,  cfg0,  rresp); check(rresp == 2'b00, "tc6: read CFG");

    cpu_write_32(UART_CTRL_OFFSET, 32'h0,         bresp); check(bresp == 2'b00, "tc6: CTRL reset");
    repeat (20) @(posedge clk_i);
    cpu_write_32(UART_CFG_OFFSET,  32'h0003_41B0, bresp); check(bresp == 2'b00, "tc6: write CFG");
    repeat (20) @(posedge clk_i);
    cpu_write_32(UART_CTRL_OFFSET, 32'h0000_0018, bresp); check(bresp == 2'b00, "tc6: TX+RX enable");
    repeat (STABILISE_CYCLES) @(posedge clk_i);

    for (int i = 0; i < 4; i++) begin

        // Poll until TXD write accepted
        ok = 0;
        for (int t = 0; t < TX_TIMEOUT_CYCLES; t++) begin
            cpu_write_32(UART_TXD_OFFSET, {24'h0, tx_pat[i]}, bresp);
            if (bresp == 2'b00) begin
                ok = 1;
                break;
            end
            @(posedge clk_i);
        end
        check(ok, $sformatf("tc6: TXD write accepted idx %0d (0x%02h)", i, tx_pat[i]));

        if (ok) begin

            // Wait for start bit (negedge on tx_o) with cycle timeout
            ok = 0;
            fork
                begin
                    @(negedge u_uart_if.rx);
                    ok = 1;
                end
                repeat (FRAME_TIMEOUT_CY) @(posedge clk_i);
            join_any
            disable fork;
            check(ok, $sformatf("tc6: start bit seen idx %0d (0x%02h)", i, tx_pat[i]));

            if (ok) begin
                // Start bit confirmed — now let recv_rx capture the full frame.
                // It uses #(bit_time/2) to re-centre, so rewind half a bit period.
                // recv_rx internally does: wait(rx==0) again from current time,
                // so we call it fresh — it will re-trigger on the same start bit
                // since rx is still low.
                u_uart_if.recv_rx(rx_byte, rx_parity);

                check(rx_byte == tx_pat[i],
                    $sformatf("tc6: wire data idx %0d got=0x%02h exp=0x%02h",
                              i, rx_byte, tx_pat[i]));

                repeat (10) @(posedge clk_i);
                cpu_read_32(UART_STAT_OFFSET, stat, rresp);
                check(rresp    == 2'b00,  $sformatf("tc6: read STAT idx %0d", i));
                check(stat[20] == 1'b1,   $sformatf("tc6: tx_empty=1 after frame idx %0d", i));
                check(stat[9:0] == 10'h0, $sformatf("tc6: tx_cnt=0 after frame idx %0d", i));
            end

        end

    end
    
    cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp); check(bresp == 2'b00, "tc6: restore CFG");
    cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp); check(bresp == 2'b00, "tc6: restore CTRL");

    $display("TC6 DONE");
endtask
