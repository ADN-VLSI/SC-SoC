module mem #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
) (
    input  logic                     clk_i,
    input  logic [ADDR_WIDTH-1:0]    addr_i,
    input  logic                     we_i,
    input  logic [DATA_WIDTH-1:0]    wdata_i,
    input  logic [DATA_WIDTH/8-1:0]  wstrb_i,
    output logic [DATA_WIDTH-1:0]    rdata_o
);

    // ------------------------------------------------------------
    // Local parameters
    // ------------------------------------------------------------
    localparam int DEPTH = 1 << ADDR_WIDTH;
    localparam int NUM_BYTES = DATA_WIDTH / 8;

    // ------------------------------------------------------------
    // Memory declaration
    // ------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem_array [0:DEPTH-1];

    // ------------------------------------------------------------
    // Write + Read logic (synchronous)
    // ------------------------------------------------------------
    always_ff @(posedge clk_i) begin
        // Write operation
        if (we_i) begin
            for (int i = 0; i < NUM_BYTES; i++) begin
                if (wstrb_i[i]) begin
                    mem_array[addr_i][i*8 +: 8] <= wdata_i[i*8 +: 8];
                end
            end
        end

        // Synchronous read
        rdata_o <= mem_array[addr_i];
    end

endmodule
