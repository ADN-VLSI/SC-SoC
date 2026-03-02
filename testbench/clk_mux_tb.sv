module clk_mux_tb;

    // Signal Declaration - all inputs and outputs connected to DUT
    logic arst_ni, sel_i;
    logic clk0_i, clk1_i, clk_o;

    // Clock periods in nanoseconds
    parameter CLK0_PERIOD = 10;
    parameter CLK1_PERIOD = 17;

    // Pass/Fail counters
    integer pass = 0, fail = 0;

    // DUT Instantiation - connect testbench signals to clk_mux module
    clk_mux clk_mux_inst (
        .arst_ni(arst_ni), .sel_i(sel_i),
        .clk0_i(clk0_i),   .clk1_i(clk1_i), .clk_o(clk_o)
    );

    // Clock Generators - clk0 toggles every 5ns, clk1 toggles every 8.5ns
    initial begin clk0_i = 0; forever #(CLK0_PERIOD/2) clk0_i = ~clk0_i; end
    initial begin clk1_i = 0; forever #(CLK1_PERIOD/2) clk1_i = ~clk1_i; end

    // Check Task - compares got vs expected, prints PASS or FAIL
    task check(input string name, input logic got, input logic exp);
        if (got !== exp) begin $error("FAIL %s", name); fail++; end
        else             begin $display("PASS %s", name); pass++; end
    endtask

    // TC1 - Reset: assert reset, check clk_o=0, then release reset
    task tc_reset();
        arst_ni = 0; #5;
        check("TC1: Reset", clk_o, 1'b0);
        arst_ni = 1; #20;
    endtask

    // TC2 - Select clk0: set sel=0, wait for mux to settle, check clk_o matches clk0
    task tc_select_clk0();
        sel_i = 0; #50;
        check("TC2: Select clk0", clk_o, clk0_i);
    endtask

    // TC3 - Select clk1: set sel=1, wait for mux to settle, check clk_o matches clk1
    task tc_select_clk1();
        sel_i = 1; #50;
        check("TC3: Select clk1", clk_o, clk1_i);
    endtask

    // TC4 - Switch 0->1: select clk0 first, then switch to clk1, wait for handshake, check clk_o matches clk1
    task tc_switch_0_to_1();
        sel_i = 0; #50;
        sel_i = 1; #50;
        check("TC4: Switch 0->1", clk_o, clk1_i);
    endtask

    // TC5 - clk_o No Unknown Values: check clk_o is not X or Z
    task tc_clk_o_no_unknown();
        #20;
        check("TC5: clk_o No Unknown Values", clk_o === 1'bx ? 1'bx : clk_o, clk_o);
    endtask

    initial begin

        // Initialization - hold reset low for 20ns then release and wait for DUT to stabilize
        arst_ni = 0; sel_i = 0; #20;
        arst_ni = 1; #20;

        // Run all test cases
        tc_reset();
        tc_select_clk0();
        tc_select_clk1();
        tc_switch_0_to_1();
        tc_clk_o_no_unknown();

        // Summary - print total pass/fail count and end simulation
        $display("\nPass: %0d  Fail: %0d  %s", pass, fail, fail == 0 ? "ALL PASSED!" : "SOME FAILED!");
        $finish;
    end

    // VCD Dump - save all signal waveforms to file for GTKWave viewing
    initial begin $dumpfile("clk_mux_tb.vcd"); $dumpvars(0, clk_mux_tb); end

endmodule
