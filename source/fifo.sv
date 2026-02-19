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
    // Width of the data bus
    parameter int DATA_WIDTH = 8,
    // Cealing of log2(FIFO_DEPTH)
    parameter int FIFO_SIZE  = 4
    // FIFO_DEPTH = 2 ** FIFO_SIZE
    // FIFO_DEPTH is the number of entries that can be stored in the FIFO
) (
    // Asynchronous reset, active low
    input logic arst_ni,
    // Synchronous clock input
    input logic clk_i,

    // Data input bus
    input  logic [DATA_WIDTH-1:0] data_i,
    // Indicates that the data on the input bus is valid
    input  logic                  data_i_valid_i,
    // Indicates that the FIFO is ready to accept data on the input bus
    output logic                  data_i_ready_o,

    // Data output bus
    output logic [DATA_WIDTH-1:0] data_o,
    // Indicates that the data on the output bus is valid
    output logic                  data_o_valid_o,
    // Indicates that the receiver is ready to accept data on the output bus
    input  logic                  data_o_ready_i
);

// ---------------------------------------------------------------------------
//  Local parameters
// ---------------------------------------------------------------------------

localparam int FIFO_DEPTH  = 2 ** FIFO_SIZE;

// ---------------------------------------------------------------------------
//  Internal Signals
// ---------------------------------------------------------------------------

    logic [DATA_WIDTH-1:0]   mem[0:FIFO_DEPTH-1]; 
    logic [FIFO_SIZE-1:0]    wr_ptr, rd_ptr;
    logic [FIFO_SIZE:0]      count;

    logic                write_do, read_do;


// ---------------------------------------------------------------------------
//  Status Logic
// ---------------------------------------------------------------------------



    logic full, empty;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);



// ---------------------------------------------------------------------------
// Handshake-facing signals
// ---------------------------------------------------------------------------

    assign data_i_ready_o = (!full);
    
    assign data_o_valid_o = (!empty);


// ---------------------------------------------------------------------------
//  Actual transfer
// ---------------------------------------------------------------------------

    assign write_do = data_i_valid_i && data_i_ready_o;

    assign read_do =  data_o_valid_o && data_o_ready_i;


// Data output (combinational read of current head)
// For FPGA BRAM you’d usually register this; for a basic FIFO this is fine.
// assign out_data = mem[rd_ptr];



// ---------------------------------------------------------------------------
// Sequential logic
// ---------------------------------------------------------------------------
    always_ff@(posedge clk_i or negedge arst_ni) 
    begin
        if(!arst_ni) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            data_o <= '0;
         end
         else begin
             // Write operation
             if(write_do)begin
                 mem[wr_ptr] <= data_i;
                 // Advanced write pointer with wrap
                 if(wr_ptr == FIFO_DEPTH-1)begin
                     wr_ptr <= '0;
                 end
                 else begin
                     wr_ptr <= wr_ptr + 1;
                 end
             end
             // Read operation
            if(read_do) begin
                data_o <= mem[rd_ptr];
                // Advanced read pointer with wrap
                if(rd_ptr == FIFO_DEPTH-1)begin
                    rd_ptr <= '0;
                end
                else begin
                    rd_ptr <= rd_ptr + 1;
                end
            end
            // Count Update (handles simulatneous read & write)
            unique case ({write_do,read_do})
                2'b10:   count <= count + 1;  // write only
                2'b01:   count <= count - 1;  // read only
                default: count <= count;      // both or neither; so unchanged
            endcase
        end
    end


endmodule



