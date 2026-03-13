//////////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Module      : delay_gen Testbench
//   Last Update : February 19, 2026
//
//   Description : Verifies the delay_gen module by checking:
//                   1. enable_o is suppressed until DELAY_CYCLES real-time clock cycles have passed.
//                   2. enable_o follows enable_i only after the delay has expired.
//                   3. Mid-operation async reset clears enable_o and restarts the counter.
//                   4. enable_o stays low when enable_i is deasserted even after the delay expires.
//
//   Author      : Sonet 4.6
//
//////////////////////////////////////////////////////////////////////////////////////////////////////

module delay_gen_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Parameters
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int DELAY_CYCLES = 10;
  localparam realtime RT_CLK_PERIOD = 1us;  // real_time_clk_i: 1 MHz
  localparam realtime CLK_PERIOD = 10ns;  // clk_i 100 MHz

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT signals
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;
  logic real_time_clk_i;
  logic clk_i;
  logic enable_i;
  logic enable_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT instantiation
  //////////////////////////////////////////////////////////////////////////////////////////////////

  delay_gen #(
      .DELAY_CYCLES(DELAY_CYCLES)
  ) dut (
      .arst_ni        (arst_ni),
      .real_time_clk_i(real_time_clk_i),
      .clk_i          (clk_i),
      .enable_i       (enable_i),
      .enable_o       (enable_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Clock generation
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial real_time_clk_i = 0;
  always #(RT_CLK_PERIOD / 2) real_time_clk_i = ~real_time_clk_i;

  initial clk_i = 0;
  always #(CLK_PERIOD / 2) clk_i = ~clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Wait for N rising edges of clk_i
  task automatic wait_clk(input int n = 1);
    repeat (n) @(posedge clk_i);
  endtask

  // Wait for N rising edges of real_time_clk_i
  task automatic wait_rt_clk(input int n = 1);
    repeat (n) @(posedge real_time_clk_i);
  endtask

  // Apply async reset for 2 rt-clock cycles, then release
  task automatic apply_reset();
    arst_ni <= 0;
    wait_rt_clk(2);
    @(negedge real_time_clk_i);  // release on negedge to avoid setup violations
    arst_ni <= 1;
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Stimulus & checking
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    $display("\033[7;37m################### TEST STARTED ###################\033[0m");

    // --------------------------------------------------------------------------
    // Initialization
    // --------------------------------------------------------------------------
    arst_ni  <= 0;
    enable_i <= 0;

    wait_rt_clk(2);

    // --------------------------------------------------------------------------
    // TEST 1 – enable_o must be 0 immediately after reset
    // --------------------------------------------------------------------------
    @(negedge real_time_clk_i);
    arst_ni <= 1;

    wait_clk(2);
    if (enable_o !== 0) begin
      $display("\033[1;31m[FAIL] TEST 1: enable_o should be 0 right after reset (got %0b)\033[0m",
               enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 1: enable_o is 0 after reset\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 2 – enable_o must stay 0 while enable_i is high but delay hasn't expired
    // --------------------------------------------------------------------------
    enable_i <= 1;

    // Wait only DELAY_CYCLES-1 real-time clock cycles (counter not yet done)
    wait_rt_clk(DELAY_CYCLES - 1);
    wait_clk(2);

    if (enable_o !== 0) begin
      $display(
          "\033[1;31m[FAIL] TEST 2: enable_o should still be 0 before delay expires (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 2: enable_o stays 0 while counter is running\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 3 – enable_o must go high once the delay has expired (enable_i still high)
    // --------------------------------------------------------------------------

    // One more real-time clock cycle takes counter to DELAY_CYCLES → counter_done=1
    wait_rt_clk(2);  // +1 extra for margin (counter saturates)
    wait_clk(3);  // let clk_i domain sample counter_done

    if (enable_o !== 1) begin
      $display(
          "\033[1;31m[FAIL] TEST 3: enable_o should be 1 after delay expires with enable_i=1 (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 3: enable_o goes high after delay expires\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 4 – enable_o must go low when enable_i is deasserted
    // --------------------------------------------------------------------------
    enable_i <= 0;
    wait_clk(3);

    if (enable_o !== 0) begin
      $display(
          "\033[1;31m[FAIL] TEST 4: enable_o should be 0 when enable_i is deasserted (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 4: enable_o goes low when enable_i=0\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 5 – enable_o comes back when enable_i is reasserted (counter already done)
    // --------------------------------------------------------------------------
    enable_i <= 1;
    wait_clk(3);

    if (enable_o !== 1) begin
      $display(
          "\033[1;31m[FAIL] TEST 5: enable_o should be 1 when enable_i reasserted after delay (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 5: enable_o follows enable_i once delay has expired\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 6 – Mid-operation reset: counter and enable_o must restart from 0
    // --------------------------------------------------------------------------
    apply_reset();
    wait_clk(3);

    if (enable_o !== 0) begin
      $display(
          "\033[1;31m[FAIL] TEST 6a: enable_o should be 0 immediately after mid-op reset (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 6a: enable_o cleared by mid-operation reset\033[0m");
    end

    // After reset the counter must count again from 0.
    // Wait fewer cycles than DELAY_CYCLES – enable_o must remain 0.
    wait_rt_clk(DELAY_CYCLES - 1);
    wait_clk(2);

    if (enable_o !== 0) begin
      $display(
          "\033[1;31m[FAIL] TEST 6b: enable_o should still be 0 (counter restarted) (got %0b)\033[0m",
          enable_o);
    end else begin
      $display("\033[1;32m[PASS] TEST 6b: counter restarts from 0 after reset\033[0m");
    end

    // Now let the counter finish
    wait_rt_clk(2);
    wait_clk(3);

    if (enable_o !== 1) begin
      $display(
          "\033[1;31m[FAIL] TEST 6c: enable_o should be 1 after second delay completed (got %0b)\033[0m",
          enable_o);
    end else begin
      $display(
          "\033[1;32m[PASS] TEST 6c: enable_o goes high after delay re-expires post-reset\033[0m");
    end

    // --------------------------------------------------------------------------
    // TEST 7 – enable_o stays 0 when enable_i is low even after delay expires
    // --------------------------------------------------------------------------
    apply_reset();
    enable_i <= 0;

    // Let counter expire
    wait_rt_clk(DELAY_CYCLES + 2);
    wait_clk(3);

    if (enable_o !== 0) begin
      $display(
          "\033[1;31m[FAIL] TEST 7: enable_o should be 0 when enable_i=0 even after delay (got %0b)\033[0m",
          enable_o);
    end else begin
      $display(
          "\033[1;32m[PASS] TEST 7: enable_o stays 0 when enable_i=0 even after delay expires\033[0m");
    end

    // --------------------------------------------------------------------------
    // Wrap-up
    // --------------------------------------------------------------------------
    wait_clk(5);
    $display("\033[7;37m#################### TEST ENDED ####################\033[0m");
    $finish;
  end

endmodule
