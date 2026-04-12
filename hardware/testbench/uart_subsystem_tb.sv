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
    string      current_testcase = "";
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

    task automatic testcase_begin(input string name);
        current_testcase = name;
        $display("\n[%s] Starting...", current_testcase);
    endtask

    task automatic testcase_check(
        input logic  ok,
        input string msg
    );
        string scoped_msg;

        scoped_msg = (current_testcase == "") ? msg : $sformatf("%s | %s", current_testcase, msg);
        check(ok, scoped_msg);
    endtask

    task automatic testcase_end();
        if (current_testcase != "")
            $display("[%s] Completed.\n", current_testcase);
        current_testcase = "";
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

    task automatic tc0();  $display("[SKIP] tc0 is not implemented in this workspace.");  endtask
    task automatic tc1();  $display("[SKIP] tc1 is not implemented in this workspace.");  endtask
    task automatic tc4();  $display("[SKIP] tc4 is not implemented in this workspace.");  endtask
    task automatic tc5();  $display("[SKIP] tc5 is not implemented in this workspace.");  endtask
    task automatic tc6();  $display("[SKIP] tc6 is not implemented in this workspace.");  endtask
    task automatic tc10(); $display("[SKIP] tc10 is not implemented in this workspace."); endtask
    task automatic tc11(); $display("[SKIP] tc11 is not implemented in this workspace."); endtask
    task automatic tc12(); $display("[SKIP] tc12 is not implemented in this workspace."); endtask
    task automatic tc13(); $display("[SKIP] tc13 is not implemented in this workspace."); endtask
    task automatic tc14(); $display("[SKIP] tc14 is not implemented in this workspace."); endtask
    task automatic tc15(); $display("[SKIP] tc15 is not implemented in this workspace."); endtask
    task automatic tc16(); $display("[SKIP] tc16 is not implemented in this workspace."); endtask
    task automatic tc17(); $display("[SKIP] tc17 is not implemented in this workspace."); endtask

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
    `include "uart_subsystem_tb/tc14.sv"
    `include "uart_subsystem_tb/tc15.sv"
    `include "uart_subsystem_tb/tc16.sv"
    `include "uart_subsystem_tb/tc17.sv"

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

        reset_dut();
        configure_uart();

        if (!$value$plusargs("TEST=%s", selected_test) || (selected_test == "") ||
            (selected_test == "default") || (selected_test == "all")) begin
            tc0();
            tc1();
            tc2();
            tc3();
            tc4();
            tc5();
            tc6();
            tc7();
            tc8();
            tc9();
            tc10();
            tc11();
            tc12();
            tc13();
            tc14();
            tc15();
            tc16();
            tc17();
        end else if (selected_test == "tc0")  tc0();
        else if (selected_test == "tc1")  tc1();
        else if (selected_test == "tc2")  tc2();
        else if (selected_test == "tc3")  tc3();
        else if (selected_test == "tc4")  tc4();
        else if (selected_test == "tc5")  tc5();
        else if (selected_test == "tc6")  tc6();
        else if (selected_test == "tc7")  tc7();
        else if (selected_test == "tc8")  tc8();
        else if (selected_test == "tc9")  tc9();
        else if (selected_test == "tc10") tc10();
        else if (selected_test == "tc11") tc11();
        else if (selected_test == "tc12") tc12();
        else if (selected_test == "tc13") tc13();
        else if (selected_test == "tc14") tc14();
        else if (selected_test == "tc15") tc15();
        else if (selected_test == "tc16") tc16();
        else if (selected_test == "tc17") tc17();
        else begin
            total_fail++;
            $display("[FAIL] Unknown TEST plusarg '%s'", selected_test);
        end

        u_uart_if.wait_till_idle();

        $display("------------------------------------------------------------");
        $display("PASS:%0d  FAIL:%0d", total_pass, total_fail);
        if (total_fail == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("------------------------------------------------------------");

        $finish;
    end

endmodule