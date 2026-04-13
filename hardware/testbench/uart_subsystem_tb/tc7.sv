task automatic tc7_write_32_checked(
  input  logic [15:0] addr,
  input  logic [31:0] data,
  output bit          ok
);
  logic [1:0] bresp;

  begin
    cpu_write_32(addr, data, bresp);
    ok = (bresp === 2'b00);
  end
endtask

task automatic tc7_read_32_checked(
  input  logic [15:0] addr,
  output logic [31:0] data,
  output bit          ok
);
  logic [1:0] rresp;

  begin
    cpu_read_32(addr, data, rresp);
    ok = (rresp === 2'b00);
  end
endtask

task automatic tc7_wait_clk(input int cycles);
  repeat (cycles) @(posedge clk_i);
endtask

task automatic tc7_configure_uart_if(
  input int baud_rate
);
  begin
    u_uart_if.BAUD_RATE       = baud_rate;
    u_uart_if.PARITY_ENABLE   = 1'b0;
    u_uart_if.PARITY_TYPE     = 1'b0;
    u_uart_if.SECOND_STOP_BIT = 1'b0;
    u_uart_if.DATA_BITS       = 8;
  end
endtask

task automatic tc7_recv_frame(
  input  realtime    bit_time,
  output logic [7:0] data,
  output realtime    start_time,
  output realtime    stop_end_time,
  output bit         ok
);
  bit start_seen;

  begin
    data          = '0;
    start_time    = 0.0;
    stop_end_time = 0.0;
    ok            = 1'b1;
    start_seen    = 1'b0;

    fork : wait_for_start
      begin
        if (u_uart_if.rx !== 1'b1)
          wait (u_uart_if.rx === 1'b1);
        @(negedge u_uart_if.rx);
        start_time = $realtime;
        start_seen = 1'b1;
      end
      begin
        #(12.0 * bit_time);
      end
    join_any
    disable wait_for_start;

    if (!start_seen) begin
      ok = 1'b0;
      return;
    end

    #(bit_time + (bit_time / 2.0));
    for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
      data[bit_idx] = u_uart_if.rx;
      #(bit_time);
    end

    if (u_uart_if.rx !== 1'b1) begin
      ok = 1'b0;
      return;
    end

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
  logic [7:0] decoded_byte;
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
  realtime timeout_window;

  bit setup_ok;
  bit io_ok;
  bit feeder_done;
  bit decoder_done;
  bit tx_empty_watcher_done;
  bit decoder_timed_out;
  bit underrun_seen;
  bit idle_error;
  bit tx_empty_seen_before_final_frame;
  bit decode_ok;
  bit mismatch_seen;
  bit gap_error_seen;

  begin
    $display("TC7 subcase: %s", case_name);

    total_bytes                    = 64;
    bytes_queued                   = 0;
    decoded_count                  = 0;
    underrun_seen                  = 1'b0;
    idle_error                     = 1'b0;
    tx_empty_seen_before_final_frame = 1'b0;
    feeder_done                    = 1'b0;
    decoder_done                   = 1'b0;
    tx_empty_watcher_done          = 1'b0;
    decoder_timed_out              = 1'b0;
    mismatch_seen                  = 1'b0;
    gap_error_seen                 = 1'b0;
    prev_stop_end_time             = 0.0;
    setup_ok                       = 1'b1;

    for (int i = 0; i < total_bytes; i++)
      expected_bytes[i] = byte'((i % 16) * 8'h11);

    cfg = '0;
    cfg.db      = 2'b11;
    cfg.pen     = 1'b0;
    cfg.ptp     = 1'b0;
    cfg.sb      = 1'b0;
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
    timeout_window = bit_time * 14.0 * total_bytes;

    reset_dut();
    tc7_configure_uart_if(baud_rate);

    tc7_write_32_checked(UART_CTRL_OFFSET[15:0], 32'h0000_0000, io_ok);
    testcase_check(io_ok, $sformatf("TC7 %s disabled UART before configuration", case_name));
    setup_ok &= io_ok;

    tc7_write_32_checked(UART_CFG_OFFSET[15:0], cfg_word, io_ok);
    testcase_check(io_ok,
                   $sformatf("TC7 %s programmed UART_CFG=0x%08h", case_name, cfg_word));
    setup_ok &= io_ok;
    testcase_check(u_uart_if.BAUD_RATE == baud_rate,
                   $sformatf("TC7 %s decoder baud rate aligned to %0d", case_name, baud_rate));

    tc7_wait_clk(STABILISE_CYCLES);

    if (setup_ok) begin
      for (int i = 0; i < 8; i++) begin
        tc7_write_32_checked(UART_TXD_OFFSET[15:0], {24'h0, expected_bytes[i]}, io_ok);
        setup_ok &= io_ok;
      end
      bytes_queued = 8;
      testcase_check(setup_ok,
                     $sformatf("TC7 %s pre-filled TX FIFO with first 8 bytes", case_name));
    end else begin
      testcase_check(1'b0,
                     $sformatf("TC7 %s setup failed before FIFO prefill", case_name));
    end

    if (setup_ok) begin
      fork
        begin : feeder_thread
          while (bytes_queued < total_bytes) begin
            tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word, io_ok);
            if (!io_ok) begin
              underrun_seen = 1'b1;
              break;
            end
            stat = stat_word;

            if ((decoded_count > 0) && (decoded_count < total_bytes) &&
                (bytes_queued < total_bytes) && stat.tx_empty) begin
              underrun_seen = 1'b1;
            end

            if (stat.tx_cnt < 10'd4) begin
              topup_count = ((total_bytes - bytes_queued) >= 8) ? 8 : (total_bytes - bytes_queued);
              for (int j = 0; j < topup_count; j++) begin
                tc7_write_32_checked(UART_TXD_OFFSET[15:0], {24'h0, expected_bytes[bytes_queued]}, io_ok);
                if (!io_ok) begin
                  underrun_seen = 1'b1;
                  break;
                end
                bytes_queued++;
              end
            end else begin
              @(posedge clk_i);
            end
          end
          feeder_done = 1'b1;
        end

        begin : last_frame_tx_empty_checker
          while (decoded_count < total_bytes) begin
            tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word, io_ok);
            if (!io_ok) begin
              tx_empty_seen_before_final_frame = 1'b1;
              break;
            end
            stat = stat_word;
            if ((decoded_count < (total_bytes - 1)) && stat.tx_empty)
              tx_empty_seen_before_final_frame = 1'b1;
            @(posedge clk_i);
          end
          tx_empty_watcher_done = 1'b1;
        end

        begin : decoder_thread
          tc7_write_32_checked(UART_CTRL_OFFSET[15:0], ctrl_word, io_ok);
          if (!io_ok) begin
            mismatch_seen = 1'b1;
            decoder_done  = 1'b1;
            disable decoder_thread;
          end

          for (int frame = 0; frame < total_bytes; frame++) begin
            tc7_recv_frame(bit_time, decoded_byte, frame_start_time, stop_end_time, decode_ok);

            if (!decode_ok) begin
              mismatch_seen = 1'b1;
              break;
            end

            if (decoded_byte !== expected_bytes[frame]) begin
              mismatch_seen = 1'b1;
            end

            if (frame > 0) begin
              gap_time = frame_start_time - prev_stop_end_time;
              if ((gap_time > gap_tolerance) || (gap_time < -gap_tolerance)) begin
                gap_error_seen = 1'b1;
              end
            end

            prev_stop_end_time = stop_end_time;
            decoded_count      = frame + 1;
          end

          u_uart_if.wait_till_idle();
          if (u_uart_if.rx !== 1'b1)
            idle_error = 1'b1;
          decoder_done = 1'b1;
        end

        begin : timeout_thread
          #(timeout_window);
          if (!decoder_done)
            decoder_timed_out = 1'b1;
        end
      join_none
      wait (decoder_done || decoder_timed_out);
      disable fork;
    end

    testcase_check(setup_ok,
                   $sformatf("TC7 %s setup completed successfully", case_name));
    testcase_check(feeder_done,
                   $sformatf("TC7 %s feeder thread completed all queueing", case_name));
    testcase_check(decoder_done && !decoder_timed_out,
                   $sformatf("TC7 %s decoded stream completed without timeout", case_name));
    testcase_check(decoded_count == total_bytes,
                   $sformatf("TC7 %s decoded %0d/%0d frames", case_name, decoded_count, total_bytes));
    testcase_check(!mismatch_seen,
                   $sformatf("TC7 %s all decoded bytes matched expected order", case_name));
    testcase_check(!gap_error_seen,
                   $sformatf("TC7 %s observed no inter-frame gaps while FIFO was fed", case_name));
    testcase_check(!underrun_seen,
                   $sformatf("TC7 %s observed no TX FIFO underrun during top-up", case_name));
    testcase_check(!tx_empty_seen_before_final_frame,
                   $sformatf("TC7 %s STATUS.TX_EMPTY stayed low until final frame", case_name));
    testcase_check(!idle_error,
                   $sformatf("TC7 %s tx_o returned to idle HIGH after the stream", case_name));

    tc7_read_32_checked(UART_STAT_OFFSET[15:0], stat_word, io_ok);
    testcase_check(io_ok,
                   $sformatf("TC7 %s final STATUS read completed", case_name));
    if (io_ok) begin
      stat = stat_word;
      testcase_check(stat.tx_empty,
                     $sformatf("TC7 %s STATUS.TX_EMPTY asserted after completion", case_name));
      testcase_check(stat.tx_cnt === 10'd0,
                     $sformatf("TC7 %s STATUS.TX_CNT drained to 0 (got %0d)",
                               case_name, stat.tx_cnt));
    end else begin
      testcase_check(1'b0,
                     $sformatf("TC7 %s final STATUS contents unavailable", case_name));
      testcase_check(1'b0,
                     $sformatf("TC7 %s final TX count unavailable", case_name));
    end
  end
endtask

task automatic tc7();
  begin
    testcase_begin("TC7");
    tc7_run_continuous_stream_case("fastest baud", 12'd8, 4'd1);
    tc7_run_continuous_stream_case("slowest baud", 12'd4095, 4'd15);
    testcase_end();
  end
endtask
