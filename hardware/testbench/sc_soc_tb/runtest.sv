case(test_name)

  "loop.c": begin
    wait_uart_slash_n();
    display_uart("ADN");
  end

  "uart.c": begin
    string tx_txt;
    dut_tx_mbx.get(tx_txt);
    if (tx_txt != "Hello World...!") uart_fault = 1;
    display_uart("Hi SC-SoC...!");
  end

  default: $display("\033[1;33mNo specific action or check defined for %s\033[0m", test_name);

endcase
