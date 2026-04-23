task automatic tc11();
    logic [1:0]  resp;
    logic [31:0] stat;
    logic [31:0] rx_val;
    logic [7:0]  sent_data;
    logic [7:0]  expected_queue[$]; 
    int i;
    int error_count = 0;

    // Timing for 115741 Baud @ 100MHz (Divider = 864)
    localparam int BIT_CYCLES = 864; 
    localparam int RX_BAUD    = 115741;

    $display("[TC11] Starting Continuous Sequential Rx Test");

    // 1. Configure Hardware via AXI-Lite
    // Set the baud rate divider directly in the CFG register
    axi_write(UART_CFG_OFFSET, 32'(BIT_CYCLES)); 
    
    // 2. Initialize Control Register
    // Flush FIFOs first
    axi_write(UART_CTRL_OFFSET, 32'h0000_0006); 
    repeat(100) @(posedge clk_i);
    // Enable RX and TX paths
    axi_write(UART_CTRL_OFFSET, 32'h0000_0018); 
    repeat(100) @(posedge clk_i);

    // 3. Drive 16 Sequential Bytes into UART RX
    // This simulates a high-traffic stream of data
    for (i = 0; i < 16; i++) begin
        sent_data = $urandom_range(0, 255);
        expected_queue.push_back(sent_data);

        // Align the first bit to the middle of the clock for stability
        if (i == 0) repeat(BIT_CYCLES / 2) @(posedge clk_i);

        u_uart_if.send_tx(sent_data, RX_BAUD);
        
        // Provide a 1-bit IDLE period to ensure the RX FSM resets correctly
        repeat(BIT_CYCLES) @(posedge clk_i);
    end

    // 4. Synchronization Grace Period
    u_uart_if.wait_till_idle();
    repeat(500) @(posedge clk_i); 

    // 5. Sequential Read & Verify via AXI-Lite
    // Pulling data out of the RX FIFO one transaction at a time
    for (i = 0; i < 16; i++) begin
        axi_read(UART_RXD_OFFSET, rx_val);
        sent_data = expected_queue.pop_front();

        if (rx_val[7:0] !== sent_data) begin
            $display("  [FAIL] Data Mismatch at Index %0d: Expected 0x%02h, Received 0x%02h", i, sent_data, rx_val[7:0]);
            error_count++;
        end
        
        // Minor delay to simulate AXI-Lite bus arbitration
        repeat(5) @(posedge clk_i);
    end

    // 6. Summary Report
    $display("------------------------------------------------------------");
    if (error_count == 0) 
        $display(" RESULT: TC11 PASSED (Successful Sequential Transfers)");
    else 
        $display(" RESULT: TC11 FAILED (Detected %0d errors)", error_count);
    $display("------------------------------------------------------------\n");

    check(error_count == 0, "TC11 Sequential Integrity");
endtask