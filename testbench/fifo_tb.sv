// ==================================================================================================
// Module      : fifo_tb
// Author      : Md. Samir Hasan (shamirhasan2.0@gmail.com)
// Date        : 03-03-2026
// Description : Parameterized synchronous FIFO with valid-ready handshaking 
//               implemented in a SystemVerilog testbench.
// ==================================================================================================

//`timescale 1ns/1ps

module fifo_tb;

    // -----------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------
    parameter  int DATA_WIDTH  = 8;
    parameter  int FIFO_SIZE   = 4;
    localparam int FIFO_DEPTH  = 2**FIFO_SIZE;

    // -----------------------------------------------------------------------
    // Signals
    // -----------------------------------------------------------------------
    logic                  clk;
    logic                  arst_ni;
    logic [DATA_WIDTH-1:0] data_i;
    logic                  data_i_valid_i;
    logic                  data_i_ready_o;
    logic [DATA_WIDTH-1:0] data_o;
    logic                  data_o_valid_o;
    logic                  data_o_ready_i;

    // Capture variable (never drive data_o directly — multi-driver error)
    logic [DATA_WIDTH-1:0] read_val;

    // -----------------------------------------------------------------------
    // Pass / Fail counters
    // -----------------------------------------------------------------------
    int tests_passed;
    int tests_failed;

    // -----------------------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------------------
    initial clk = 0;
    always  #5  clk = ~clk;

    // -----------------------------------------------------------------------
    // DUT instantiation
    // -----------------------------------------------------------------------
    fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_SIZE  (FIFO_SIZE)
    ) dut (
        .clk_i          (clk),
        .arst_ni        (arst_ni),
        .data_i         (data_i),
        .data_i_valid_i (data_i_valid_i),
        .data_i_ready_o (data_i_ready_o),
        .data_o         (data_o),
        .data_o_valid_o (data_o_valid_o),
        .data_o_ready_i (data_o_ready_i)
    );

    // -----------------------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("fifo_waves.vcd");
        $dumpvars(0, fifo_tb);
    end

    // -----------------------------------------------------------------------
    // PUSH task
    // -----------------------------------------------------------------------
    task automatic push(input [DATA_WIDTH-1:0] val);
        data_i         <= val;
        data_i_valid_i <= 1;
        @(posedge clk);
        while (!data_i_ready_o) @(posedge clk);
        data_i_valid_i <= 0;
        data_i         <= 0;
    endtask

    // -----------------------------------------------------------------------
    // POP task
    // -----------------------------------------------------------------------
    task automatic pop(output [DATA_WIDTH-1:0] val);
        data_o_ready_i <= 1;
        @(posedge clk);
        while (!data_o_valid_o) @(posedge clk);
        #1;
        val            =  data_o;
        data_o_ready_i <= 0;
    endtask

    // -----------------------------------------------------------------------
    // Check task
    // -----------------------------------------------------------------------
    task automatic check(input string test_name, input logic condition);
        if (condition) begin
            $display("    [PASS] %s", test_name);
            tests_passed++;
        end else begin
            $display("    [FAIL] %s  (got: 8'h%0h)", test_name, read_val);
            tests_failed++;
        end
    endtask

    // -----------------------------------------------------------------------
    // Summary task
    // -----------------------------------------------------------------------
    task automatic print_summary();
        int total;
        total = tests_passed + tests_failed;
        $display("============================================");
        $display("             TEST SUMMARY                   ");
        $display("============================================");
        $display("  Total  : %0d", total);
        $display("  Passed : %0d", tests_passed);
        $display("  Failed : %0d", tests_failed);
        $display("============================================");
        if (tests_failed == 0)
            $display("  Result : *** ALL TESTS PASSED ***");
        else
            $display("  Result : *** %0d TEST(S) FAILED ***", tests_failed);
        $display("============================================");
    endtask

    // -----------------------------------------------------------------------
    // Main test sequence
    // -----------------------------------------------------------------------
    initial begin

        // Initialise counters
        tests_passed   = 0;
        tests_failed   = 0;

        // Initialise driven signals
        arst_ni        <= 0;
        data_i         <= 0;
        data_i_valid_i <= 0;
        data_o_ready_i <= 0;

        // Reset — hold 2 cycles then release
        repeat(2) @(posedge clk);
        arst_ni <= 1;
        repeat(2) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 1: Single Write and Read
        // ------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("Test 1: Single Write and Read");
        push(8'hA1);
        $display("  Wrote   : 8'hA1");
        pop(read_val);
        $display("  Got     : 8'h%0h  (expected A1)", read_val);
        check("T1 Single Write/Read (A1)", read_val === 8'hA1);

        // ------------------------------------------------------------------
        // Test 2: Multiple Write then Read — FIFO order check
        // ------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("Test 2: Multiple Write and Read");
        begin : t2
            logic [DATA_WIDTH-1:0] exp0, exp1, exp2;
            exp0 = 8'hB1; exp1 = 8'hB2; exp2 = 8'hB3;

            push(8'hB1); push(8'hB2); push(8'hB3);

            pop(read_val);
            $display("  Got: 8'h%0h  (expected B1)", read_val);
            check("T2 FIFO order entry [1]", read_val === exp0);

            pop(read_val);
            $display("  Got: 8'h%0h  (expected B2)", read_val);
            check("T2 FIFO order entry [2]", read_val === exp1);

            pop(read_val);
            $display("  Got: 8'h%0h  (expected B3)", read_val);
            check("T2 FIFO order entry [3]", read_val === exp2);
        end

        // ------------------------------------------------------------------
        // Test 3: Full and Empty flag checks
        // ------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("Test 3: FIFO Full/Empty Flags (depth=%0d)", FIFO_DEPTH);

        for (int i = 0; i < FIFO_DEPTH; i++) push(i[DATA_WIDTH-1:0]);
        #1;
        $display("  data_i_ready_o = %b  (expect 0 = FULL)", data_i_ready_o);
        check("T3 FIFO Full: ready de-asserts", data_i_ready_o === 1'b0);

        for (int i = 0; i < FIFO_DEPTH; i++) begin
            pop(read_val);
            check($sformatf("T3 Full-drain integrity [%0d]", i),
                  read_val === i[DATA_WIDTH-1:0]);
        end
        #1;
        $display("  data_o_valid_o = %b  (expect 0 = EMPTY)", data_o_valid_o);
        check("T3 FIFO Empty: valid de-asserts", data_o_valid_o === 1'b0);

        // ------------------------------------------------------------------
        // Test 4: Simultaneous Read and Write
        // ------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("Test 4: Simultaneous Read and Write");
        push(8'hCC);
        fork
            push(8'hDD);
            pop(read_val);
        join
        $display("  Simul-Read got : 8'h%0h  (expected CC)", read_val);
        check("T4 Simul R/W: first pop = CC", read_val === 8'hCC);

        pop(read_val);
        $display("  Final-Read got : 8'h%0h  (expected DD)", read_val);
        check("T4 Simul R/W: second pop = DD", read_val === 8'hDD);

        // ------------------------------------------------------------------
        // Test 5: Random Stress Test
        // ------------------------------------------------------------------
        $display("--------------------------------------------");
        $display("Test 5: Random Stress Test (50 iterations)");
        begin : t5
            int stress_errors;
            stress_errors = 0;
            for (int i = 0; i < 50; i++) begin
                fork
                    begin
                        if ($urandom_range(0,1)) push($urandom % (2**DATA_WIDTH));
                    end
                    begin
                        if ($urandom_range(0,1) && data_o_valid_o) pop(read_val);
                    end
                join
                @(posedge clk);
            end
            if (data_i_ready_o === 1'bx || data_o_valid_o === 1'bx)
                stress_errors++;
            $display("  Protocol errors: %0d", stress_errors);
            check("T5 Stress: no X on status signals", stress_errors === 0);
        end

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        #50;
        print_summary();
        $finish;
    end

endmodule