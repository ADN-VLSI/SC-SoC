module clk_mux_tb;

    // Signals
    logic arst_ni, sel_i, clk0_i, clk1_i, clk_o;

    // Clock parameters
    parameter CLK0_PERIOD = 10;
    parameter CLK1_PERIOD = 17;

    // Counters for results
    integer total_pass = 0;
    integer total_error = 0;

    // Instantiate Clock Mux
    clk_mux clk_mux_inst (
        .arst_ni(arst_ni),
        .sel_i(sel_i),
        .clk0_i(clk0_i),
        .clk1_i(clk1_i),
        .clk_o(clk_o)
    );

    // -------------------------
    // Clock generation
    // -------------------------
    initial clk0_i = 0;
    always #(CLK0_PERIOD/2) clk0_i = ~clk0_i;

    initial clk1_i = 0;
    always #(CLK1_PERIOD/2) clk1_i = ~clk1_i;

    // -------------------------
    // Monitor signals
    // -------------------------
    initial begin
        $display("Time | sel_i | clk0_i | clk1_i | clk_o");
        $monitor("%0t |   %b   |   %b   |   %b   |  %b",
                  $time, sel_i, clk0_i, clk1_i, clk_o);
    end

    // -------------------------
    // Task: Check clk_o immediately
    // -------------------------
    task check_clk_o_sync(input logic sel);
    begin
        #1; // small delay for signal settle
        if (sel == 0) begin
            if (clk_o !== clk0_i) begin
                $error("[%0t] ERROR: clk_o does not follow clk0!", $time);
                total_error = total_error + 1;
            end else begin
                total_pass = total_pass + 1;
                $display("[%0t] PASS: clk_o follows clk0", $time);
            end
        end 
        else begin
            if (clk_o !== clk1_i) begin
                $error("[%0t] ERROR: clk_o does not follow clk1!", $time);
                total_error = total_error + 1;
            end else begin
                total_pass = total_pass + 1;
                $display("[%0t] PASS: clk_o follows clk1", $time);
            end
        end
    end
    endtask

    // -------------------------
    // Test Cases
    // -------------------------

    // TC1 – Reset Verification
    task tc_reset();
    begin
        $display("\n[%0t] TC1: Reset Behavior", $time);
        arst_ni = 0; #20;
        arst_ni = 1; #50;
        $display("[%0t] Reset released", $time);
        check_clk_o_sync(sel_i);
    end
    endtask

    // TC2 – Select clk0
    task tc_select_clk0();
    begin
        $display("\n[%0t] TC2: Select clk0", $time);
        sel_i = 0; 
        check_clk_o_sync(0);
    end
    endtask

    // TC3 – Select clk1
    task tc_select_clk1();
    begin
        $display("\n[%0t] TC3: Select clk1", $time);
        sel_i = 1; 
        check_clk_o_sync(1);
    end
    endtask

    // TC4 – Switch 0 -> 1
    task tc_switch_0_to_1();
    begin
        $display("\n[%0t] TC4: Switch 0 -> 1", $time);
        sel_i = 0; check_clk_o_sync(0);
        sel_i = 1; check_clk_o_sync(1);
    end
    endtask

    // TC5 – clk_o Behavior Verification (assign simulation)
    task tc_show_assign_behavior();
    begin
        $display("\n[%0t] TC5: clk_o Behavior Verification", $time);
        $display("Simulate effect if clk_o was driven by assign (internal FFs not respected)");

        sel_i = 0; arst_ni = 1;

        // Rapid toggles to simulate unsafe assign behavior
        clk0_i = 0; clk1_i = 0;
        #1 clk0_i = 1; #0.5;
        $display("[%0t] clk0 toggled, clk_o = %b", $time, clk_o);

        #1 clk1_i = 1; #0.5;
        $display("[%0t] clk1 toggled, clk_o = %b", $time, clk_o);

        #1 clk0_i = 0; #0.5;
        $display("[%0t] clk0 toggled again, clk_o = %b", $time, clk_o);

        #1 clk1_i = 0; #0.5;
        $display("[%0t] clk1 toggled again, clk_o = %b", $time, clk_o);

        $display("[%0t] Note: If assign was used in clk_mux, you would see unexpected values above.", $time);
        total_pass = total_pass + 1;
    end
    endtask

    // -------------------------
    // Run all test cases
    // -------------------------
    initial begin
        sel_i = 0;
        arst_ni = 1;

        tc_reset();
        tc_select_clk0();
        tc_select_clk1();
        tc_switch_0_to_1();
        tc_show_assign_behavior(); // TC5

        $display("\n==============================");
        $display("Simulation Summary:");
        $display("Total Passes : %0d", total_pass);
        $display("Total Errors : %0d", total_error);

        if (total_error == 0)
            $display("RESULT: ALL TESTS PASSED!");
        else
            $display("RESULT: SOME TESTS FAILED!");

        $display("==============================");

        $stop;
    end

    // -------------------------
    // VCD Dump
    // -------------------------
    initial begin
        $dumpfile("clk_mux_tb.vcd");
        $dumpvars(0, clk_mux_tb);
        #500;
        $finish;
    end

endmodule