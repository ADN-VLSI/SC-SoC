module apb_mem_uart_tb;

    import sc_soc_pkg::*;

    //////////////////////////////////////////////////////////////////
    // SIGNALS
    //////////////////////////////////////////////////////////////////

    logic apb_clk;
    logic apb_arst_n;
    logic sys_clk;
    logic sys_arst_n;
    logic uart_loop;

    logic [31:0] rd_data;

    // pass/fail counter
    int pass_count = 0;
    int fail_count = 0;

    //////////////////////////////////////////////////////////////////
    // CLOCK GENERATION
    //////////////////////////////////////////////////////////////////

    initial apb_clk = 0;
    always #10 apb_clk = ~apb_clk;

    initial sys_clk = 0;
    always #10 sys_clk = ~sys_clk;

    //////////////////////////////////////////////////////////////////
    // INTERFACE INSTANTIATION
    //////////////////////////////////////////////////////////////////

    apb_if apb_vif (
        .clk_i   (apb_clk),
        .arst_ni (apb_arst_n)
    );

    //////////////////////////////////////////////////////////////////
    // DUT INSTANTIATION
    //////////////////////////////////////////////////////////////////

    sc_soc dut (
        .system_arst_ni (sys_arst_n),
        .system_clk_i   (sys_clk),
        .core_clk_i     (sys_clk),
        .boot_addr_i    ('0),
        .hart_id_i      ('0),
        .xtal_in        ('0),
        .glob_arst_ni   (1'b1),
        .apb_arst_ni    (apb_arst_n),
        .apb_clk_i      (apb_clk),
        .apb_req_i      (apb_vif.req),
        .apb_resp_o     (apb_vif.resp),
        .uart_tx_o      (uart_loop),
        .uart_rx_i      (uart_loop)
    );

    //////////////////////////////////////////////////////////////////
    // TASKS
    //////////////////////////////////////////////////////////////////

    task check_data(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       test_name
    );
        if (actual == expected) begin
            $display("PASS: %s | expected=0x%08X got=0x%08X",
                      test_name, expected, actual);
            pass_count++;
        end else begin
            $error("FAIL: %s | expected=0x%08X got=0x%08X",
                    test_name, expected, actual);
            fail_count++;
        end
    endtask

    task write_read_check(
        input logic [31:0] addr,
        input logic [31:0] data,
        input string       test_name
    );
        apb_vif.apb_write(addr, data, 4'hF);
        apb_vif.apb_read(addr, rd_data);
        check_data(rd_data, data, test_name);
    endtask

    task do_reset();
        apb_arst_n <= 0;
        sys_arst_n <= 0;
        apb_vif.req_reset();
        #205;
        apb_arst_n <= 1;
        sys_arst_n <= 1;
        repeat(5) @(posedge apb_clk);
    endtask

    task tc1_ram_write_read();
        $display("=== TC1: RAM write/read ===");
        write_read_check(32'h2100_0000, 32'h1000_BEEF, "TC1_RAM");  // Access RAM 0x2000_0000-0x6000_0000
        write_read_check(32'h0000_0010, 32'hCAFE_BABE, "TC1_RAM2"); // Access RAM without dedicated Memory map. 
    endtask

    task tc2_uart_cfg_write_read();
        $display("=== TC2: UART CFG write/read ===");
        write_read_check(
            UART_BASE + 32'h04,
            32'h0003_405B,
            "TC2_UART_CFG"
        );
    endtask

    task tc3_uart_single_byte_loopback();
        $display("=== TC3: UART single byte loopback ===");
        apb_vif.apb_write(UART_BASE + 32'h04, 32'h0003_405B, 4'hF);
        apb_vif.apb_write(UART_BASE + 32'h00, 32'h0000_0018, 4'hF);
        apb_vif.apb_write(UART_BASE + 32'h1C, 32'h0000_0041, 4'hF);
        apb_vif.wait_tx_empty();
        repeat(5000) @(posedge apb_clk);
        apb_vif.wait_rx_data();
        apb_vif.apb_read(UART_BASE + 32'h2C, rd_data);
        check_data(rd_data[7:0], 8'h41, "TC3_UART_LOOPBACK");
    endtask

    task tc4_uart_16byte_loopback();
        $display("=== TC4: 16 byte TX/RX loopback ===");
        apb_vif.apb_write(UART_BASE + 32'h04, 32'h0003_405B, 4'hF);
        apb_vif.apb_write(UART_BASE + 32'h00, 32'h0000_0018, 4'hF);


        for (int i = 0; i < 16; i++) begin
            apb_vif.apb_write(UART_BASE + 32'h1C, i, 4'hF);
        end

        // TX complete wait
        apb_vif.wait_tx_empty();
        repeat(5000) @(posedge apb_clk);


        for (int i = 0; i < 16; i++) begin
            apb_vif.wait_rx_data();
            apb_vif.apb_read(UART_BASE + 32'h2C, rd_data);
            check_data(rd_data[7:0], i[7:0], $sformatf("TC4_RX_BYTE_%0d", i));
        end
    endtask

    //////////////////////////////////////////////////////////////////
    // TEST
    //////////////////////////////////////////////////////////////////

    initial begin

        do_reset();

        tc1_ram_write_read();
        tc2_uart_cfg_write_read();
        tc3_uart_single_byte_loopback();
        tc4_uart_16byte_loopback();

        repeat(10) @(posedge apb_clk);

        // ── Summary ──
        $display("==============================");
        $display("TOTAL PASS : %0d", pass_count);
        $display("TOTAL FAIL : %0d", fail_count);
        $display("==============================");

        $finish;
    end

    initial begin
        $dumpfile("apb_mem_uart_tb.vcd");
        $dumpvars(0, apb_mem_uart_tb);
    end

endmodule