module mem #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic [  ADDR_WIDTH-1:0] addr_i,
    input  logic                    we_i,
    input  logic [  DATA_WIDTH-1:0] wdata_i,
    input  logic [DATA_WIDTH/8-1:0] wstrb_i,
    output logic [  DATA_WIDTH-1:0] rdata_o
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------
  localparam int NUM_ROW_BYTES = DATA_WIDTH / 8;
  localparam int DEPTH = 1 << (ADDR_WIDTH - $clog2(NUM_ROW_BYTES));

  // ------------------------------------------------------------
  // Memory declaration
  // ------------------------------------------------------------
  logic [DATA_WIDTH-1:0] mem_array[DEPTH];

  // ------------------------------------------------------------
  // Write + Read logic (synchronous)
  // ------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    // Write operation
    if (we_i) begin
      for (int i = 0; i < NUM_ROW_BYTES; i++) begin
        if (wstrb_i[i]) begin
          mem_array[addr_i[ADDR_WIDTH-1:$clog2(NUM_ROW_BYTES)]][i*8+:8] <= wdata_i[i*8+:8];
        end
      end
    end
  end

  // Asynchronous read
  always_comb rdata_o = mem_array[addr_i[ADDR_WIDTH-1:$clog2(NUM_ROW_BYTES)]];

endmodule
