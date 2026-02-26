module clk_div_tb;

  /////////////////////////////////////
  //           PARAMETER
  /////////////////////////////////////

  localparam realtime TP        = 10ns;
  parameter int       DIV_WIDTH = 4;

  ////////////////////////////////////
  //           Signasls
  ////////////////////////////////////

  //  active low asynchronous reset
  logic             arst_ni;

  //  input clock
  logic             clk_i;

  //  input clock divider
  logic [DIV_WIDTH-1:0] div_i;

  //  output clocks
  logic            clk_o;

  ///////////////////////////////////////////
  //         INSTANTIATIONS
  ///////////////////////////////////////////

  clk_div #(.DIV_WIDTH(4)) dut (
            .arst_ni(arst_ni),
            .clk_i(clk_i),
            .div_i(div_i),
            .clk_o(clk_o)
          );

  ///////////////////////////////////////////
  //            Clock generation
  ///////////////////////////////////////////

  always #(TP/2) clk_i <= ~clk_i;

  ///////////////////////////////////////////
  //           Test 1: Reset Behaviour
  ///////////////////////////////////////////

  task automatic apply_reset();
    arst_ni<=0;
    clk_i<=0;
    div_i<=0;
    repeat (5) @(posedge clk_i);
    arst_ni<=1;
    repeat (2) @(posedge clk_i);
  endtask

  ///////////////////////////////////////////
  //     Test 2: Async Reset Behaviour
  ///////////////////////////////////////////

  task automatic async_reset();
    arst_ni <= 0;
    #1;
    if (clk_o == 0)
      $display("Reset clears output.");
    else
      $display("Reset Failed.");
    arst_ni <= 1;
  endtask


  ///////////////////////////////////////////
  //     Test 3: Check Division
  ///////////////////////////////////////////

  task automatic check_division(input logic [DIV_WIDTH-1:0]div_val);
    time t1, t2, expected_period, measured_period;
    $display("[%0t] Attempting with div_val:%0d", $realtime, div_val);
    div_i=div_val;
    repeat(5) @(posedge clk_i);
    @(posedge clk_o);
    t1=$time;
    @(posedge clk_o);
    t2=$time;
    measured_period=t2-t1;
    expected_period= TP*div_val;
    if (measured_period==expected_period)
      $display("Division Passed, Period: %0t",measured_period);
    else
    begin
      $display("Division Failed");
      $display("Measured Period: %0t",measured_period);
      $display("Expected Period: %0t",expected_period);
    end
  endtask

  ////////////////////////////////////////////
  //      Test 4: Reset During Operation
  ///////////////////////////////////////////

  task automatic reset_during_op(input logic [DIV_WIDTH-1:0]div_val);
    div_i=div_val;
    repeat (15) @(posedge clk_i);
    arst_ni=0;
    #1;
    if(clk_o==0)
      $display (" Reset Done");
    else
      $display (" Reset Failed");
    repeat(2) @(posedge clk_i);
    arst_ni=1;
    check_division(div_val);
  endtask

  ////////////////////////////////////////////
  //             PROCEDURALS
  ///////////////////////////////////////////

  initial
  begin
    $timeformat(-9,2," ns",8);
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
    repeat(5) @(posedge clk_i);
    $display("All Divisional Sweep");
    for(int i=1;i<=15;i++)
    begin
      check_division(i);
    end
    $display("Reset During Operation");
    reset_during_op(3);
    reset_during_op(2);
    $display("Test Completed");
    $finish;
  end

  initial begin
    #100us;
    $fatal(1,"Fatal Timeout");
  end

endmodule

