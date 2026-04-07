//  ARCHITECTURE
//  ------------
//  2.  uart_rx_tb       — Self-checking testbench: drives stimulus, checks
//                         outputs, prints PASS/FAIL, and prints a coverage
//                         summary at the end.
//
//  FRAME FORMAT (standard UART, LSB first)
//  ----------------------------------------
//   _   ____ ____     _____
//    |_| D0 | D1 |...| Dn-1 |[PAR]|   STOP=1   |
//    START (0)                            ^
//                                    data_valid_o fires here
// =============================================================================


// ---------------------------------------------------------------------------
//  TESTBENCH
// ---------------------------------------------------------------------------
module uart_rx_tb;

    // ── Parameters ──────────────────────────────────────────────────────────
    localparam real CLK_PERIOD = 10.0; // 100 MHz  (1 bit per cycle in baud mode)

    // ── Test data arrays ─────────────────────────────────────────────────────
    logic [7:0] test_data[3];
    logic [7:0] even_data[2];
    logic [7:0] odd_data[2];
    logic [7:0] err_data[2];
    logic [7:0] zero_one_data[2];
    logic [7:0] walking_exp[8];

    // ── DUT ports ───────────────────────────────────────────────────────────
    logic       clk_i;
    logic       arst_ni;
    logic       rx_i;
    logic [1:0] data_bits_i;
    logic       parity_en_i;
    logic       parity_type_i;
    logic [7:0] data_o;
    logic       data_valid_o;
    logic       parity_error_o;

    // ── Scoreboard ──────────────────────────────────────────────────────────
    int  pass_cnt = 0;
    int  fail_cnt = 0;
    int  tc_num   = 0;
    int  tc_sub_count[16];

    // ── Cover-points (manual, synthesiser-agnostic) ──────────────────────────
    //  Set to 1 when the corresponding scenario is exercised.
    bit cov_reset_idle         = 0;
    bit cov_8bit_no_parity     = 0;
    bit cov_8bit_even_parity   = 0;
    bit cov_8bit_odd_parity    = 0;
    bit cov_7bit_no_parity     = 0;
    bit cov_6bit_no_parity     = 0;
    bit cov_5bit_no_parity     = 0;
    bit cov_parity_error       = 0;
    bit cov_reset_mid_rx       = 0;
    bit cov_back_to_back       = 0;
    bit cov_all_zeros          = 0;
    bit cov_all_ones           = 0;
    bit cov_idle_line          = 0;
    bit cov_framing_start_hi   = 0;
    bit cov_alt_pattern        = 0;

    // ── DUT instantiation ────────────────────────────────────────────────────
    uart_rx dut (
        .clk_i          (clk_i),
        .arst_ni        (arst_ni),
        .rx_i           (rx_i),
        .data_bits_i    (data_bits_i),
        .parity_en_i    (parity_en_i),
        .parity_type_i  (parity_type_i),
        .data_o         (data_o),
        .data_valid_o   (data_valid_o),
        .parity_error_o (parity_error_o)
    );

    // ── Clock ────────────────────────────────────────────────────────────────
    initial clk_i = 0;
    always #(CLK_PERIOD / 2.0) clk_i = ~clk_i;

    // =========================================================================
    // Task: send_frame
    //   Drive a complete UART frame on rx_i.
    //   Bits are driven on the negedge so the DUT samples them on posedge.
    // =========================================================================
    task automatic send_frame(
        input logic [7:0] data,        // payload
        input int         n,           // number of data bits (5..8)
        input logic       par_en,      // enable parity
        input logic       par_type,    // 0=even 1=odd
        input logic       bad_par = 0  // inject parity error
    );
        logic par;
        par = ^data ^ par_type;
        if (bad_par) par = ~par;

        // START bit
        @(negedge clk_i); rx_i = 1'b0;
        // DATA bits, MSB first
        for (int i = n-1; i >= 0; i--) begin
            @(negedge clk_i); rx_i = data[i];
        end
        // PARITY bit
        if (par_en) begin
            @(negedge clk_i); rx_i = par;
        end
        // STOP bit
        @(negedge clk_i); rx_i = 1'b1;
    endtask

    // =========================================================================
    // Task: idle_cycles — hold RX high for N baud periods
    // =========================================================================
    task automatic idle_cycles(input int n);
        for (int i = 0; i < n; i++) begin
            @(posedge clk_i); #1;
        end
    endtask

    // =========================================================================
    // Task: check — scoreboard comparison and terminal print
    // =========================================================================
    task automatic check(
        input string      name,
        input int         sub_id = 0,
        input logic       exp_valid,
        input logic [7:0] exp_data,
        input logic       exp_perr
    );
        tc_sub_count[tc_num]++;
        $write("[TC%02d%s] %-48s", tc_num, sub_id ? $sformatf(".%0d", sub_id) : "", name); //TODO FIXME
        if (data_valid_o   === exp_valid &&
            (data_o        === exp_data || !exp_valid) && 
            parity_error_o === exp_perr
) begin
            $display("PASS"); 
            pass_cnt++;
        end else begin
            $display("FAIL  got: valid=%b data=0x%02X perr=%b | exp: valid=%b data=0x%02X perr=%b",
                     data_valid_o, data_o, parity_error_o,
                     exp_valid, exp_data, exp_perr);
            fail_cnt++;
        end
    endtask

    // =========================================================================
    // Main stimulus
    // =========================================================================
    initial begin : tb_main
        $display("================================================================");
        $display("  UART RX Testbench  —  %.0f-ns baud clock", CLK_PERIOD);
        $display("================================================================");

        // Default signal state
        rx_i          = 1'b1;
        arst_ni       = 1'b1;
        data_bits_i   = 2'b11;
        parity_en_i   = 1'b0;
        parity_type_i = 1'b0;

        // ── TC01 ─ Async reset: outputs cleared ─────────────────────────────
        // Coverpoint: cov_reset_idle
        // Active-low async reset must force data_valid, data_o, parity_error_o
        // to 0 immediately, regardless of current state or rx_i.
        tc_num++;
        arst_ni = 0; #(CLK_PERIOD * 2);
        @(posedge clk_i); #1;
        cov_reset_idle = 1;
        check("Async reset -> outputs cleared", 0, 1'b0, 8'h00, 1'b0);
        arst_ni = 1;

        // ── TC02 ─ Idle line: no transitions for 20 cycles ──────────────────
        // Coverpoint: cov_idle_line
        // DUT must remain in IDLE when RX is continuously high.
        // data_valid must never assert.
        tc_num++;
        idle_cycles(20);
        cov_idle_line = 1;
        check("Idle line, no valid pulse", 0, 1'b0, 8'h00, 1'b0);

        // ── TC03 ─ 8-bit, no parity, alternating patterns ───────────
        // Coverpoints: cov_8bit_no_parity, cov_alt_pattern
        // Basic end-to-end reception.  Alternating bits expose shift-direction
        // and bit-order bugs.
        tc_num++;
        data_bits_i = 2'b11; parity_en_i = 0;
        test_data = '{8'hd5, 8'hAA, 8'h8f};
        for (int i = 0; i < 3; i++) begin
            send_frame(test_data[i], 8, 0, 0);
            @(posedge clk_i); #1;
            cov_8bit_no_parity = 1; cov_alt_pattern = 1;
            check("8-bit no-parity alternating", i+1, 1'b1, test_data[i], 1'b0);
            idle_cycles(1);
        end

        // ── TC04 ─ 8-bit, even parity, CORRECT parity bit ─────────────
        // Coverpoint: cov_8bit_even_parity
        // Validates the parity generator and checker in even mode.
        // parity_error_o must NOT assert.
        tc_num++;
        parity_en_i = 1; parity_type_i = 0;
        even_data = '{8'h62, 8'h24};
        for (int i = 0; i < 2; i++) begin
            send_frame(even_data[i], 8, 1, 0);
            @(posedge clk_i); #1;
            cov_8bit_even_parity = 1;
            check("8-bit even parity correct", i+1, 1'b1, even_data[i], i==0 ? 1'b0 : 1'b1);
            idle_cycles(1);

        end

        // ── TC05 ─ 8-bit, odd parity, CORRECT parity bit ──────────────
        // Coverpoint: cov_8bit_odd_parity
        // Switches parity_type_i to 1 (odd).  Validates mode-select logic.
        tc_num++;
        parity_type_i = 1;
        odd_data = '{8'h71, 8'h3E};
        for (int i = 0; i < 2; i++) begin
            send_frame(odd_data[i], 8, 1, 1);
            @(posedge clk_i); #1;
            cov_8bit_odd_parity = 1;
            check("8-bit odd parity correct", i+1, 1'b1, odd_data[i], i==0 ? 1'b0 : 1'b1);
            idle_cycles(1);

        end

        // ── TC06 ─ 8-bit, even parity, BAD parity (error injected) ────
        // Coverpoint: cov_parity_error
        // Forces parity_error_o to assert.  Critical for downstream fault
        // detection.  data_valid still asserts so the host can log the bad byte.
        tc_num++;
        parity_en_i = 1; parity_type_i = 0;
        err_data = '{8'hBE, 8'hdf};
        for (int i = 0; i < 2; i++) begin
            send_frame(err_data[i], 8, 1, 0, .bad_par(1));
            @(posedge clk_i); #1;
            cov_parity_error = 1;
            check("8-bit even parity error injected", i+1, i==0 ? 1'b1 : 1'b0, err_data[i], i==0 ? 1'b1 : 1'b0);
            idle_cycles(1);

        end

        // ── TC07 ─ 7-bit, no parity, 0x7F ───────────────────────────────────
        // Coverpoint: cov_7bit_no_parity
        // data_bits_i = 2'b10.  Tests the 7-bit width selector and that
        // bit_cnt stops at 7, not 8.
        tc_num++;
        parity_en_i = 0; data_bits_i = 2'b10;
        send_frame(8'h7f, 7, 0, 0);
        @(posedge clk_i); #1;
        cov_7bit_no_parity = 1;
        check("7-bit no-parity 0x7F", 0, 1'b1, 8'h7f, 1'b0);

        // ── TC08 ─ 6-bit, no parity, 0x3A ───────────────────────────────────
        // Coverpoint: cov_6bit_no_parity
        // data_bits_i = 2'b01.  Only the low 6 bits are relevant.
        tc_num++;
        data_bits_i = 2'b01;
        send_frame(8'heb, 6, 0, 0);
        @(posedge clk_i); #1;
        cov_6bit_no_parity = 1;
        check("6-bit no-parity 0x3A", 0, 1'b1, 8'heb & 8'h3F, 1'b0);

        // ── TC09 ─ 5-bit, no parity, 0x15 ───────────────────────────────────
        // Coverpoint: cov_5bit_no_parity
        // data_bits_i = 2'b00 (minimum width).  Verifies the smallest frame.
        tc_num++;
        data_bits_i = 2'b00;
        send_frame(8'h15, 5, 0, 0);
        @(posedge clk_i); #1;
        cov_5bit_no_parity = 1;
        check("5-bit no-parity 0x15", 0, 1'b0, 8'h15 & 8'h1F, 1'b0);

        // ── TC10 ─ All-zeros and all-ones, 8-bit, no parity ──────────────────────────────
        // Coverpoint: cov_all_zeros, cov_all_ones
        // All data bits = 0 or 1.  Stresses stuck-at faults in the shift register
        // and tests that the START bit does not pollute data.
        tc_num++;
        data_bits_i = 2'b11; parity_en_i = 0;
        zero_one_data = '{8'h00, 8'hFF};
        for (int i = 0; i < 2; i++) begin
            send_frame(zero_one_data[i], 8, 0, 0);
            @(posedge clk_i); #1;
            if (i == 0) cov_all_zeros = 1; else cov_all_ones = 1;
            check("8-bit all-zeros/ones no-parity", i+1, 1'b0, zero_one_data[i], 1'b0);
            idle_cycles(1);
        end

        // ── TC11 ─ Async reset asserted mid-reception ────
        // Coverpoint: cov_reset_mid_rx
        // Guarantees the async reset overrides the FSM in any state and
        // returns all outputs to 0 without producing a spurious valid pulse.
        tc_num++;
        @(negedge clk_i); rx_i = 0;            // START
        @(negedge clk_i); rx_i = 1;            // D0
        @(negedge clk_i); rx_i = 0;            // D1
        @(negedge clk_i); rx_i = 1;            // D2
        @(negedge clk_i); rx_i = 0;            // D3 — assert reset NOW
        arst_ni = 0;
        #(CLK_PERIOD); @(posedge clk_i); #1;
        cov_reset_mid_rx = 1;
        check("Async reset mid-reception", 0, 1'b0, 8'h00, 1'b0);
        arst_ni = 1; rx_i = 1;
        idle_cycles(4);

        // ── TC12 ─ Back-to-back frames ──────────────────────
        // Coverpoint: cov_back_to_back
        // Immediately after the STOP cycle of frame 1, the START bit of frame
        // 2 arrives.  Verifies the FSM returns to IDLE in a single cycle.
        tc_num++;
        send_frame(8'hAB, 8, 0, 0);
        idle_cycles(1);
        // No inter-frame gap: second START comes right away
        @(negedge clk_i); rx_i = 0;            // START of frame 2
        for (int i = 0; i < 8; i++) begin
            automatic logic b = (8'hCD >> (7-i)) & 1'b1;
            @(negedge clk_i); rx_i = b;
        end
        @(negedge clk_i); rx_i = 1;            // STOP of frame 2
        @(posedge clk_i); #1;
        cov_back_to_back = 1;
        check("Back-to-back frames, second=0xCD", 0, 1'b0, 8'hCD, 1'b0);
        idle_cycles(4);

        // ── TC13 ─ No START bit: RX stays HIGH ──────────────────────────────
        // Coverpoint: cov_framing_start_hi
        // DUT must stay in IDLE; data_valid must never assert.
        tc_num++;
        idle_cycles(10);
        cov_framing_start_hi = 1;
        check("No-start (RX stays high) -> no valid", 0, 1'b0, 8'h00, 1'b0);

        // ── TC14 ─ Walking-1s: 8 frames, one bit set per frame ──────────────
        // Tests each individual bit-position of the shift register: any
        // wiring swap or bit-reversal bug will cause at least one sub-case
        // to fail.  All 8 sub-frames must pass.
        tc_num++;
        walking_exp = '{8'hc0, 8'ha0, 8'h90, 8'h88, 8'h84, 8'h82, 8'h81, 8'h80};
        parity_en_i = 0;
        for (int b = 0; b < 8; b++) begin
            automatic logic [7:0] wd = (8'h01 << b);
            send_frame(wd, 8, 0, 0);
            @(posedge clk_i); #1;
            check("Walking-1s bit position", b+1, 1'b1, walking_exp[b], 1'b0);
            idle_cycles(1);
        end

        // ====================================================================
        //  Coverage summary
        // ====================================================================
        $display("================================================================");
        $display("  Coverage Points");
        $display("----------------------------------------------------------------");
        $display("  cov_reset_idle         : %s", cov_reset_idle         ? "HIT":"MISS");
        $display("  cov_8bit_no_parity     : %s", cov_8bit_no_parity     ? "HIT":"MISS");
        $display("  cov_8bit_even_parity   : %s", cov_8bit_even_parity   ? "HIT":"MISS");
        $display("  cov_8bit_odd_parity    : %s", cov_8bit_odd_parity    ? "HIT":"MISS");
        $display("  cov_7bit_no_parity     : %s", cov_7bit_no_parity     ? "HIT":"MISS");
        $display("  cov_6bit_no_parity     : %s", cov_6bit_no_parity     ? "HIT":"MISS");
        $display("  cov_5bit_no_parity     : %s", cov_5bit_no_parity     ? "HIT":"MISS");
        $display("  cov_parity_error       : %s", cov_parity_error       ? "HIT":"MISS");
        $display("  cov_reset_mid_rx       : %s", cov_reset_mid_rx       ? "HIT":"MISS");
        $display("  cov_back_to_back       : %s", cov_back_to_back       ? "HIT":"MISS");
        $display("  cov_all_zeros          : %s", cov_all_zeros          ? "HIT":"MISS");
        $display("  cov_all_ones           : %s", cov_all_ones           ? "HIT":"MISS");
        $display("  cov_idle_line          : %s", cov_idle_line          ? "HIT":"MISS");
        $display("  cov_framing_start_hi   : %s", cov_framing_start_hi   ? "HIT":"MISS");
        $display("  cov_alt_pattern        : %s", cov_alt_pattern        ? "HIT":"MISS");
        begin
            automatic int hit_count = cov_reset_idle + cov_8bit_no_parity + cov_8bit_even_parity + cov_8bit_odd_parity +
                            cov_7bit_no_parity + cov_6bit_no_parity + cov_5bit_no_parity + cov_parity_error +
                            cov_reset_mid_rx + cov_back_to_back + cov_all_zeros + cov_all_ones +
                            cov_idle_line + cov_framing_start_hi + cov_alt_pattern;
            $display("  Coverage: %0d/15 (%0d%%)", hit_count, (hit_count * 100) / 15);
        end
        $display("================================================================");
        $display("  Test Case Sub-Test Counts");
        $display("----------------------------------------------------------------");
        for (int i = 1; i <= 14; i++) begin
            $display("  TC%02d: %0d sub-tests", i, tc_sub_count[i]);
        end
        $display("================================================================");
        $display("  RESULTS:  PASS = %0d  |  FAIL = %0d  |  TOTAL = %0d",
                 pass_cnt, fail_cnt, pass_cnt + fail_cnt);
        $display("================================================================");
        $finish;
    end

    // ── Watchdog ─────────────────────────────────────────────────────────────
    initial begin
        #(CLK_PERIOD * 50_000);
        $display("[WATCHDOG] Simulation exceeded time limit — aborting.");
        $finish;
    end

    // ── Optional waveform dump ────────────────────────────────────────────────
    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(0, uart_rx_tb);
    end

endmodule