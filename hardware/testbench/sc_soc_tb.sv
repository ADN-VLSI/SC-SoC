module sc_soc_tb;

  import sc_soc_pkg::*;
  import uart_pkg::*;

  //---------------------------REMOVE---------------------------
  logic                       system_arst_ni;
  logic      [ADDR_WIDTH-1:0] boot_addr_i;
  logic      [DATA_WIDTH-1:0] hart_id_i;
  //---------------------------REMOVE---------------------------

  logic                       glob_arst_ni;
  logic                       apb_arst_ni;

  logic                       uart_tx_o;
  logic                       uart_rx_i;

  // -------------------------------------------------------------------------
  // Clock generation macro
  // Generates:
  //   - A toggling clock signal <__NAME__>
  //   - A gate bit   <__NAME__>_state  (1 = running, 0 = held low)
  //   - A task       <__NAME__>_enable(bit en) to start/stop the clock
  // -------------------------------------------------------------------------
  `define CLOCK(__NAME__, __PERIOD__)                                  \
      logic ``__NAME__``;                                              \
      bit   ``__NAME__``_state = '0;                                   \
      initial begin                                                    \
        ``__NAME__ = '0;                                               \
        forever begin                                                  \
          #( __PERIOD__ / 2 );                                         \
          if (``__NAME__``_state) ``__NAME__ = ~``__NAME__;            \
          else                    ``__NAME__ = '0;                     \
        end                                                            \
      end                                                              \
                                                                       \
      function automatic void ``__NAME__``_enable(input bit en = 1);   \
        ``__NAME__``_state = en;                                        \
      endfunction

  `CLOCK(system_clk_i, 10ns)    // 100 MHz
  `CLOCK(core_clk_i,   10ns)    // 100 MHz  (reserved — not yet wired inside DUT)
  `CLOCK(xtal_in,      62.5ns)  //  16 MHz  (feeds SoC PLL)
  `CLOCK(apb_clk_i,    25ns)    //  40 MHz

  `undef CLOCK

  // -------------------------------------------------------------------------
  // APB interface instance — owns all req/resp signals for APB transactions
  // -------------------------------------------------------------------------
  apb_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_apb_if (
    .clk_i   (apb_clk_i),
    .arst_ni (apb_arst_ni)
  );

  // -------------------------------------------------------------------------
  // DUT instantiation
  // Note:
  //   apb_req_i / apb_resp_o are driven exclusively through u_apb_if.
  //   The bare apb_req_i / apb_resp_o signals are removed to avoid
  //   multi-driver conflicts from the wildcard connect (.*).
  // -------------------------------------------------------------------------
  sc_soc u_dut (
    // REMOVE ports
    .system_arst_ni (system_arst_ni),
    .system_clk_i   (system_clk_i),
    .core_clk_i     (core_clk_i),
    .boot_addr_i    (boot_addr_i),
    .hart_id_i      (hart_id_i),

    // Clock and Reset
    .xtal_in        (xtal_in),
    .glob_arst_ni   (glob_arst_ni),

    // APB — driven through the interface
    .apb_arst_ni    (apb_arst_ni),
    .apb_clk_i      (apb_clk_i),
    .apb_req_i      (u_apb_if.req),
    .apb_resp_o     (u_apb_if.resp),

    // UART
    .uart_tx_o      (uart_tx_o),
    .uart_rx_i      (uart_rx_i)
  );

  // -------------------------------------------------------------------------
  // Reset task
  //   - Holds all resets asserted for <duration>, deasserts, then waits again
  //   - UART idle line is logic-1 (mark state)
  //   - APB bus is driven idle through the interface
  // -------------------------------------------------------------------------
  task automatic apply_reset(input realtime duration = 100ns);
    // Default / safe values before reset
    system_arst_ni        <= '0;
    glob_arst_ni          <= '0;
    apb_arst_ni           <= '0;
    boot_addr_i           <= '0;
    hart_id_i             <= '0;
    uart_rx_i             <= '1;   // UART idle = high (mark state)
    u_apb_if.req          <= '0;

    #(duration);

    // Deassert resets
    system_arst_ni <= '1;
    glob_arst_ni   <= '1;
    apb_arst_ni    <= '1;

    #(duration);
  endtask

  // -------------------------------------------------------------------------
  // Main test sequence
  // -------------------------------------------------------------------------
  initial begin
    logic [DATA_WIDTH-1:0] rdata;
    logic                  slverr;

    // -------------------------------------------------------------------
    // 1. Backdoor RAM pre-load via $readmemh
    //
    //    test.hex contains an @20000000 address tag which $readmemh would
    //    interpret as a word index — completely out of range for the RAM
    //    array depth.  strip_hex_tag.py removes the tag and writes a clean
    //    file (test_clean.hex) starting at word index 0, which maps
    //    directly onto mem_array[0..N-1] inside dual_port_mem.
    //
    //    dual_port_mem hierarchy:
    //      u_dut.u_ram          -> axi4l_mem instance
    //      u_dut.u_ram.mem_inst -> dual_port_mem instance
    //      .mem_array           -> the actual storage array
    // -------------------------------------------------------------------
    $system("python3 strip_hex_tag.py test.hex test_clean.hex");
    $readmemh("test_clean.hex", u_dut.u_ram.mem_inst.mem_array);

    // -------------------------------------------------------------------
    // 2. Start clocks, then apply reset
    // -------------------------------------------------------------------
    system_clk_i_enable();
    core_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();

    apply_reset(100ns);

    // -------------------------------------------------------------------
    // 3. Verify backdoor-loaded RAM contents via APB frontdoor read
    //    The hex file starts at @20000000, so word 0 = 0x03020100,
    //    word 1 = 0x07060504, etc. (little-endian packing).
    // -------------------------------------------------------------------
    $display("[TB] Verifying backdoor RAM load ...");
    u_apb_if.apb_read(32'h2000_0000, rdata, slverr);
    assert(slverr == 0 && rdata == 32'h0302_0100)
      else $error("RAM[0] mismatch: got 0x%08X, expected 0x03020100", rdata);
    $display("[TB] RAM[0x2000_0000] = 0x%08X (expected 0x03020100)", rdata);

    u_apb_if.apb_read(32'h2000_0004, rdata, slverr);
    assert(slverr == 0 && rdata == 32'h0706_0504)
      else $error("RAM[4] mismatch: got 0x%08X, expected 0x07060504", rdata);
    $display("[TB] RAM[0x2000_0004] = 0x%08X (expected 0x07060504)", rdata);

    // -------------------------------------------------------------------
    // 4. UART — enable TX and RX via CTRL register
    // -------------------------------------------------------------------
    $display("[TB] Configuring UART ...");
    u_apb_if.apb_write(UART_BASE + UART_CTRL_OFFSET, 32'h0000_0018, 4'b1111, slverr);
    assert(slverr == 0) else $error("UART CTRL write failed");

    // -------------------------------------------------------------------
    // 5. UART — transmit byte 'A' (0x41)
    // -------------------------------------------------------------------
    u_apb_if.apb_write(UART_BASE + UART_TXD_OFFSET, 32'h0000_0041, 4'b1111, slverr);
    assert(slverr == 0) else $error("UART TXD write failed");

    // -------------------------------------------------------------------
    // 6. UART — read and display STATUS register
    // -------------------------------------------------------------------
    u_apb_if.apb_read(UART_BASE + UART_STAT_OFFSET, rdata, slverr);
    $display("[TB] UART STAT = 0x%08X", rdata);

    // -------------------------------------------------------------------
    // 7. RAM — APB frontdoor write then read-back
    // -------------------------------------------------------------------
    $display("[TB] Testing APB frontdoor RAM write/read ...");
    u_apb_if.apb_write(32'h2000_0010, 32'hDEAD_BEEF, 4'b1111, slverr);
    assert(slverr == 0) else $error("RAM APB write failed");

    u_apb_if.apb_read(32'h2000_0010, rdata, slverr);
    assert(slverr == 0 && rdata == 32'hDEAD_BEEF)
      else $fatal(1, "RAM mismatch: got 0x%08X, expected 0xDEADBEEF", rdata);
    $display("[TB] RAM[0x2000_0010] = 0x%08X  ✓", rdata);

    #1000ns;

    $display("[TB] All checks passed.");
    $finish;
  end

endmodule