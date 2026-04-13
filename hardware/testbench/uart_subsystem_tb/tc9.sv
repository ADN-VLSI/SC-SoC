task automatic tc9();
    // Registers
    logic [31:0] ctrl0, cfg0, cfg, rd;
    logic [1:0]  bresp, rresp;
    int bitcy;

    // Desired baud rate
    int unsigned BAUD = 115200; // change as needed
    int unsigned CLK_FREQ = 100_000_000; // 100 MHz
    int unsigned baud_div;

    $display("------------------------------------------------------------");
    $display("TC9: TX CONFIG SWEEP");
    $display("------------------------------------------------------------");

    // Save current configuration
    cpu_read_32(UART_CTRL_OFFSET, ctrl0, rresp);
    cpu_read_32(UART_CFG_OFFSET,  cfg0,  rresp);

    // Compute bit cycles (for simulation delay)
    bitcy = CLK_FREQ / BAUD; // approximate cycles per bit

    // Sweep configurations
    for (int c = 0; c < 6; c++) begin
        // Base config: parity, stop bits, data bits
        case (c)
            0: cfg = 32'h0000_0000; // 8N1 placeholder
            1: cfg = 32'h0000_1000; // 8E1
            2: cfg = 32'h0000_2000; // 8O1
            3: cfg = 32'h0000_3000; // 8N2
            4: cfg = 32'h0000_4000; // 7E1
            5: cfg = 32'h0000_5000; // 7O2
        endcase

        // Add baud divisor
        baud_div = CLK_FREQ / BAUD;
        cfg[15:0] = baud_div[15:0]; // assume lower 16 bits hold baud divisor

        // Disable, flush, configure, enable
        cpu_write_32(UART_CTRL_OFFSET, 32'h0, bresp);   // disable
        repeat (10) @(posedge clk_i);
        cpu_write_32(UART_CTRL_OFFSET, 32'h6, bresp);   // flush
        repeat (10) @(posedge clk_i);
        cpu_write_32(UART_CFG_OFFSET, cfg, bresp);      // write config
        repeat (10) @(posedge clk_i);
        cpu_write_32(UART_CTRL_OFFSET, 32'h18, bresp);  // enable
        repeat (bitcy * 4) @(posedge clk_i);            // wait

        // Verify config
        cpu_read_32(UART_CFG_OFFSET, rd, rresp);
        check(rd == cfg, $sformatf("cfg%0d accepted: 0x%08h", c, rd));

        // Test TX write
        cpu_write_32(UART_TXR_OFFSET, 32'h55, bresp);
        check(bresp == 2'b00, $sformatf("cfg%0d TXR write BRESP=OK", c));

        repeat (bitcy * 4) @(posedge clk_i); // allow TX to finish
    end

    // Restore original config
    cpu_write_32(UART_CTRL_OFFSET, ctrl0, bresp);
    cpu_write_32(UART_CFG_OFFSET,  cfg0,  bresp);
endtask