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

    // AXI driver — creates cpu_write_32() and cpu_read_32()
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
    string      active_testcase = "";
    int         testcase_pass = 0;
    int         testcase_fail = 0;
    int         testcase_run_count = 0;

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

    task automatic testcase_begin(input string name);
        active_testcase = name;
        testcase_pass   = 0;
        testcase_fail   = 0;
        testcase_run_count++;
        $display("------------------------------------------------------------");
        $display("Running %s", name);
        $display("------------------------------------------------------------");
    endtask

    task automatic testcase_check(
        input logic  ok,
        input string msg
    );
        if (ok) begin
            testcase_pass++;
            total_pass++;
            $display("[PASS][%s] %s", active_testcase, msg);
        end else begin
            testcase_fail++;
            total_fail++;
            $display("[FAIL][%s] %s", active_testcase, msg);
        end
    endtask

    task automatic testcase_end();
        $display("[%s] pass=%0d fail=%0d", active_testcase, testcase_pass, testcase_fail);
    endtask

    // poll STAT until rx_empty=0 (bit22)
    task automatic wait_rx_data();
        logic [31:0] stat;
        do axi_read(UART_STAT_OFFSET, stat);
        while (stat[22] == 1);
    endtask

    // poll STAT until tx_empty=1 (bit20)
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
    // CFG = 0x000341B0: psclr=4, clk_div=432, db=3(8bit), no parity
    // baud = 100MHz / 4 / (432>>3) / 4 = 115741 Hz
    ////////////////////////////////////////////////////////////////////////////

    task automatic configure_uart();
        logic [31:0] readback;

        // disable TX+RX — CFG only written when FIFOs empty
        axi_write(UART_CTRL_OFFSET, 32'h0000_0000);
        repeat(10) @(posedge clk_i);

        // set baud rate and frame format
        axi_write(UART_CFG_OFFSET, 32'h0003_41B0);
        repeat(10) @(posedge clk_i);

        // verify CFG accepted
        axi_read(UART_CFG_OFFSET, readback);
        if (readback !== 32'h0003_41B0)
            $display("  WARNING: CFG=0x%08h expected 0x000341B0", readback);
        else
            $display("  CFG OK: 0x%08h  baud=%0d", readback, BAUD_RATE);

        // enable TX+RX: rx_en[4]=1, tx_en[3]=1 = 0x18
        axi_write(UART_CTRL_OFFSET, 32'h0000_0018);
        repeat(10) @(posedge clk_i);

        axi_read(UART_CTRL_OFFSET, readback);
        $display("  CTRL: 0x%08h  (expect 0x00000018)", readback);

        // wait for clk_div chain to stabilise and uart_tx to reach IDLE
        repeat(STABILISE_CYCLES) @(posedge clk_i);
    endtask

    ////////////////////////////////////////////////////////////////////////////
    // INCLUDE TESTCASES
    ////////////////////////////////////////////////////////////////////////////
    `include "uart_subsystem_tb/tc3.sv"
    `include "uart_subsystem_tb/tc7.sv"
    `include "uart_subsystem_tb/tc8.sv"

    ////////////////////////////////////////////////////////////////////////////
    // TEST SEQUENCE
    ////////////////////////////////////////////////////////////////////////////

    initial begin
        string selected_test;

        $timeformat(-9, 1, " ns", 20);
        $display("------------------------------------------------------------");
        $display("uart_subsystem TB | BAUD=%0d | FIFO_DEPTH=%0d",
                 BAUD_RATE, FIFO_DEPTH);
        $display("------------------------------------------------------------");

        if (!$value$plusargs("TEST=%s", selected_test))
            selected_test = "all";

        case (selected_test)
            "all": begin
                tc3();
                tc7();
                tc8();
            end
            "default": begin
                tc3();
                tc7();
                tc8();
            end
            "tc3": tc3();
            "tc7": tc7();
            "tc8": tc8();
            default: begin
                $display("Unsupported TEST=%s", selected_test);
                $display("Supported values: all, default, tc3, tc7, tc8");
                $finish;
            end
        endcase

        u_uart_if.wait_till_idle();

        $display("------------------------------------------------------------");
        $display("TESTCASES RUN:%0d", testcase_run_count);
        $display("PASS:%0d  FAIL:%0d", total_pass, total_fail);
        if (testcase_run_count == 0)
            $display("NO TESTCASES RAN");
        else if (total_fail == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("------------------------------------------------------------");

        $finish;
    end

endmodule
