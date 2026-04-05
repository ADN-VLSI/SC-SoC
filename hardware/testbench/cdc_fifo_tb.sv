module cdc_fifo_tb;

    // ---------------------------------------------------------------------------------------------
    // PARAMETERS
    // ---------------------------------------------------------------------------------------------

    parameter int DATA_WIDTH  = 8;
    parameter int FIFO_DEPTH  = 16;
    parameter int SYNC_STAGES = 2;

    // ---------------------------------------------------------------------------------------------
    // SIGNALS
    // ---------------------------------------------------------------------------------------------

    logic                        arst_ni;

    // WRITE DOMAIN
    logic                        wr_clk_i;
    logic [DATA_WIDTH-1:0]       wr_data_i;
    logic                        wr_valid_i;
    logic                        wr_ready_o;
    logic [$clog2(FIFO_DEPTH):0] wr_count_o;

    // READ DOMAIN
    logic                        rd_clk_i;
    logic                        rd_ready_i;
    logic                        rd_valid_o;
    logic [DATA_WIDTH-1:0]       rd_data_o;
    logic [$clog2(FIFO_DEPTH):0] rd_count_o;

    // ---------------------------------------------------------------------------------------------
    // DUT INSTANTIATION
    // ---------------------------------------------------------------------------------------------

    cdc_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .SYNC_STAGES(SYNC_STAGES)
    ) dut (
        .arst_ni(arst_ni),

        .wr_clk_i(wr_clk_i),
        .wr_data_i(wr_data_i),
        .wr_valid_i(wr_valid_i),
        .wr_ready_o(wr_ready_o),
        .wr_count_o(wr_count_o),

        .rd_clk_i(rd_clk_i),
        .rd_ready_i(rd_ready_i),
        .rd_valid_o(rd_valid_o),
        .rd_data_o(rd_data_o),
        .rd_count_o(rd_count_o)
    );

    // ---------------------------------------------------------------------------------------------
    // CLOCK GENERATION
    // ---------------------------------------------------------------------------------------------
    initial begin
        wr_clk_i = 0;
        forever #5 wr_clk_i = ~wr_clk_i; // 100 MHz
    end

    initial begin
        rd_clk_i = 0;
        forever #10 rd_clk_i = ~rd_clk_i; // 50 MHz
    end

    logic [DATA_WIDTH-1:0] read_data;




    task automatic reset_dut();
        begin
            arst_ni = 0;
            wr_data_i = 0;
            wr_valid_i = 0;
            rd_ready_i = 0;
            repeat (10) @(posedge wr_clk_i);
            arst_ni = 1;
        end
    endtask

    task automatic write(input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge wr_clk_i);
            wr_data_i <= data;
            wr_valid_i <= 1;
            do @(posedge wr_clk_i); while (!wr_ready_o);
            wr_valid_i <= 0;
            //@(posedge wr_clk_i);
            $display("Wrote data: %0h", data);
        end
    endtask

    task automatic read();
        begin
            @(posedge rd_clk_i);
            rd_ready_i <= 1;
            do @(posedge rd_clk_i); while (!rd_valid_o);
            rd_ready_i <= 0;
            @(posedge rd_clk_i);
            read_data = rd_data_o;
            $display("Read data: %0h", read_data);
            
        end
    endtask

    task automatic wait_sync();
        begin
            repeat (SYNC_STAGES) @(posedge wr_clk_i);
            repeat (SYNC_STAGES) @(posedge rd_clk_i);
        end
    endtask 

    task automatic wait_empty();
        begin
            do @(posedge wr_clk_i); while (wr_count_o != 0);
            do @(posedge rd_clk_i); while (rd_count_o != 0);
        end
    endtask

    task automatic wait_full();
        begin
            do @(posedge wr_clk_i); while (wr_count_o != FIFO_DEPTH);
            do @(posedge rd_clk_i); while (rd_count_o != FIFO_DEPTH);
        end
    endtask

    task automatic after_reset_check();
        begin
            if (wr_ready_o !== 1) $error("WR_READY should be 1 after reset");
            if (rd_valid_o !== 0) $error("RD_VALID should be 0 after reset");
            if (wr_count_o !== 0) $error("WR_COUNT should be 0 after reset");
            if (rd_count_o !== 0) $error("RD_COUNT should be 0 after reset");
        end
    endtask 


    // ---------------------------------------------------------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------------------------------------------------------

    initial begin
      reset_dut();
      repeat (10) @(posedge rd_clk_i);
        // Write some data into the FIFO
        write(8'hA5);
        wait_sync();
        write(8'h5A);
        wait_sync();
        write(8'hFF);
        wait_sync();
        // Read the data back
        
        read();
        wait_sync();
        read();
        wait_sync();
        read();
        wait_sync();
        read();
        wait_sync();
        read();

        repeat (10) @(posedge rd_clk_i);
        $finish;
    end

endmodule
