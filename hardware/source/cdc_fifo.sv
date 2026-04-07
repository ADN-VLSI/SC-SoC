module cdc_fifo #(
    parameter int DATA_WIDTH  = 8,
    parameter int FIFO_DEPTH  = 16,
    parameter int SYNC_STAGES = 2
)(
    input  logic                        arst_ni,

    // WRITE DOMAIN
    input  logic                        wr_clk_i,
    input  logic [DATA_WIDTH-1:0]       wr_data_i,
    input  logic                        wr_valid_i,
    output logic                        wr_ready_o,
    output logic [$clog2(FIFO_DEPTH):0] wr_count_o,

    // READ DOMAIN
    input  logic                        rd_clk_i,
    input  logic                        rd_ready_i,
    output logic                        rd_valid_o,
    output logic [DATA_WIDTH-1:0]       rd_data_o,
    output logic [$clog2(FIFO_DEPTH):0] rd_count_o
);

    // ---------------------------------------------------------------------------------------------
    // PARAMETERS
    // ---------------------------------------------------------------------------------------------

    localparam int ADDR_WIDTH  = $clog2(FIFO_DEPTH);
    localparam int COUNT_WIDTH = ADDR_WIDTH + 1;

    // ---------------------------------------------------------------------------------------------
    // ASSERTIONS
    // ---------------------------------------------------------------------------------------------

    initial begin
        assert ((FIFO_DEPTH & (FIFO_DEPTH - 1)) == 0)
            else $fatal(1, "cdc_fifo: FIFO_DEPTH must be power of 2");
        assert (FIFO_DEPTH >= 4)
            else $fatal(1, "cdc_fifo: FIFO_DEPTH must be >= 4");
        assert (SYNC_STAGES >= 2)
            else $fatal(1, "cdc_fifo: SYNC_STAGES must be >= 2");
        assert (DATA_WIDTH >= 1)
            else $fatal(1, "cdc_fifo: DATA_WIDTH must be >= 1");
    end

    // ---------------------------------------------------------------------------------------------
    // MEMORY
    // ---------------------------------------------------------------------------------------------

    logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH];

    // ---------------------------------------------------------------------------------------------
    // POINTERS
    // ---------------------------------------------------------------------------------------------

    logic [COUNT_WIDTH-1:0] wr_ptr_bin,  wr_ptr_gray;
    logic [COUNT_WIDTH-1:0] rd_ptr_bin,  rd_ptr_gray;

    logic [COUNT_WIDTH-1:0] wr_ptr_bin_next,  wr_ptr_gray_next;
    logic [COUNT_WIDTH-1:0] rd_ptr_bin_next,  rd_ptr_gray_next;

    logic                   wr_handshake;
    logic                   rd_handshake;

    // ---------------------------------------------------------------------------------------------
    // SYNC POINTERS
    // ---------------------------------------------------------------------------------------------

    logic [COUNT_WIDTH-1:0] wr_ptr_gray_sync [SYNC_STAGES];
    logic [COUNT_WIDTH-1:0] rd_ptr_gray_sync [SYNC_STAGES];

    logic [COUNT_WIDTH-1:0] sync_wr_ptr_gray;
    logic [COUNT_WIDTH-1:0] sync_rd_ptr_gray;

    // ---------------------------------------------------------------------------------------------
    // FUNCTIONS
    // ---------------------------------------------------------------------------------------------

    function automatic logic [COUNT_WIDTH-1:0] bin2gray(input logic [COUNT_WIDTH-1:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    function automatic logic [COUNT_WIDTH-1:0] gray2bin(input logic [COUNT_WIDTH-1:0] gray);
        logic [COUNT_WIDTH-1:0] bin;
        bin[COUNT_WIDTH-1] = gray[COUNT_WIDTH-1];
        for (int i = COUNT_WIDTH-2; i >= 0; i--)
            bin[i] = bin[i+1] ^ gray[i];
        return bin;
    endfunction

    // ---------------------------------------------------------------------------------------------
    // WRITE POINTER LOGIC
    // ---------------------------------------------------------------------------------------------

    assign wr_handshake     = wr_valid_i & wr_ready_o;
    assign wr_ptr_bin_next  = wr_ptr_bin + (wr_handshake ? 1 : 0);
    assign wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);

    always_ff @(posedge wr_clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // ---------------------------------------------------------------------------------------------
    // READ POINTER LOGIC
    // ---------------------------------------------------------------------------------------------

    assign rd_handshake     = rd_valid_o & rd_ready_i;
    assign rd_ptr_bin_next  = rd_ptr_bin + (rd_handshake ? 1 : 0);
    assign rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

    always_ff @(posedge rd_clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // ---------------------------------------------------------------------------------------------
    // SYNCHRONIZERS
    // ---------------------------------------------------------------------------------------------

    // WR -> RD
    always_ff @(posedge rd_clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            for (int i = 0; i < SYNC_STAGES; i++)
                wr_ptr_gray_sync[i] <= '0;
        end else begin
            wr_ptr_gray_sync[0] <= wr_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++)
                wr_ptr_gray_sync[i] <= wr_ptr_gray_sync[i-1];
        end
    end

    assign sync_wr_ptr_gray = wr_ptr_gray_sync[SYNC_STAGES-1];

    // RD -> WR
    always_ff @(posedge wr_clk_i or negedge arst_ni) begin
        if (!arst_ni) begin
            for (int i = 0; i < SYNC_STAGES; i++)
                rd_ptr_gray_sync[i] <= '0;
        end else begin
            rd_ptr_gray_sync[0] <= rd_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++)
                rd_ptr_gray_sync[i] <= rd_ptr_gray_sync[i-1];
        end
    end

    assign sync_rd_ptr_gray = rd_ptr_gray_sync[SYNC_STAGES-1];

    // ---------------------------------------------------------------------------------------------
    // FULL / EMPTY (GRAY SAFE)
    // ---------------------------------------------------------------------------------------------

    wire fifo_full;
    assign fifo_full =
        (wr_ptr_gray == {
            ~sync_rd_ptr_gray[COUNT_WIDTH-1:COUNT_WIDTH-2],
             sync_rd_ptr_gray[COUNT_WIDTH-3:0]
        });

    assign wr_ready_o = ~fifo_full;

    wire fifo_empty;
    assign fifo_empty = (rd_ptr_gray == sync_wr_ptr_gray);

    assign rd_valid_o = ~fifo_empty;

    // ---------------------------------------------------------------------------------------------
    // MEMORY WRITE
    // ---------------------------------------------------------------------------------------------

    always_ff @(posedge wr_clk_i) begin
        if (wr_handshake)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data_i;
    end

    // ---------------------------------------------------------------------------------------------
    // MEMORY READ — sequential, registered output
    // ---------------------------------------------------------------------------------------------

    always_ff @(posedge rd_clk_i or negedge arst_ni) begin
        if (!arst_ni)
            rd_data_o <= '0;
        else if (rd_handshake)
            rd_data_o <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];  // capture current entry on handshake
    end

    // ---------------------------------------------------------------------------------------------
    // COUNT (APPROXIMATE)
    // ---------------------------------------------------------------------------------------------

    wire [COUNT_WIDTH-1:0] sync_wr_ptr_bin = gray2bin(sync_wr_ptr_gray);
    wire [COUNT_WIDTH-1:0] sync_rd_ptr_bin = gray2bin(sync_rd_ptr_gray);

    assign wr_count_o = wr_ptr_bin  - sync_rd_ptr_bin;
    assign rd_count_o = sync_wr_ptr_bin - rd_ptr_bin;

endmodule