task automatic tc8(); //TX FIFO Full test
    begin
        $display("TC8: UART Subsystem - TX FIFO Full Test");
        // Configure UART for normal transmission mode
        uart_configure_normal_tx();

        // Fill the TX FIFO to its maximum capacity
        for (int i = 0; i < UART_TX_FIFO_DEPTH; i++) begin
            uart_send(8'hA5); // Example test byte
            $display("Sent byte to fill TX FIFO: 0x%0h", 8'hA5);
        end

        // Attempt to send one more byte to trigger FIFO full condition
        uart_send(8'h5A); // This byte should trigger the FIFO full condition
        $display("Attempted to send byte: 0x%0h", 8'h5A);

        // Wait for the response indicating FIFO full condition
        wait(uart_fifo_full_response());

        // Check if the response indicates that the FIFO is full
        if (uart_check_fifo_full_response()) begin
            $display("TC8 PASSED: Received FIFO full response as expected");
        end else begin
            $display("TC8 FAILED: Did not receive FIFO full response when expected");
        end

        // Reset UART configuration after test
        uart_reset();
    end
endtask