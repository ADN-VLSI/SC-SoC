`include "package/uart_pkg.sv"
`include "package/uart_subsystem_pkg.sv"
`include "vip/simple_axil_m_driver.svh"

module uart_subsystem_tb;

    import uart_pkg::*;

    ////////////////////////////////////////////////////////////////////////////
    // PARAMETERS
    ////////////////////////////////////////////////////////////////////////////

    localparam int FIFO_DEPTH       = uart_subsystem_pkg::UART_FIFO_DEPTH;
    localparam int BAUD_RATE        = 115741;
    localparam int STABILISE_CYCLES = 20000;

    ////////////////////////////////////////////////////////////////////////////
    // SIGNALS
    ////////////////////////////////////////////////////////////////////////////

    logic clk_i;
    logic arst_ni;
    logic int_en_o;

    uart_axil_req_t req_i;
    uart_axil_rsp_t resp_o;

    `SIMPLE_AXIL_M_DRIVER(cpu, clk_i, arst_ni, req_i, resp_o)

    ////////////////////////////////////////////////////////////////////////////
    // UART INTERFACE
    ////////////////////////////////////////////////////////////////////////////

    uart_if u_uart_if();

    ////////////////////////////////////////////////////////////////////////////
    // DUT
    ////////////////////////////////////////////////////////////////////////////

    uart_subsystem #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_dut (
        .clk_i    (clk_i),
        .arst_ni  (arst_ni),
        .req_i    (req_i),
        .resp_o   (resp_o),
        .rx_i     (u_uart_if.tx),
        .tx_o     (u_uart_if.rx),
        .int_en_o (int_en_o)
    );

    ////////////////////////////////////////////////////////////////////////////
    // CLOCK
    ////////////////////////////////////////////////////////////////////////////

    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    ////////////////////////////////////////////////////////////////////////////
    // COUNTERS AND SCOREBOARD
    ////////////////////////////////////////////////////////////////////////////

    int         total_pass = 0;
    int         total_fail = 0;
    logic [7:0] scoreboard [$];

    ////////////////////////////////////////////////////////////////////////////
    // HELPER TASKS
    ////////////////////////////////////////////////////////////////////////////

    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        logic [1:0] resp;
        cpu_write_32(addr, data, resp);
        if (resp !== 2'b00)
            $display("  WARNING: write 0x%08h resp=SLVERR", addr);
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        logic [1:0] resp;
        cpu_read_32(addr, data, resp);
    endtask

    task automatic check(
        input logic  ok,
        input string msg
    );
        if (ok) begin
            total_pass++;
            $display("[PASS] %s", msg);
        end else begin
            total_fail++;
            $display("[FAIL] %s", msg);
        end
    endtask

    task automatic wait_rx_data();
        logic [31:0] stat;
        do axi_read(UART_STAT_OFFSET, stat);
        while (stat[22] == 1);
    endtask

    task automatic wait_tx_done();
        logic [31:0] stat;
        do axi_read(UART_STAT_OFFSET, stat);
        while (stat[20] == 0);
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // RESET
    ////////////////////////////////////////////////////////////////////////////

    task automatic reset_dut();
        arst_ni = 0;
        req_i   = '0;
        scoreboard.delete();
        repeat(20) @(posedge clk_i);
        arst_ni = 1;
        repeat(10) @(posedge clk_i);
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // CONFIGURE UART
    ////////////////////////////////////////////////////////////////////////////

    task automatic configure_uart();
        logic [31:0] readback;

        axi_write(UART_CTRL_OFFSET, 32'h0000_0000);
        repeat(10) @(posedge clk_i);

        axi_write(UART_CFG_OFFSET, 32'h0003_41B0);
        repeat(10) @(posedge clk_i);

        axi_read(UART_CFG_OFFSET, readback);
        if (readback !== 32'h0003_41B0)
            $display("  WARNING: CFG=0x%08h expected 0x000341B0", readback);
        else
            $display("  CFG OK: 0x%08h  baud=%0d", readback, BAUD_RATE);

        axi_write(UART_CTRL_OFFSET, 32'h0000_0018);
        repeat(10) @(posedge clk_i);

        axi_read(UART_CTRL_OFFSET, readback);
        $display("  CTRL: 0x%08h  (expect 0x00000018)", readback);

        repeat(STABILISE_CYCLES) @(posedge clk_i);
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // RUN ONE TEST — snapshot counters before/after to get per-test p/f
    ////////////////////////////////////////////////////////////////////////////

    task automatic run_test(
        input  int test_num,
        output int p,
        output int f
    );
        int p_before, f_before;
        p_before = total_pass;
        f_before = total_fail;

        case (test_num)
            0:  tc0();
            1:  tc1();
            2:  tc2();
            3:  tc3();
            4:  tc4();
            5:  tc5();
            6:  tc6();
            7:  tc7();
            8:  tc8();
            9:  tc9();
            10: tc10();
            11: tc11();
            12: tc12();
            13: tc13();
            16: tc16();
            default: $fatal(1, "Invalid test number %0d. Valid range 0-17.", test_num);
        endcase

        p = total_pass - p_before;
        f = total_fail - f_before;
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // INCLUDE TESTCASES
    ////////////////////////////////////////////////////////////////////////////
    `include "uart_subsystem_tb/tc0.sv"
    `include "uart_subsystem_tb/tc1.sv"
    `include "uart_subsystem_tb/tc2.sv"
    `include "uart_subsystem_tb/tc3.sv"
    `include "uart_subsystem_tb/tc4.sv"
    `include "uart_subsystem_tb/tc5.sv"
    `include "uart_subsystem_tb/tc6.sv"
    `include "uart_subsystem_tb/tc7.sv"
    `include "uart_subsystem_tb/tc8.sv"
    `include "uart_subsystem_tb/tc9.sv"
    `include "uart_subsystem_tb/tc10.sv"
    `include "uart_subsystem_tb/tc11.sv"
    `include "uart_subsystem_tb/tc12.sv"
    `include "uart_subsystem_tb/tc13.sv"
    `include "uart_subsystem_tb/tc16.sv"

    ////////////////////////////////////////////////////////////////////////////
    // TEST SEQUENCE
    ////////////////////////////////////////////////////////////////////////////

    initial begin
        int test_num;
        int p, f;
        int total_p, total_f;

        total_p = 0;
        total_f = 0;

        $timeformat(-9, 1, " ns", 20);
        $display("------------------------------------------------------------");
        $display("uart_subsystem TB | BAUD=%0d | FIFO_DEPTH=%0d",
                 BAUD_RATE, FIFO_DEPTH);
        $display("------------------------------------------------------------");

        reset_dut();
        configure_uart();

        if (!$value$plusargs("TEST=%d", test_num))
            test_num = -1;

        if (test_num == -1) begin
            for (int i = 0; i <= 17; i++) begin
                run_test(i, p, f);
                $display("TEST %0d RESULT: PASS=%0d FAIL=%0d", i, p, f);
                total_p += p;
                total_f += f;
            end
        end else begin
            run_test(test_num, p, f);
            $display("SELECTED TEST %0d RESULT: PASS=%0d FAIL=%0d", test_num, p, f);
            total_p += p;
            total_f += f;
        end

        u_uart_if.wait_till_idle();

        $display("------------------------------------------------------------");
        $display("TOTAL PASS=%0d  TOTAL FAIL=%0d", total_p, total_f);
        if (total_f == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("------------------------------------------------------------");

        $finish;
    end

endmodule
