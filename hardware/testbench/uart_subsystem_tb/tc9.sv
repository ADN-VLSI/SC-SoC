// -----------------------------------------------------------------------------
// TC9: TX Configuration Sweep
// -----------------------------------------------------------------------------

task automatic tc9();
    logic [31:0] read_data;
    
    $display("\n[tc9] TX Configuration Sweep");

   
    axi_write(UART_CTRL_OFFSET, 32'h0);
    repeat(20) @(posedge clk_i);

    // Test writing different CFG values
    axi_write(UART_CFG_OFFSET, 32'h0004_405B);  // 8E1
    repeat(10) @(posedge clk_i);
    axi_read(UART_CFG_OFFSET, read_data);
    check((read_data == 32'h0004_405B), "CFG 8E1");

    axi_write(UART_CFG_OFFSET, 32'h0006_405B);  // 8O1
    repeat(10) @(posedge clk_i);
    axi_read(UART_CFG_OFFSET, read_data);
    check((read_data == 32'h0006_405B), "CFG 8O1");

    axi_write(UART_CFG_OFFSET, 32'h0013_405B);  // 8N2
    repeat(10) @(posedge clk_i);
    axi_read(UART_CFG_OFFSET, read_data);
    check((read_data == 32'h0013_405B), "CFG 8N2");

    // Restore default
    axi_write(UART_CFG_OFFSET, 32'h0003_41B0);
    repeat(10) @(posedge clk_i);
    check(1, "CFG restored");

    $display("[tc9] Completed");
endtask