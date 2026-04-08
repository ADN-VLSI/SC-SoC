task automatic tc7(): //Contionuous TX stream test 
    begin
        $display("TC7: UART Subsystem - Continuous TX stream Test");
        // Configure UART for continuous transmission mode
        uart_configure_continuous_tx();

        // Send a series of test bytes
        byte test_bytes[5] = '{8'hA5, 8'h5A, 8'hFF, 8'h00, 8'h3C}; // Example test bytes
        foreach (test_bytes[i]) begin
            uart_send(test_bytes[i]);
            $display("Sent byte: 0x%0h", test_bytes[i]);
        end

        // Wait for all bytes to be transmitted
        wait(uart_transmission_complete());

        // Check if the transmission was successful and no errors occurred
        if (uart_check_transmission_success()) begin
            $display("TC7 PASSED: Continuous TX stream transmitted successfully");
        end else begin
            $display("TC7 FAILED: Error occurred during continuous TX stream transmission");
        end
        // Reset UART configuration after test
        uart_reset();
    end
endtask

