case(test_name)

  "loop.c": begin
    automatic string intf_tx_str = "ADN\n";
    automatic bit [7:0] data;
    automatic bit       parity;
    do uart_intf.recv_rx(data, parity); while (data !== "\n");
    for (int i = 0; i < intf_tx_str.len(); i++) begin
      uart_intf.send_tx(intf_tx_str[i]);
    end
  end

  "uart.c": begin
    automatic string intf_tx_str = "Hi SC-SoC...!\n";
    automatic bit [7:0] data;
    automatic bit       parity;
    do uart_intf.recv_rx(data, parity); while (data !== "\n");
    for (int i = 0; i < intf_tx_str.len(); i++) begin
      uart_intf.send_tx(intf_tx_str[i]);
    end
  end

  default: $display("\033[1;33mNo specific action or check defined for %s\033[0m", test_name);

endcase
