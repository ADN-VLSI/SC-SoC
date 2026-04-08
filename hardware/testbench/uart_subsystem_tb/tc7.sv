task automatic tc7_write_32_checked(
  input logic [15:0] addr,
  input logic [31:0] data,
  input int          timeout_cycles = 1000
);
  logic [1:0] bresp;

  begin
    cpu_write_32(addr, data, bresp);
  end

  if (bresp !== 2'b00) begin
    $fatal(1, "TC7 write failed at 0x%0h with BRESP=%0b", addr, bresp);
  end
endtask

task automatic tc7_read_32_checked(
  input  logic [15:0] addr,
  output logic [31:0] data,
  input  int          timeout_cycles = 1000
);
  logic [1:0] rresp;
  logic [31:0] rdata;

  begin
    cpu_read_32(addr, rdata, rresp);
  end

  if (rresp !== 2'b00) begin
    $fatal(1, "TC7 read failed at 0x%0h with RRESP=%0b", addr, rresp);
  end

  data = rdata;
endtask

task automatic tc7_wait_clk(input int cycles);
  repeat (cycles) @(posedge clk_i);
endtask

task automatic tc7_recv_frame(
  input  realtime    bit_time,
  output logic [7:0] data,
  output realtime    start_time,
  output realtime    stop_end_time
);
  begin
    data = '0;

    if (u_uart_if.rx !== 1'b1)
      wait (u_uart_if.rx === 1'b1);

    @(negedge u_uart_if.rx);
    start_time = $realtime;
    #(bit_time + (bit_time / 2.0));

    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      data[bit_idx] = u_uart_if.rx;
      #(bit_time);
    end

    if (u_uart_if.rx !== 1'b1)
      $fatal(1, "TC7 observed a stop-bit error while decoding tx_o");

    stop_end_time = start_time + (10.0 * bit_time);
  end
endtask

task automatic tc7_run_continuous_stream_case(
  input string        case_name,
  input logic [11:0]  clk_div_val,
  input logic [3:0]   psclr_val
);
  uart_cfg_reg_t  cfg;
  uart_ctrl_reg_t ctrl;
  uart_stat_reg_t stat;

  logic [31:0] cfg_word;
  logic [31:0] ctrl_word;
  logic [31:0] stat_word;

  byte expected_bytes[64];
  byte decoded_byte;
  int total_bytes;
  int bytes_queued;
  int decoded_count;
  int topup_count;
  int baud_rate;
  realtime bit_time;
  realtime prev_stop_end_time;
  realtime frame_start_time;
  realtime stop_end_time;
  realtime gap_time;
  realtime gap_tolerance;

  bit underrun_seen;
  bit idle_error;
  bit early_tx_empty_seen;
  bit tx_empty_seen_before_final_frame;

  begin
    $display("TC7 subcase: %s", case_name);

    total_bytes      = 64;
    bytes_queued     = 0;
    decoded_count    = 0;
    underrun_seen    = 0;
    idle_error       = 0;
    early_tx_empty_seen = 0;
    tx_empty_seen_before_final_frame = 0;
    prev_stop_end_time = 0.0;

    for (int i = 0; i < total_bytes; i++)
      expected_bytes[i] = byte'((i % 16) * 8'h11);

    cfg = '0;
    cfg.db      = 2'b11;       // 8 data bits
    cfg.pen     = 1'b0;        // no parity
    cfg.ptp     = 1'b0;
    cfg.sb      = 1'b0;        // 1 stop bit
    cfg.psclr   = psclr_val;
    cfg.clk_div = clk_div_val;
    cfg_word    = cfg;

    ctrl = '0;
    ctrl.tx_en   = 1'b1;
    ctrl.rx_en   = 1'b0;
    ctrl_word    = ctrl;

    baud_rate = 100_000_000 /
                ((psclr_val == 0) ? 1 : psclr_val) /
                (((clk_div_val >> 3) == 0) ? 1 : (clk_div_val >> 3)) / 4;
    bit_time = 1s / baud_rate;
    gap_tolerance = bit_time / 4.0;

    reset_dut();
    tc7_write_32_checked(UART_CTRL_OFFSET[15:0], 32'h0000_0000);
    tc7_write_32_checked(UART_CFG_OFFSET[15:0], cfg_word);
    tc7_wait_clk(STABILISE_CYCLES);

    for (int i = 0; i < 8; i++) begin
      tc7_write_32_checked(UART_TXD_OFFSET[15:0], {24'h0, expected_bytes[i]});
      bytes_queued++;
    end

    fork
      begin : feeder_thread
        while (bytes_queued < total_bytes) begin
          tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word);
          stat = stat_word;

          if ((decoded_count > 0) && (decoded_count < total_bytes) &&
              (bytes_queued < total_bytes) && stat.tx_empty) begin
            underrun_seen = 1'b1;
          end

          if (stat.tx_cnt < 10'd4) begin
            topup_count = ((total_bytes - bytes_queued) >= 8) ? 8 : (total_bytes - bytes_queued);
            for (int j = 0; j < topup_count; j++) begin
              tc7_write_32_checked(UART_TXD_OFFSET[15:0], {24'h0, expected_bytes[bytes_queued]});
              bytes_queued++;
            end
          end else begin
            @(posedge clk_i);
          end
        end
      end

      begin : last_frame_tx_empty_checker
        while (decoded_count < total_bytes) begin
          tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word);
          stat = stat_word;
          if ((decoded_count < (total_bytes - 1)) && stat.tx_empty)
            tx_empty_seen_before_final_frame = 1'b1;
          @(posedge clk_i);
        end
      end

      begin : decoder_thread
        tc7_write_32_checked(UART_CTRL_OFFSET[15:0], ctrl_word);

        for (int frame = 0; frame < total_bytes; frame++) begin
          tc7_recv_frame(bit_time, decoded_byte, frame_start_time, stop_end_time);

          if (decoded_byte !== expected_bytes[frame]) begin
            $fatal(1,
                   "TC7 %s byte mismatch at index %0d: got 0x%02h expected 0x%02h",
                   case_name, frame, decoded_byte, expected_bytes[frame]);
          end

          if (frame > 0) begin
            gap_time = frame_start_time - prev_stop_end_time;
            if ((gap_time > gap_tolerance) || (gap_time < -gap_tolerance)) begin
              $fatal(1,
                     "TC7 %s observed inter-frame gap %0t at boundary %0d, expected 0 baud periods",
                     case_name, gap_time, frame - 1);
            end
          end

          prev_stop_end_time = stop_end_time;
          decoded_count      = frame + 1;
        end

        u_uart_if.wait_till_idle();
        if (u_uart_if.rx !== 1'b1) begin
          idle_error = 1'b1;
        end
      end
    join

    if (underrun_seen) begin
      $fatal(1, "TC7 %s observed TX FIFO underrun while software was topping up", case_name);
    end

    if (idle_error) begin
      $fatal(1, "TC7 %s tx_o did not return to idle HIGH after the last frame", case_name);
    end

    if (tx_empty_seen_before_final_frame || early_tx_empty_seen) begin
      $fatal(1, "TC7 %s STATUS.TX_EMPTY asserted before the last stop bit completed", case_name);
    end

    tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word);
    stat = stat_word;
    if (!stat.tx_empty) begin
      $fatal(1, "TC7 %s STATUS.TX_EMPTY was not asserted after the stream completed", case_name);
    end

    if (stat.tx_cnt !== 10'd0) begin
      $fatal(1, "TC7 %s STATUS.TX_CNT expected 0 after completion, got %0d", case_name, stat.tx_cnt);
    end

    $display("TC7 subcase passed: %s", case_name);
  end
endtask

task automatic tc7();
  begin
    $display("TC7: UART Subsystem - Continuous TX Stream");

    tc7_run_continuous_stream_case("fastest baud", 12'd8, 4'd1);
    tc7_run_continuous_stream_case("slowest baud", 12'd4095, 4'd15);

    $display("TC7 completed successfully");
  end
endtask
