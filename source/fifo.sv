// ============================================================================
// Module      : fifo
// Author      : Dhruba Jyoti Barua
// Description :
//   Parameterized synchronous Handshake FIFO implemented in SystemVerilog.
//
//   - Uses valid–ready handshake protocol
//   - Single clock domain
//   - Active-low asynchronous reset
//   - Count-based full/empty detection
//   - Supports simultaneous read and write
//
//   FIFO_DEPTH = 2 ** FIFO_SIZE
//
//   Write occurs when:
//       data_i_valid_i && data_i_ready_o
//
//   Read occurs when:
//       data_o_valid_o && data_o_ready_i
//
//   Full  condition: count == FIFO_DEPTH
//   Empty condition: count == 0
//
// ============================================================================

module fifo #(
    parameter int FIFO_SIZE         = 4,  // address width for depth = 2^FIFO_SIZE
    parameter int DATA_WIDTH        = 8,  // width of each data word
    parameter bit ALLOW_FALLTHROUGH = 0   // enable fall-through (bypass) behavior
) (
    input logic arst_ni,  // active-low asynchronous reset
    input logic clk_i,    // clock

    // Input (write) interface
    input  logic [DATA_WIDTH-1:0] data_in_i,        // input data
    input  logic                  data_in_valid_i,  // input valid
    output logic                  data_in_ready_o,  // input ready

    // Output (read) interface
    output logic [DATA_WIDTH-1:0] data_out_o,        // output data
    output logic                  data_out_valid_o,  // output valid
    input  logic                  data_out_ready_i,  // output ready

    output logic [FIFO_SIZE:0] count_o  // number of items in FIFO (binary difference)
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pointers: one extra MSB used to detect full/empty by comparing MSBs
  logic [   FIFO_SIZE:0] wr_ptr;  // write pointer (increment on writes)
  logic [   FIFO_SIZE:0] rd_ptr;  // read pointer (increment on reads)

  // Memory output from the buffer
  logic [DATA_WIDTH-1:0] mem_data_out;

  // Comparison flags used to compute full/empty conditions
  logic                  msb_eq;  // MSB of pointers equal
  logic                  nmsb_eq;  // lower bits of pointers equal
  logic                  full;  // FIFO full indicator
  logic                  empty;  // FIFO empty indicator

  // Memory control signals
  logic                  mem_we;  // memory write enable
  logic                  mem_re;  // memory read enable

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULES INSTANTIATIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] fifo_mem                                       [2**FIFO_SIZE];

  always_comb mem_data_out = fifo_mem[rd_ptr[FIFO_SIZE-1:0]];

  always_ff @(posedge clk_i) begin
    if (mem_we) begin
      fifo_mem[wr_ptr[FIFO_SIZE-1:0]] <= data_in_i;
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // COMBINATIONAL LOGICS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Pointer comparisons: MSB used to distinguish wrap-around
  always_comb msb_eq = (wr_ptr[FIFO_SIZE] == rd_ptr[FIFO_SIZE]);
  always_comb nmsb_eq = (wr_ptr[FIFO_SIZE-1:0] == rd_ptr[FIFO_SIZE-1:0]);

  // Full when MSBs equal but lower bits differ; empty when both equal
  always_comb full = msb_eq && !nmsb_eq;
  always_comb empty = msb_eq && nmsb_eq;

  // Back-pressure: if full then input ready follows output ready (to allow pop-then-push)
  always_comb data_in_ready_o = full ? data_out_ready_i : 1'b1;

  // Memory control: write when input valid & ready; read when output consumed
  always_comb mem_we = data_in_valid_i && data_in_ready_o;
  always_comb mem_re = data_out_valid_o && data_out_ready_i;

  // Element count is pointer difference (wr - rd)
  always_comb count_o = wr_ptr - rd_ptr;

  if (ALLOW_FALLTHROUGH) begin
    always_comb begin
      // Fall-through mode: when FIFO empty, output directly reflects incoming data
      data_out_o = empty ? data_in_i : mem_data_out;
      data_out_valid_o = empty ? data_in_valid_i : 1'b1;
    end
  end else begin
    always_comb begin
      // Non fall-through: output is driven from memory; valid when not empty
      data_out_o = mem_data_out;
      data_out_valid_o = !empty;
    end
  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL LOGICS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      wr_ptr <= '0;
    end else begin
      if (mem_we) wr_ptr <= wr_ptr + 1;
    end
  end

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      rd_ptr <= '0;
    end else begin
      if (mem_re) rd_ptr <= rd_ptr + 1;
    end
  end

endmodule
