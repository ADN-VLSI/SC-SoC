module sc_soc_tb;

  import sc_soc_pkg::*;

  //---------------------------REMOVE---------------------------
  logic                       system_arst_ni;
  logic      [ADDR_WIDTH-1:0] boot_addr_i;
  logic      [DATA_WIDTH-1:0] hart_id_i;
  //---------------------------REMOVE---------------------------

  logic                       glob_arst_ni;

  logic                       apb_arst_ni;
  apb_req_t                   apb_req_i;
  apb_resp_t                  apb_resp_o;

  logic                       uart_tx_o;
  logic                       uart_rx_i;

  `define CLOCK(__NAME__, __PERIOD__)                                 \
      logic ``__NAME__``;                                             \
      bit ``__NAME__``_state = '1;                                    \
      initial begin                                                   \
        forever begin                                                 \
          ``__NAME__ <= ``__NAME__``_state;                           \
          #( __PERIOD__ / 2 );                                        \
          ``__NAME__ <= '0;                                           \
          #( __PERIOD__ / 2 );                                        \
        end                                                           \
      end                                                             \
                                                                      \
      function automatic void ``__NAME__``_enable(input bit en = 1);  \
        ``__NAME__``_state = en;                                      \
      endfunction                                                     \


  `CLOCK(system_clk_i, 10ns)
  `CLOCK(core_clk_i, 10ns)
  `CLOCK(xtal_in, 62.5ns)
  `CLOCK(apb_clk_i, 25ns)

  `undef CLOCK

  sc_soc u_dut (
    .*,
    .apb_req_i  (u_apb_if.req),
    .apb_resp_o (u_apb_if.resp)
    );

  // Instance of the APB interface for driving and monitoring
  apb_if u_apb_if (
      .clk_i(apb_clk_i),
      .arst_ni(apb_arst_ni)
  );

  task automatic apply_reset(input realtime duration = 100ns);
    #(duration);
    system_arst_ni <= '0;
    glob_arst_ni   <= '0;
    apb_arst_ni    <= '0;
    boot_addr_i    <= '0;
    hart_id_i      <= '0;
    apb_req_i      <= '0;
    uart_rx_i      <= '0;
    #(duration);
    system_arst_ni <= '1;
    glob_arst_ni   <= '1;
    apb_arst_ni    <= '1;
    #(duration);
  endtask

  initial begin
    logic [31:0] rdata;
    logic        slverr;

    apply_reset();

    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();

    // UART — enable TX/RX
        u_apb_if.write(UART_BASE + UART_CTRL, 32'h0000_0018, 4'b1111, slverr);
        assert(slverr == 0) 
        else $error("UART CTRL write failed");

    // UART — write byte 'A' to TXD
        u_apb_if.write(UART_BASE + UART_TXD, 32'h0000_0041, 4'b1111, slverr);
        assert(slverr == 0) 
        else $error("UART TXD write failed");
    // UART — read STAT
        u_apb_if.read(UART_BASE + UART_STAT, rdata, slverr);
        $display("UART STAT = 0x%08X", rdata);

    // RAM — write then read back
        u_apb_if.write(32'h2000_0010, 32'hDEAD_BEEF, 4'b1111, slverr);
        u_apb_if.read(32'h2000_0010, rdata, slverr);
        assert(rdata == 32'hDEAD_BEEF) 
        else $fatal(1, "RAM mismatch: got 0x%08X", rdata);
        $display("RAM readback = 0x%08X", rdata);

    #1000;

    $finish;
  end

endmodule
