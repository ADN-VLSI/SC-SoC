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

  sc_soc u_dut (.*);

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


    apply_reset();

    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();

    #1000;

    $finish;
  end

endmodule
