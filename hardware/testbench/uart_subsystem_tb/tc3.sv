

task automatic tc3(); //AXI Invalid_Address_Test
    begin
        $display("TC3: AXI Invalid Address Test");
        // Configure AXI master to send a transaction to an invalid address
        axi_configure_invalid_address();
        // Send a test transaction
        axi_send_transaction();
        // Wait for the response        wait(axi_response_received());
        // Check if the response indicates an error
        if (axi_check_error_response()) begin
            $display("TC3 PASSED: Received error response for invalid address");
        end else begin
            $display("TC3 FAILED: Did not receive error response for invalid address");
        `end
        // Reset AXI configuration after test
        axi_reset();     
    end
endtask


/*
        $display("TC3: UART Subsystem - Loopback Test");
        // Configure UART for loopback mode
        uart_configure_loopback();

        // Send a test byte
        byte test_byte = 8'hA5; // Example test byte
        uart_send(test_byte);

        // Wait for the byte to be received back
        wait(uart_data_received());

        // Read the received byte
        byte received_byte = uart_read();

        // Check if the received byte matches the sent byte
        if (received_byte == test_byte) begin
            $display("TC3 PASSED: Received byte matches sent byte (0x%0h)", received_byte);
        end else begin
            $display("TC3 FAILED: Received byte (0x%0h) does not match sent byte (0x%0h)", received_byte, test_byte);
        end

        // Reset UART configuration after test
        uart_reset();

*/
