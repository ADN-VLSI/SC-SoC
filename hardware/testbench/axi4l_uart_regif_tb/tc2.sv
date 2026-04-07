// tc2.sv - Write TXD and check tx_data signals
// tx_data_valid_o is combinational and pulse-only (high only during write-fire).

task automatic tc2(inout int p, inout int f);
  logic [7:0] exp_val;
  logic       captured_valid;
  logic [7:0] captured_data;
  p = 0; f = 0;

  $display("TC2: Write TXD and check tx_data signals");

  exp_val        = 8'hEE;
  captured_valid = 1'b0;
  captured_data  = '0;

  tx_data_ready_i = 1'b1;
  @(posedge clk_i);

  fork
    begin
      // Thread A: perform the write
      write_32(UART_TXD_OFFSET, {24'd0, exp_val}, 1000);
    end
    begin
      // Thread B: sample tx_data_valid_o each cycle during the write
      repeat (1000) begin
        @(posedge clk_i);
        if (tx_data_valid_o) begin
          captured_valid = 1'b1;
          captured_data  = tx_data_o.data;
        end
      end
    end
  join

  $display("  captured tx_data_o = 0x%0h  tx_data_valid_o = %0b",
           captured_data, captured_valid);

  if (captured_valid && captured_data == exp_val) begin
    $display("  TXD accepted by DUT"); p++;
  end else begin
    $display("  TXD not accepted"); f++;
  end

  @(posedge clk_i);
endtask