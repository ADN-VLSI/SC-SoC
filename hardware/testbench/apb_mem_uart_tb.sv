module apb_mem_uart_tb;

    import sc_soc_pkg::*;
    import uart_pkg::*;

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
        apb_vif.apb_write(UART_BASE + UART_CFG_OFFSET, 32'h0003_405B, 4'hF);
        apb_vif.apb_write(UART_BASE + UART_CTRL_OFFSET , 32'h0000_0018, 4'hF);
        apb_vif.apb_write(UART_BASE + UART_TXD_OFFSET, 32'h0000_0041, 4'hF);
        apb_vif.wait_tx_empty();
        repeat(5000) @(posedge apb_clk);
        apb_vif.wait_rx_data();
        apb_vif.apb_read(UART_BASE + UART_RXD_OFFSET, rd_data);
        check_data(rd_data[7:0], 8'h41, "TC3_UART_LOOPBACK");
    endtask

    task tc4_uart_16byte_loopback();
        $display("=== TC4: 16 byte TX/RX loopback ===");
        apb_vif.apb_write(UART_BASE + UART_CFG_OFFSET, 32'h0003_405B, 4'hF);
        apb_vif.apb_write(UART_BASE + UART_CTRL_OFFSET, 32'h0000_0018, 4'hF);


        for (int i = 0; i < 16; i++) begin
            apb_vif.apb_write(UART_BASE + UART_TXD_OFFSET, i, 4'hF);
        end

        // TX complete wait
        apb_vif.wait_tx_empty();
        repeat(5000) @(posedge apb_clk);


        for (int i = 0; i < 16; i++) begin
            apb_vif.wait_rx_data();
            apb_vif.apb_read(UART_BASE + UART_RXD_OFFSET, rd_data);
            check_data(rd_data[7:0], i[7:0], $sformatf("TC4_RX_BYTE_%0d", i));
        end
    endtask

    task tc5_hex_load_verify();
        int byte_mem [int];   // associative array: key=address, value=byte
        int word_data [int];  // associative array: key=word_addr, value=word
        int word_addr;
        logic [3:0] byte_pos;

        $display("=== TC5: Load hex file to RAM via APB ===");

        // Step 1: hex file load
        $readmemh("test.hex", byte_mem);
        $display("TC5: Hex file loaded");

        // Step 2: byte → word convert
        foreach (byte_mem[addr]) begin
            word_addr = addr & 'hFFFFFFFC;  // aligned word address
            byte_pos  = addr & 'h3;         // byte position

            // word এ byte বসাও
            word_data[word_addr] |= (byte_mem[addr] & 'hFF) << (byte_pos * 8);
        end

        // Step 3: APB write → RAM
        foreach (word_data[waddr]) begin
            apb_vif.apb_write(waddr, word_data[waddr], 4'hF);
        end
        $display("TC5: Written to RAM");

        // Step 4: APB read → verify
        foreach (word_data[waddr]) begin
            apb_vif.apb_read(waddr, rd_data);
            check_data(rd_data, word_data[waddr], $sformatf("TC5_WORD_0x%08X", waddr));
        end

    endtask
    //////////////////////////////////////////////////////////////////
    // TEST
    //////////////////////////////////////////////////////////////////

    initial begin

        do_reset();

        tc1_ram_write_read();
        tc2_uart_cfg_write_read();
        tc5_hex_load_verify();
        //tc3_uart_single_byte_loopback();
        //tc4_uart_16byte_loopback();

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