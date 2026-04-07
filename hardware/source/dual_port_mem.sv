/////////////////////////////////////////////////////////////////////////////////////////
// Module        : Dual Port Memory (dual_port_mem)
// Update at     : 19 Feb,2026
// Description   : A simple byte-addressable memory module with parameterizable address
//                 and data widths.
// Author        : Md Samir Hasan
//
////////////////////////////////////////////////////////////////////////////////////////

module dual_port_mem #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
) (
    input  logic                         clk_i,
    input  logic [  ADDR_WIDTH-1:0]      waddr_i,
    input  logic                         we_i,
    input  logic [DATA_WIDTH/8-1:0][7:0] wdata_i,
    input  logic [DATA_WIDTH/8-1:0]      wstrb_i,
    input  logic [  ADDR_WIDTH-1:0]      raddr_i,
    output logic [DATA_WIDTH/8-1:0][7:0] rdata_o
);

  // ------------------------------------------------------------
  // Local parameters
  // ------------------------------------------------------------

  // Number of bytes in each memory row
  localparam int NUM_ROW_BYTES = DATA_WIDTH / 8;

  // Number of bits for byte addressing
  localparam int BYTE_ADDR_WIDTH = $clog2(NUM_ROW_BYTES);

  // Total depth of the memory (number of rows)
  localparam int DEPTH = 1 << (ADDR_WIDTH - BYTE_ADDR_WIDTH);

  // ------------------------------------------------------------
  // Memory declaration
  // ------------------------------------------------------------
  logic [DATA_WIDTH/8-1:0][7:0] mem_array[DEPTH];

  // ------------------------------------------------------------
  // Write + Read logic (synchronous)
  // ------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    // Write operation
    if (we_i) begin
      foreach (wstrb_i[i]) begin
        if (wstrb_i[i]) begin
          mem_array[waddr_i[ADDR_WIDTH-1:BYTE_ADDR_WIDTH]][i] <= wdata_i[i];
        end
      end
    end
  end

  // Asynchronous read
  assign rdata_o = mem_array[raddr_i[ADDR_WIDTH-1:BYTE_ADDR_WIDTH]];

endmodule