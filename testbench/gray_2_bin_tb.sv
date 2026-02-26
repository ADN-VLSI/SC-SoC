module gray_2_bin_tb;
    
    // Author's Name: Adnan Sami Anirban (adnananirban259@gmail.com)

    // ---------------------------------------------------------
    // 1. PARAMETERS & SIGNALS
    // ---------------------------------------------------------
    parameter int WIDTH = 8;

    logic [WIDTH-1:0] gray_i;
    logic [WIDTH-1:0] bin_o;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // Enable / Disable error injection
    bit ENABLE_ERROR_INJECTION = 0;

    // ---------------------------------------------------------
    // 2. DUT INSTANTIATION
    // ---------------------------------------------------------
    gray_2_bin #(
        .WIDTH(WIDTH)
    ) dut_inst (
        .gray_i(gray_i),
        .bin_o(bin_o)
    );

    // ---------------------------------------------------------
    // 3. SCOREBOARD TASK
    // ---------------------------------------------------------
    task check_result(
        input logic [WIDTH-1:0] g_stimulus,
        input logic [WIDTH-1:0] b_actual
    );
        logic [WIDTH-1:0] b_expected;

        // Reference Model (Golden Model)
        b_expected[WIDTH-1] = g_stimulus[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) begin
            b_expected[i] = b_expected[i+1] ^ g_stimulus[i];
        end

        // Compare
        if (b_actual === b_expected) begin
            pass_count++;
        end
        else begin
            $display("[TIME:%0t] FAIL | Gray:%b | Exp:%b | Got:%b",
                     $time, g_stimulus, b_expected, b_actual);
            fail_count++;
        end
    endtask

    // ---------------------------------------------------------
    // 4. TEST CASES
    // ---------------------------------------------------------

    // ---------------- Test 1 ----------------
    task test_min_boundary();
        $display("\n--- Running Test Case 1: test_min_boundary (All Zeros) ---");
        for (int i = 0; i < 10; i++) begin
            gray_i = {WIDTH{1'b0}};
            #10;
            check_result(gray_i, bin_o);
            test_count++;
        end
    endtask

    // ---------------- Test 2 ----------------
    task test_max_boundary();
        $display("\n--- Running Test Case 2: test_max_boundary (All Ones) ---");
        for (int i = 0; i < 10; i++) begin
            gray_i = {WIDTH{1'b1}};
            #10;
            check_result(gray_i, bin_o);
            test_count++;
        end
    endtask

    // ---------------- Test 3 ----------------
    task test_check_board();
        $display("\n--- Running Test Case 3: test_check_board (Pattern 1010...) ---");
        for (int i = 0; i < 10; i++) begin
            gray_i = {(WIDTH/2){2'b10}};
            #10;
            check_result(gray_i, bin_o);
            test_count++;
        end
    endtask

    // ---------------- Test 4 ----------------
    task test_random_sequence();
        $display("\n--- Running Test Case 4: test_random_sequence (Random Patterns) ---");
        for (int i = 0; i < 970; i++) begin
            gray_i = $urandom_range(0, (1<<WIDTH)-1);
            #10;

            // Inject error intentionally for testing scoreboard
            if (ENABLE_ERROR_INJECTION && (i == 50 || i == 100)) begin
                $display("\n[SYSTEM] >>> INTENTIONAL ERROR INJECTED <<<");
                check_result(gray_i, bin_o ^ 1'b1); // Flip LSB
            end
            else begin
                check_result(gray_i, bin_o);
            end

            test_count++;
        end
    endtask

    // ---------------------------------------------------------
    // 5. SUMMARY REPORT
    // ---------------------------------------------------------
    task print_summary();
        $display("\n=================================================");
        $display("             VERIFICATION SUMMARY");
        $display("=================================================");
        $display("Total Tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);

        if (fail_count == 0)
            $display("FINAL RESULT: PASSED");
        else
            $display("FINAL RESULT: FAILED");

        $display("=================================================\n");
    endtask

    // ---------------------------------------------------------
    // 6. MAIN TEST SEQUENCE
    // ---------------------------------------------------------
    initial begin
        $display("Starting Gray-to-Binary Verification | WIDTH=%0d", WIDTH);

        test_min_boundary();
        test_max_boundary();
        test_check_board();
        test_random_sequence();

        print_summary();

        $finish;
    end

endmodule
