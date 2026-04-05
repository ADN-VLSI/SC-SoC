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

    int total_pass = 0;
    int total_fail = 0;

    



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

    task automatic wait_sync_rd();
        begin
            repeat (SYNC_STAGES + 1) @(posedge rd_clk_i);
        end
    endtask 

    task automatic wait_sync_wr();
        begin
            repeat (SYNC_STAGES + 1) @(posedge wr_clk_i);
        end
    endtask

    task automatic after_reset_check();
        begin
            $display("Checking FIFO state after reset...");
            if (wr_ready_o !== 1 && rd_valid_o !== 0 && wr_count_o !== 0 && rd_count_o !== 0) $error("After reset, FIFO should be empty and ready for writes");
             else begin 
                $display("[TC0] After reset check passed");
                total_pass++;
             end
        end
    endtask 

    task automatic TC1(); // single write read test
        begin
            $display("TC1: Single write read test...");
            write(8'hA5);
            wait_sync_rd();
            read();
            wait_sync_wr();
            if (read_data !== 8'hA5) $error("TC1 Failed: Expected 0xA5, got %0h", read_data);
             else begin
                $display("[TC1] Single write read test passed");
                total_pass++;
             end
        end
    endtask 

    task automatic TC2(); // Fill FIFO with multiple writes and read them back, checking for full condition and data integrity 
        begin
            $display("TC2: Multiple write read test...");
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                write(i);
                wait_sync_rd();
            end
            if (wr_ready_o !== 0) $error("TC2 Failed: FIFO should be full and not ready for writes");
            else begin
                $display("[TC2] FIFO full condition check passed");
                total_pass++;
            end
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                read();
                wait_sync_wr();
                if (read_data !== i) $error("TC2 Failed: Expected %0h, got %0h", i, read_data);
            end
                if(rd_valid_o !== 0) $error("TC2 Failed: FIFO should be empty and not valid for reads");
                else begin 
                $display("[TC2] Multiple write read test passed");
                total_pass++;
             end
        end
    endtask 

    task automatic TC3(); // Test reset behavior during operation
        begin
            $display("TC3: Reset behavior test...");
            write(8'h55);
            wait_sync_rd();
            arst_ni = 0; // Assert reset during operation
            repeat (10) @(posedge wr_clk_i);
            arst_ni = 1; // Deassert reset
            wait_sync_rd();
            if (wr_ready_o !== 1 && rd_valid_o !== 0 && wr_count_o !== 0 && rd_count_o !== 0) $error("TC3 Failed: After reset, FIFO should be empty and ready for writes");
             else begin 
                $display("[TC3] Reset behavior test passed");
                total_pass++;
             end
        end
    endtask

    task automatic TC4();
        logic [DATA_WIDTH-1:0] expected;
        logic [DATA_WIDTH-1:0] next_wr_data;
        int                    bytes_written;
        int                    bytes_read;

    begin
        $display("TC7: Simultaneous read + write test...");

        scoreboard.delete();
        bytes_written = 0;
        bytes_read    = 0;
        next_wr_data  = 8'hA0;

        // ── Phase 1: Pre-fill 8 bytes ─────────────────────────────
        $display("      Phase 1: Pre-filling...");
        for (int i = 0; i < 8; i++) begin
            write(next_wr_data);
            scoreboard.push_back(next_wr_data);
            next_wr_data++;
            bytes_written++;
        end
        wait_sync_rd();

        // ── Phase 2: Simultaneous — write one, read one ───────────
        // For every write → immediately read one back
        // This keeps FIFO count stable
        $display("      Phase 2: Simultaneous...");
        for (int i = 0; i < 16; i++) begin
            // write new byte
            write(next_wr_data);
            scoreboard.push_back(next_wr_data);
            next_wr_data++;
            bytes_written++;
            wait_sync_rd();

            // read one byte back
            read();
            wait_sync_wr();
            expected = scoreboard.pop_front();
            if (read_data !== expected) begin
                $error("TC7 MISMATCH: got 0x%02h expected 0x%02h",
                       read_data, expected);
                total_fail++;
            end
            bytes_read++;
        end

        // ── Phase 3: Drain remaining ──────────────────────────────
        $display("      Phase 3: Draining...");
        wait_sync_rd();
        while (rd_valid_o) begin
            read();
            wait_sync_wr();
            expected = scoreboard.pop_front();
            if (read_data !== expected) begin
                $error("TC7 Drain MISMATCH: got 0x%02h expected 0x%02h",
                       read_data, expected);
                total_fail++;
            end
            bytes_read++;
        end

        // ── Checks ────────────────────────────────────────────────
        if (scoreboard.size() !== 0) begin
            $error("TC7 FAIL: %0d bytes lost", scoreboard.size());
            total_fail++;
        end

        if (rd_valid_o !== 0) begin
            $error("TC7 FAIL: FIFO not empty after drain");
            total_fail++;
        end

        $display("      bytes_written=%0d bytes_read=%0d",
                 bytes_written, bytes_read);

        if (bytes_written !== bytes_read) begin
            $error("TC7 FAIL: wrote %0d but read %0d",
                   bytes_written, bytes_read);
            total_fail++;
        end else begin
            $display("[TC7] PASS");
            total_pass++;
        end

    end
endtask







    // ---------------------------------------------------------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------------------------------------------------------

    initial begin
        reset_dut(); // TC0: Reset the DUT and check initial conditions
        after_reset_check();

      
        // Write some data into the FIFO
        TC1(); // TC1: Single write read test
        TC2(); // TC2: Multiple write read test
        TC3(); // TC3: Reset behavior test
        TC4(); // TC4: Asynchronous behavior test

        repeat (10) @(posedge rd_clk_i);
        $finish;
    end

endmodule
