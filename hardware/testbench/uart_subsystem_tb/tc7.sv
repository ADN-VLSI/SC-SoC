task automatic tc7(): //Contionuous TX stream test 
    begin
        
        $display("TC7: UART Subsystem - Continuous TX Stream Test");
        
        ///////////PRECONDITIONS/////////
        $display(" reseting uart for testing");
        // Reset UART configuration before test
        uart_reset();
        $display("configuring uart for continuous transmission mode");
        // no parity bit
        uart_configure_continuous_tx(0); // 0 for no parity, 1 for even parity, 2 for odd parity
        // 8-bit data, 1-stop bit
        uart_configure_data_format(8, 1); // 8 data bits, 1 stop bit

        ////////////TESTING///////////////

        //Pre-fill TX_FIFO with 8-bytes
        //0x00
        //0x11
        //0x22
        //0x33
        //0x44
        //0x55
        //0x66
        //0x77
        byte test_bytes[8] = '{8'h00, 8'h11, 8'h22, 8'h33, 8'h44, 8'h55, 8'h66, 8'h77}; // Example test bytes
        foreach (test_bytes[i]) begin
            uart_send(test_bytes[i]);
            $display("Sent byte: 0x%0h", test_bytes[i]);
        //monitor tx_o for capturing all the transmitted frames using serial decoder
        //While transmission is ongoing, we can also monitor the UART_STAT register to check the status of the TX FIFO and ensure that it is not being emptied as data is transmitted. We can check for the following conditions:
        end
        


                    




    end
endtask


/*
        $display("Sent byte to pre-fill TX FIFO: 0x%0h",&test_bytes(i));
            
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

*/
