// ============================================================================
// Module   : cdc_fifo_tb
// DUT      : cdc_fifo
// Author   : Adnan Sami Anirban && Shuparna Haque
//
// Test Cases:
//
// TC     Name                                     Description
// ----------------------------------------------------------------------------
// TC0    Reset and initial conditions check       Assert reset → check wr_ready_o=1,
//                                                 rd_valid_o=0, wr_count_o=0, rd_count_o=0
//
// TC1    Single write read test                   Write 0xA5 → wait_sync_rd → read
//                                                 → check read_data=0xA5
//
// TC2    Fill FIFO full and drain test            Write FIFO_DEPTH bytes → check
//                                                 wr_ready_o=0 (full) → read all
//                                                 → check rd_valid_o=0 and data integrity
//
// TC3    Reset during operation test              Write 0x55 → assert reset mid-operation
//                                                 → deassert → check FIFO clean state
//
// TC4    Simultaneous write and read test         Pre-fill 8 bytes → write one read one
//                                                 for 16 cycles → drain → check scoreboard
//
// TC5    Read faster than write test              Speed up rd_clk → write 8 bytes
//                                                 → read continuously → check data integrity
//                                                 and rd_valid_o=0 after empty
//
// TC6    Pointer wraparound test                  Fill FIFO → drain half → write more
//                                                 to force pointer wraparound → drain all
//                                                 → check data integrity
//
// TC7    Count check test                         Write 4 → check wr_count_o=rd_count_o=4
//                                                 → read 1 → check counts=3
//                                                 → drain → check counts=0
// ============================================================================

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
    logic [DATA_WIDTH-1:0] scoreboard [$];




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
            //$display("Wrote data: %0h", data);
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
            //$display("Read data: %0h", read_data);
            
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

    task automatic after_reset_check(input string test_name = "TC0");
        begin
            //$display("Checking FIFO state after reset...");
            if (wr_ready_o !== 1 && rd_valid_o !== 0 && wr_count_o !== 0 && rd_count_o !== 0) begin 
                $error("[%s] \033[31m[FAILED]\033[0m:: After reset, FIFO should be empty and ready for writes", test_name);
                total_fail++;
             end
             else begin 
                $display("[%s] \033[32m[PASSED]\033[0m: Check after reset", test_name);
                total_pass++;
             end
        end
    endtask 

    task automatic TC1(); // single write read test
        begin
            write(8'hA5);
            wait_sync_rd();
            read();
            wait_sync_wr();
            if (read_data !== 8'hA5) begin 
                $error("[TC1] \033[31m[FAILED]\033[0m:: Expected 0xA5, got %0h", read_data);
                total_fail++;
            end
            else begin
                $display("[TC1] \033[32m[PASSED]\033[0m:Single write read test");
                total_pass++;
             end
        end
    endtask 

    task automatic TC2(); // Fill FIFO with multiple writes and read them back, checking for full condition and data integrity 
        begin
            //$display("TC2: Multiple write read test...");
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                write(i);
            end
            wait_sync_rd();
            if (wr_ready_o !== 0) begin 
                $error("[TC2] \033[31m[FAILED]\033[0m:: FIFO should be full and not ready for writes");
                total_fail++;
            end
            else begin
                $display("[TC2] \033[32m[PASSED]\033[0m: FIFO full condition check");
                total_pass++;
            end
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                read();
                wait_sync_wr();
                if (read_data !== i) begin 
                    $error("[TC2] \033[31m[FAILED]\033[0m:: Expected %0h, got %0h", i, read_data);
                    total_fail++;
                end
            end
            if(rd_valid_o !== 0) begin
                $error("[TC2] \033[31m[\033[31m[FAILED]\033[0m:]\033[0m: FIFO should be empty and not valid for reads");
                total_fail++;
            end
            else begin 
                $display("[TC2] \033[32m[PASSED]\033[0m: Multiple write read test");
                total_pass++;
            end
        end
    endtask 

    task automatic TC3(); // Test reset behavior during operation
        begin
            write(8'h55);
            wait_sync_rd();
            arst_ni = 0; // Assert reset during operation
            repeat (10) @(posedge wr_clk_i);
            arst_ni = 1; // Deassert reset
            after_reset_check("TC3");
        end
    endtask

    task automatic TC4();
        logic [DATA_WIDTH-1:0] expected;
        logic [DATA_WIDTH-1:0] next_wr_data;
        int                    bytes_written;
        int                    bytes_read;

        begin
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
                    $error("[TC4] \033[31m[FAILED]\033[0m:: MISMATCH- got 0x%02h expected 0x%02h",
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
                    $error("[TC4] \033[31m[FAILED]\033[0m:: Drain MISMATCH- got 0x%02h expected 0x%02h",
                        read_data, expected);
                    total_fail++;
                end
                bytes_read++;
            end

            // ── Checks ────────────────────────────────────────────────
            if (scoreboard.size() !== 0) begin
                $error("[TC4] \033[31m[FAILED]\033[0m:: %0d bytes lost", scoreboard.size());
                total_fail++;
            end

            if (rd_valid_o !== 0) begin
                $error("[TC4] \033[31m[FAILED]\033[0m:: FIFO not empty after drain");
                total_fail++;
            end

            $display("      bytes_written=%0d bytes_read=%0d",
                    bytes_written, bytes_read);

            if (bytes_written !== bytes_read) begin
                $error("[TC4] \033[31m[FAILED]\033[0m:: wrote %0d but read %0d",
                    bytes_written, bytes_read);
                total_fail++;
            end else begin
                $display("[TC4] \033[32m[\033[32m[PASSED]\033[0m]\033[0m: Simultaneous write/read test");
                total_pass++;
            end

        end
    endtask

    task automatic TC5(); // Read faster than write
        logic [DATA_WIDTH-1:0] expected;
        begin
            // Temporarily speed up read clock (toggle every 2ns = 250 MHz)
            fork
                forever #2 rd_clk_i = ~rd_clk_i;
            join_none

            // Write a few values slowly
            for (int i = 0; i < 8; i++) begin
                write(i);
            end
            wait_sync_rd();

            // Try to read continuously
            for (int i = 0; i < 8; i++) begin
                read();
                expected = i;
                if (read_data !== expected) begin
                    $error("[TC5] \033[31m[FAILED]\033[0m: Expected %0h, got %0h", expected, read_data);
                    total_fail++;
                end
            end

            // After draining, rd_valid_o should go low
            if (rd_valid_o !== 0) begin
                $error("[TC5] \033[31m[FAILED]\033[0m: rd_valid_o should be 0 after empty");
                total_fail++;
            end else begin
                $display("[TC5] \033[32m[PASSED]\033[0m: Read faster than write handled correctly");
                total_pass++;
            end
        end
    endtask

    task automatic TC6(); // Pointer wraparound test
        logic [DATA_WIDTH-1:0] expected;
        begin
            //$display("[TC6]: Pointer wraparound test...");

            // Fill FIFO completely
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                write(i);
            end
            wait_sync_rd();

            // Drain half
            for (int i = 0; i < FIFO_DEPTH/2; i++) begin
                read();
                if (read_data !== i) begin
                    $error("[TC6] \033[31m[FAILED]\033[0m: Expected %0h, got %0h", i, read_data);
                    total_fail++;
                end
            end

            // Write more data to force pointer wraparound
            for (int i = FIFO_DEPTH; i < FIFO_DEPTH + FIFO_DEPTH/2; i++) begin
                write(i);
            end
            wait_sync_rd();

            // Drain remaining
            for (int i = FIFO_DEPTH/2; i < FIFO_DEPTH + FIFO_DEPTH/2; i++) begin
                read();
                if (read_data !== i) begin
                    $error("[TC6] \033[31m[FAILED]\033[0m: Expected %0h, got %0h", i, read_data);
                    total_fail++;
                end
            end

            if (rd_valid_o !== 0) begin
                $error("[TC6] \033[31m[FAILED]\033[0m: FIFO should be empty after wraparound drain");
                total_fail++;
            end else begin
                $display("[TC6] \033[32m[PASSED]\033[0m: Pointer wraparound test passed");
                total_pass++;
            end
        end
    endtask

    task automatic TC7();
        begin

            // ── Step 1: check count at reset ──────────────────────────
            reset_dut();
            if (wr_count_o !== 0 || rd_count_o !== 0) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: counts should be 0 at start, wr=%0d rd=%0d",
                    wr_count_o, rd_count_o);
                total_fail++;
            end

            // ── Step 2: write 4 bytes ─────────────────────────────────
            write(8'h01);
            write(8'h02);
            write(8'h03);
            write(8'h04);
            wait_sync_rd();
            //wait_sync_wr();

            if (wr_count_o !== 4) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: wr_count_o expected 4 got %0d", wr_count_o);
                total_fail++;
            end
            if (rd_count_o !== 4) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: rd_count_o expected 4 got %0d", rd_count_o);
                total_fail++;
            end

            // ── Step 3: read 1 byte — count should drop to 3 ─────────
            read();
            wait_sync_wr();

            if (wr_count_o !== 3) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: wr_count_o expected 3 got %0d", wr_count_o);
                total_fail++;
            end
            if (rd_count_o !== 3) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: rd_count_o expected 3 got %0d", rd_count_o);
                total_fail++;
            end

            // ── Step 4: drain remaining 3 bytes ───────────────────────
            read();
            read();
            read();
            wait_sync_wr();

            if (wr_count_o !== 0) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: wr_count_o expected 0 got %0d", wr_count_o);
                total_fail++;
            end else if (rd_count_o !== 0) begin
                $error("[TC7] \033[31m[FAILED]\033[0m:: rd_count_o expected 0 got %0d", rd_count_o);
                total_fail++;
            end else begin
                $display("[TC7] \033[32m[PASSED]\033[0m: Count check test");
                total_pass++;
            end

        end
    endtask
    // ---------------------------------------------------------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------------------------------------------------------

    initial begin
        $display("---------------------TEST START-----------------------------");
        $display("Testing CDC FIFO with DATA_WIDTH=%0d, FIFO_DEPTH=%0d, SYNC_STAGES=%0d",
            DATA_WIDTH, FIFO_DEPTH, SYNC_STAGES);
        $display("-------------------------------------------------------------");
        $display("\033[1;35m[TC0]: Reset and initial conditions check...\033[0m");
        reset_dut(); // TC0: Reset the DUT and check initial conditions
        after_reset_check();

      
        // Write some data into the FIFO
        $display("\033[1;35m[TC1]: Single write read test...\033[0m");
        TC1(); 
        $display("\033[1;35m[TC2]: Multiple write until FIFO is full and read test...\033[0m");
        TC2();
        $display("\033[1;35m[TC3]: Reset behavior during operation test...\033[0m");
        TC3();
        $display("\033[1;35m[TC4]: Simultaneous write and read test...\033[0m");
        TC4();
        $display("\033[1;35m[TC5]: Read faster than write test...\033[0m");
        TC5();
        $display("\033[1;35m[TC6]: Pointer wraparound test...\033[0m");
        TC6();
        $display("\033[1;35m[TC7]: Count check test...\033[0m");
        TC7();

        repeat (10) @(posedge rd_clk_i);
        $display("---------------------TEST SUMMARY-----------------------------");
        $display("TEST COMPLETE");
        $display("\033[32m[%0d PASSED]\033[0m, \033[31m[%0d FAILED]\033[0m:", total_pass, total_fail);
        $display("-------------------------------------------------------------");
        if(total_fail == 0) begin
            $display("ALL TESTS \033[32m[PASSED]\033[0m!");
        end else begin
            $display("SOME TESTS \033[31m[FAILED]\033[0m:!");
        end
        $finish;
    end

endmodule
