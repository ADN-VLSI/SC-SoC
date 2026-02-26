module clk_mux_tb;

    // -------------------------
    // Signals
    // -------------------------
    logic arst_ni, sel_i;
    logic clk0_i, clk1_i, clk_o;

    // Clock periods
    parameter CLK0_PERIOD = 10;
    parameter CLK1_PERIOD = 17;

    // Counters
    integer total_pass = 0;
    integer total_error = 0;

    // -------------------------
    // Instantiate DUT
    // -------------------------
    clk_mux clk_mux_inst (
        .arst_ni(arst_ni),
        .sel_i(sel_i),
        .clk0_i(clk0_i),
        .clk1_i(clk1_i),
        .clk_o(clk_o)
    );

    // -------------------------
    // Clock generation (start AFTER reset)
    // -------------------------
    initial begin
        clk0_i = 0;
        clk1_i = 0;
        arst_ni = 0;   // assert reset at time 0
        sel_i = 0;     // default select

        #20 arst_ni = 1; // release reset after 20 ns

        // start clk0 toggling after reset
        forever #(CLK0_PERIOD/2) clk0_i = ~clk0_i;
    end

    initial begin
        // wait until reset released
        @(posedge arst_ni);
        // start clk1 toggling after reset
        forever #(CLK1_PERIOD/2) clk1_i = ~clk1_i;
    end

    // -------------------------
    // Monitor
    // -------------------------
    initial begin
        $display("Time | sel_i | clk0_i | clk1_i | clk_o");
        $monitor("%0t |   %b   |   %b   |   %b   |  %b",
                  $time, sel_i, clk0_i, clk1_i, clk_o);
    end

    // -------------------------
    // Task: Check clk_o at rising edge of selected clock
    // -------------------------
    task check_clk_o(input logic sel);
        begin
            if (sel == 0) @(posedge clk0_i);
            else         @(posedge clk1_i);

            if (sel == 0 && clk_o !== clk0_i) begin
                $error("[%0t] ERROR: clk_o != clk0", $time);
                total_error = total_error + 1;
            end else if (sel == 1 && clk_o !== clk1_i) begin
                $error("[%0t] ERROR: clk_o != clk1", $time);
                total_error = total_error + 1;
            end else begin
                $display("[%0t] PASS: clk_o follows selected clk", $time);
                total_pass = total_pass + 1;
            end
        end
    endtask

    // -------------------------
    // Test Cases
    // -------------------------
    task tc_reset();
        begin
            $display("\n[%0t] TC1: Reset test", $time);
            check_clk_o(sel_i);
            #50; // wait a few ns for waveform observation
        end
    endtask

    task tc_select_clk0();
        begin
            $display("\n[%0t] TC2: Select clk0", $time);
            sel_i = 0;
            check_clk_o(0);
            #50;
        end
    endtask

    task tc_select_clk1();
        begin
            $display("\n[%0t] TC3: Select clk1", $time);
            sel_i = 1;
            check_clk_o(1);
            #50;
        end
    endtask

    task tc_switch_0_to_1();
        begin
            $display("\n[%0t] TC4: Switch 0->1", $time);
            sel_i = 0; check_clk_o(0); #20;
            sel_i = 1; check_clk_o(1); #20;
        end
    endtask

    // -------------------------
    // Run all tests
    // -------------------------
    initial begin
        tc_reset();
        tc_select_clk0();
        tc_select_clk1();
        tc_switch_0_to_1();

        $display("\n==============================");
        $display("Simulation Summary:");
        $display("Total Passes : %0d", total_pass);
        $display("Total Errors : %0d", total_error);
        if (total_error == 0)
            $display("RESULT: ALL TESTS PASSED!");
        else
            $display("RESULT: SOME TESTS FAILED!");
        $display("==============================");

        // -------------------------
        // Wait extra time to capture waveforms
        // -------------------------
        #200; // allow clocks and clk_o to toggle in GTKWave

        $display("\nSimulation complete at %0t ns", $time);
        $finish;
    end

    // -------------------------
    // VCD dump
    // -------------------------
    initial begin
        $dumpfile("clk_mux_tb.vcd");
        $dumpvars(0, clk_mux_tb);
    end

endmodule