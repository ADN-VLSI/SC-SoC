`include "package/sc_soc_pkg.sv"

module sc_soc_tb;
  import sc_soc_pkg::*;
  import uart_pkg::*;

  //////////////////////////////////////////////////////////////////
  // SIGNALS — TODO REMOVE
  //////////////////////////////////////////////////////////////////

  logic                       system_arst_ni;
  logic      [ADDR_WIDTH-1:0] boot_addr_i;
  logic      [DATA_WIDTH-1:0] hart_id_i;

  //////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////

  logic                       glob_arst_ni;
  logic                       apb_arst_ni;
  apb_req_t                   apb_req_i;
  apb_resp_t                  apb_resp_o;
  logic                       uart_tx_o;
  wire                        uart_rx_i;

  // pass/fail counter
  int pass_count = 0;
  int fail_count = 0;

  logic [31:0] rd_data;

  //////////////////////////////////////////////////////////////////
  // CLOCK MACRO
  //////////////////////////////////////////////////////////////////

  `define CLOCK(__NAME__, __PERIOD__)                                  \
      logic ``__NAME__``;                                              \
      bit ``__NAME__``_state = '1;                                     \
      initial begin                                                    \
        forever begin                                                  \
          ``__NAME__ <= ``__NAME__``_state;                            \
          #( __PERIOD__ / 2 );                                         \
          ``__NAME__ <= '0;                                            \
          #( __PERIOD__ / 2 );                                         \
        end                                                            \
      end                                                              \
                                                                       \
      function automatic void ``__NAME__``_enable(input bit en = 1);   \
        ``__NAME__``_state = en;                                       \
      endfunction                                                      \

  `CLOCK(system_clk_i, 10ns)
  `CLOCK(core_clk_i,   10ns)
  `CLOCK(xtal_in,      62.5ns)
  `CLOCK(apb_clk_i,    25ns)
  `undef CLOCK

  //////////////////////////////////////////////////////////////////
  // INTERFACE INSTANTIATION
  //////////////////////////////////////////////////////////////////

  apb_if apb_vif (
      .clk_i   (apb_clk_i),
      .arst_ni (apb_arst_ni)
  );

  //////////////////////////////////////////////////////////////////
  // DUT INSTANTIATION
  //////////////////////////////////////////////////////////////////

  sc_soc u_dut (
      // TODO REMOVE
      .system_arst_ni (system_arst_ni),
      .system_clk_i   (system_clk_i),
      .core_clk_i     (core_clk_i),
      .boot_addr_i    (boot_addr_i),
      .hart_id_i      (hart_id_i),

      // real ports
      .xtal_in        (xtal_in),
      .glob_arst_ni   (glob_arst_ni),
      .apb_arst_ni    (apb_arst_ni),
      .apb_clk_i      (apb_clk_i),
      .apb_req_i      (apb_vif.req),
      .apb_resp_o     (apb_vif.resp),
      .uart_tx_o      (uart_tx_o),
      .uart_rx_i      (uart_rx_i)
  );

  // loopback
  assign uart_rx_i = uart_tx_o;

  //////////////////////////////////////////////////////////////////
  // RESET TASK
  //////////////////////////////////////////////////////////////////

  task automatic apply_reset(input realtime duration = 100ns);
    #(duration);
    system_arst_ni <= '0;
    glob_arst_ni   <= '0;
    apb_arst_ni    <= '0;
    boot_addr_i    <= '0;
    hart_id_i      <= '0;
    apb_vif.req_reset();
    #(duration);
    system_arst_ni <= '1;
    glob_arst_ni   <= '1;
    apb_arst_ni    <= '1;
    #(duration);
  endtask

  //////////////////////////////////////////////////////////////////
  // CHECKER TASKS
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

  //////////////////////////////////////////////////////////////////
  // TEST CASES
  //////////////////////////////////////////////////////////////////

  task tc1_ram_write_read();
      $display("=== TC1: RAM write/read ===");
      write_read_check(32'h2100_0000, 32'h1000_BEEF, "TC1_RAM");
      write_read_check(32'h0000_0010, 32'hCAFE_BABE, "TC1_RAM2");
  endtask

  task tc2_uart_cfg_write_read();
      $display("=== TC2: UART CFG write/read ===");
      write_read_check(
          UART_BASE + UART_CFG_OFFSET,
          32'h0003_405B,
          "TC2_UART_CFG"
      );
  endtask

  task tc3_uart_single_byte_loopback();
      $display("=== TC3: UART single byte loopback ===");
      apb_vif.apb_write(UART_BASE + UART_CFG_OFFSET,  32'h0003_405B, 4'hF);
      apb_vif.apb_write(UART_BASE + UART_CTRL_OFFSET, 32'h0000_0018, 4'hF);
      apb_vif.apb_write(UART_BASE + UART_TXD_OFFSET,  32'h0000_0041, 4'hF);
      apb_vif.wait_tx_empty();
      repeat(5000) @(posedge apb_clk_i);
      apb_vif.wait_rx_data();
      apb_vif.apb_read(UART_BASE + UART_RXD_OFFSET, rd_data);
      check_data(rd_data[7:0], 8'h41, "TC3_UART_LOOPBACK");
  endtask

  task tc4_uart_16byte_loopback();
      $display("=== TC4: 16 byte TX/RX loopback ===");
      apb_vif.apb_write(UART_BASE + UART_CFG_OFFSET,  32'h0003_405B, 4'hF);
      apb_vif.apb_write(UART_BASE + UART_CTRL_OFFSET, 32'h0000_0018, 4'hF);

      for (int i = 0; i < 16; i++) begin
          apb_vif.apb_write(UART_BASE + UART_TXD_OFFSET, i, 4'hF);
      end

      apb_vif.wait_tx_empty();
      repeat(5000) @(posedge apb_clk_i);

      for (int i = 0; i < 16; i++) begin
          apb_vif.wait_rx_data();
          apb_vif.apb_read(UART_BASE + UART_RXD_OFFSET, rd_data);
          check_data(rd_data[7:0], i[7:0], $sformatf("TC4_RX_BYTE_%0d", i));
      end
  endtask

  task tc5_hex_load_verify();
      int byte_mem  [int];
      int word_data [int];
      int word_addr;
      logic [3:0] byte_pos;

      $display("=== TC5: Load hex file to RAM via APB ===");

      // Step 1: hex file load
      $readmemh("test.hex", byte_mem);
      $display("TC5: Hex file loaded");

      // Step 2: byte to word convert
      foreach (byte_mem[addr]) begin
          word_addr = addr & 'hFFFFFFFC;
          byte_pos  = addr & 'h3;
          word_data[word_addr] |= (byte_mem[addr]) << (byte_pos * 8);
      end

      // Step 3: APB write RAM
      foreach (word_data[waddr]) begin
          apb_vif.apb_write(waddr, word_data[waddr], 4'hF);
      end
      $display("TC5: Written to RAM");

      // Step 4: APB read verify
      foreach (word_data[waddr]) begin
          apb_vif.apb_read(waddr, rd_data);
          check_data(rd_data, word_data[waddr], $sformatf("TC5_WORD_0x%08X", waddr));
      end

  endtask

  //////////////////////////////////////////////////////////////////
  // TEST
  //////////////////////////////////////////////////////////////////

  initial begin
    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();
    //core_clk_i_enable();
    apply_reset();
    repeat(10) @(posedge apb_clk_i);

    tc1_ram_write_read();
    tc2_uart_cfg_write_read();
    tc3_uart_single_byte_loopback();
    tc4_uart_16byte_loopback();
    tc5_hex_load_verify();
    repeat(10) @(posedge apb_clk_i);
   

    // ── Summary ──
    $display("==============================");
    $display("TOTAL PASS : %0d", pass_count);
    $display("TOTAL FAIL : %0d", fail_count);
    $display("==============================");

    $finish;
  end

  initial begin
    $dumpfile("sc_soc_tb.vcd");
    $dumpvars(0, sc_soc_tb);
  end

endmodule
