//////////////////////////////////////////////////////////////////////////////////////////////////////
//
//   Module      : Delay generator
//   Last Update : February 18, 2026
//
//   Description : Gates an enable until a programmable number of real-time clock cycles have
//                 elapsed. The counter runs on real_time_clk_i, while the enable handoff occurs on
//                 clk_i. Both domains share an active-low async reset. This module is useful for
//                 introducing a delay after system reset before allowing certain logic to operate.
//
//   Author      : Foez Ahmed (foez.official@gmail.com)
//
//////////////////////////////////////////////////////////////////////////////////////////////////////

module delay_gen #(
    // Number of cycles on real_time_clk_i to wait before forwarding enable_i
    parameter int DELAY_CYCLES = 10
) (
    // Active-low asynchronous reset, shared by both clock domains
    input logic arst_ni,

    // Reference clock used for the delay counter
    input logic real_time_clk_i,
    // Local clock used when releasing enable_o
    input logic clk_i,

    // Enable signal to be gated until the delay expires
    input  logic enable_i,
    // Delayed enable output, synchronized to clk_i
    output logic enable_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Signals
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Counter to track the number of real-time clock cycles elapsed
  logic [$clog2(DELAY_CYCLES)-1:0] counter;

  // Flag indicating when the counter has reached the programmed delay
  logic counter_done;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Combinational
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Counter is done when it reaches the specified number of delay cycles
  assign counter_done = (counter == DELAY_CYCLES);  // One-shot completion flag

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Sequential
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Count real-time cycles until the programmed delay expires
  always_ff @(posedge real_time_clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      counter <= 0;
    end else begin
      if (!counter_done) begin
        counter <= counter + 1;
      end
    end
  end

  // Forward the enable once the delay has completed, synchronized to clk_i
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      enable_o <= 0;
    end else begin
      if (enable_i) begin
        enable_o <= counter_done;
      end
    end
  end

endmodule
