module clk_div_tb;

  /////////////////////////////////////
  //           PARAMETER
  /////////////////////////////////////

  localparam realtime TP = 10ns;  // 100 MHz
  parameter int DIV_WIDTH = 4;

  ////////////////////////////////////
  //           Signasls
  ////////////////////////////////////

  //  active low asynchronous reset
  logic                 arst_ni;

  //  input clock
  logic                 clk_i;

  //  input clock divider
  logic [DIV_WIDTH-1:0] div_i;

  //  output clocks
  logic                 clk_o;

  ////////////////////////////////////
  //           Variables
  ////////////////////////////////////

  int                   test_passed;
  int                   test_failed;

  bit                   mota_clk_p;
  bit                   mota_clk_n;

  ///////////////////////////////////////////
  //         INSTANTIATIONS
  ///////////////////////////////////////////

  clk_div #(
      .DIV_WIDTH(DIV_WIDTH)
  ) dut (
      .arst_ni(arst_ni),
      .clk_i  (clk_i),
      .div_i  (div_i),
      .clk_o  (clk_o)
  );

  ///////////////////////////////////////////
  //            Clock generation
  ///////////////////////////////////////////

  always #(TP / 2) clk_i <= ~clk_i;

  ///////////////////////////////////////////
  //           Test 1: Reset Behaviour
  ///////////////////////////////////////////

  task automatic apply_reset();
    arst_ni <= '0;
    clk_i   <= '0;
    div_i   <= '0;
    repeat (5) @(posedge clk_i);
    arst_ni <= '1;
    repeat (2) @(posedge clk_i);
  endtask

  ///////////////////////////////////////////
  //     Test 2: Async Reset Behaviour
  ///////////////////////////////////////////

  task automatic async_reset();
    arst_ni <= '0;
    #1;
    if (clk_o == 0) $display("Reset clears output.");
    else $display("Reset Failed.");
    arst_ni <= '1;
  endtask

  task automatic check_division(input logic [DIV_WIDTH-1:0] div_val);

    realtime measured_timeperiod;
    real x;

    div_i <= (div_val == 0) ? 1 : div_val;

    // let divider settle
    repeat (2) @(posedge clk_o);

    // Measure the time between 100 output clock edges to get an average period
    measured_timeperiod = $realtime;
    repeat (3) @(posedge clk_o);
    measured_timeperiod = $realtime - measured_timeperiod;
    measured_timeperiod = measured_timeperiod / 3;

    x = (10ns * div_i) / measured_timeperiod;

    if (x > 0.98 && x < 1.02) begin
      $display("Division Passed for div_val=%0d, Measured Period: %0t\n [%0t]", div_val,
               measured_timeperiod, $realtime);
    end else begin
      $display("Division Failed for div_val=%0d [%0t]", div_val, $realtime);
      $display("Measured Period: %0t, Expected Period: %0t\n", measured_timeperiod, 10ns * div_i);
    end

  endtask
  ////////////////////////////////////////////
  //      Test 4: Reset During Operation
  ///////////////////////////////////////////

  task automatic reset_during_op(input logic [DIV_WIDTH-1:0] div_val);
    div_i <= div_val;
    repeat (15) @(posedge clk_i);
    arst_ni <= '0;
    #1;
    if (clk_o == 0) $display(" Reset Done");
    else $display(" Reset Failed");
    repeat (2) @(posedge clk_i);
    arst_ni <= '1;
    check_division(div_val);
  endtask

  ////////////////////////////////////////////
  //             PROCEDURALS
  ///////////////////////////////////////////

  initial begin
    $timeformat(-9, 2, "ns", 8);
    $dumpfile("clk_div_tb.vcd");
    $dumpvars(0, clk_div_tb);
    apply_reset();
    $display("Minimum Division");
    check_division(1);
    $display("Maximum Division");
    check_division(15);
    $display("Zero Division");
    check_division(0);
    async_reset();
    repeat (5) @(posedge clk_i);
    $display("All Divisional Sweep");
    for (int i = 1; i <= 15; i++) begin
      check_division(i);
    end
    $display("Reset During Operation");
    reset_during_op(3);
    reset_during_op(2);
    $display("Test Completed");
    if (test_failed == 0) begin
      $display("\033[1;32mAll tests passed!\033[0m");
    end else begin
      $display("\033[1;31m%d tests failed.\033[0m", test_failed);
    end
    $finish;
  end

endmodule

