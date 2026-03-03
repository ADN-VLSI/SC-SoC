// Simple self-checking testbench for dual_edge_reg.
module dual_edge_reg_tb;

  localparam int WIDTH = 8;

  logic arst_ni;
  logic clk_i;
  logic en_i;

  logic [WIDTH-1:0] data_i;
  logic [WIDTH-1:0] data_o;
  logic [WIDTH-1:0] data_o_ref;

  bit mismatch;

  dual_edge_reg #(
      .WIDTH(WIDTH)
  ) u_dut (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .data_i(data_i),
      .en_i(en_i),
      .data_o(data_o)
  );

  // Reference model: captures on both edges when enabled, resets asynchronously.
  always_ff @(clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      data_o_ref <= '0;
    end else if (en_i) begin
      data_o_ref <= data_i;
    end
  end

  initial begin

    $timeformat(-9, 1, "ns", 0);
    // Waveform dump disabled by default; uncomment for debugging.
    $dumpfile("dual_edge_reg_tb.vcd");
    $dumpvars(0, dual_edge_reg_tb);

    mismatch = 0;

    #10ns;

    // Initialize signals
    arst_ni <= '0;
    clk_i   <= '0;
    data_i  <= '0;
    en_i    <= '0;

    #10ns;

    arst_ni <= '1;

    #10ns;

    fork
      forever begin
        #5ns clk_i <= ~clk_i;  // 100 MHz clock
      end
    join_none

    // Run randomized stimulus and compare DUT against the reference model.
    repeat (10000) begin
      @(clk_i);
      en_i   <= $random;
      data_i <= $random;
      if (data_o !== data_o_ref) begin
        $display("Mismatch at time %t: data_o = %h, expected = %h", $time, data_o, data_o_ref);
        mismatch = 1;
        repeat (10) @(clk_i);
        $display("\033[1;31m************** TEST FAILED **************\033[0m");
        $finish;
      end
    end

    // Finish simulation
    $display("\033[1;32m************** TEST PASSED **************\033[0m");
    $finish;
  end

endmodule
