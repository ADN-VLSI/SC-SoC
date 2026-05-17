`include "package/sc_soc_pkg.sv"

module sc_soc_tb;
  import sc_soc_pkg::*;
  import uart_pkg::*;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS — TODO REMOVE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                       system_arst_ni;
  logic      [ADDR_WIDTH-1:0] boot_addr_i;
  logic      [DATA_WIDTH-1:0] hart_id_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic                       glob_arst_ni;
  logic                       apb_arst_ni;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK MACRO
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `define CLOCK(__NAME__, __PERIOD__)                                                              \
      logic ``__NAME__``;                                                                          \
      bit ``__NAME__``_state = '0;                                                                 \
      initial begin                                                                                \
        forever begin                                                                              \
          ``__NAME__ <= ``__NAME__``_state;                                                        \
          #( __PERIOD__ / 2 );                                                                     \
          ``__NAME__ <= '0;                                                                        \
          #( __PERIOD__ / 2 );                                                                     \
        end                                                                                        \
      end                                                                                          \
                                                                                                   \
      function automatic void ``__NAME__``_enable(input bit en = 1);                               \
        ``__NAME__``_state = en;                                                                   \
      endfunction                                                                                  \

  `CLOCK(system_clk_i, 10ns)
  `CLOCK(core_clk_i, 10ns)
  `CLOCK(xtal_in, 62.5ns)
  `CLOCK(apb_clk_i, 25ns)
  `undef CLOCK

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  string  test_name;
  bit     debug;
  bit     back_door_load;

  int exit_code;

  longint sym            [string];

  `include "sc_soc_tb/reg_wave_mon.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  apb_if apb_intf (
      .clk_i  (apb_clk_i),
      .arst_ni(apb_arst_ni)
  );

  uart_if uart_intf ();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  sc_soc u_dut (
      // TODO REMOVE
      .system_arst_ni(system_arst_ni),
      .system_clk_i  (system_clk_i),
      .core_clk_i    (core_clk_i),
      .boot_addr_i   (boot_addr_i),
      .hart_id_i     (hart_id_i),

      // real ports
      .xtal_in     (xtal_in),
      .glob_arst_ni(glob_arst_ni),
      .apb_arst_ni (apb_arst_ni),
      .apb_clk_i   (apb_clk_i),
      .apb_req_i   (apb_intf.req),
      .apb_resp_o  (apb_intf.resp),
      .uart_tx_o   (uart_intf.rx),
      .uart_rx_i   (uart_intf.tx)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // RESET
  task automatic apply_reset(input realtime duration = 100ns);
    #(duration);
    system_arst_ni <= '0;
    glob_arst_ni   <= '0;
    apb_arst_ni    <= '0;
    boot_addr_i    <= '0;
    hart_id_i      <= '0;
    apb_intf.req_reset();
    #(duration);
    system_arst_ni <= '1;
    glob_arst_ni   <= '1;
    apb_arst_ni    <= '1;
    #(duration);
  endtask

  function automatic void ram_write(int addr, int data);
    bit [3:0][7:0] byte_data;
    int aligned_addr;
    aligned_addr = addr & 'hffff_fffc;
    byte_data = data;
    foreach (byte_data[i]) u_dut.u_ram.mem[0][aligned_addr+i] = byte_data[i];
  endfunction

  function automatic int ram_read(int addr);
    bit [3:0][7:0] byte_data;
    int aligned_addr;
    aligned_addr = addr & 'hffff_fffc;
    foreach (byte_data[i]) byte_data[i] = u_dut.u_ram.mem[0][aligned_addr+i];
    return byte_data;
  endfunction

  // LOAD SYMBOL FILE
  function automatic void load_symbols(string filename);
    int file, r;
    string line;
    string key;
    int value;

    file = $fopen(filename, "r");
    if (file == 0) begin
      $fatal(1, " [FATAL] Could not open file %s", filename);
    end

    while (!$feof(
        file
    )) begin
      r = $fgets(line, file);
      if (r != 0) begin
        r = $sscanf(line, "%h %*s %s", value, key);
        if (r == 2) begin
          sym[key] = value;
        end
      end
    end
    if (debug) begin
      $display(" [DEBUG] Loaded symbols:");
      foreach (sym[key]) begin
        $display(" [DEBUG]   0x%08x %s", sym[key], key);
      end
    end
    $fclose(file);
  endfunction

  // LOAD PROGRAM
  task automatic load_program(string filename);
    automatic bit [7:0]      bmem[int];
    automatic bit [3:0][7:0] wmem[int];

    bmem.delete();
    wmem.delete();
    $readmemh(filename, bmem);
    foreach (bmem[i]) begin
      wmem[i&'hffff_fffc][i&'h0000_0003] = bmem[i];
    end

    foreach (wmem[i]) begin
      if (debug) $display(" [DEBUG] RAM[0x%08x] <= 0x%08x", i, wmem[i]);
      if (back_door_load) begin
        ram_write(i, wmem[i]);
      end else begin
        apb_intf.apb_write(i, wmem[i]);
      end
    end
  endtask


  `define UART_CFG(__BITS__) u_dut.u_uart.u_axi4l_regif.uart_cfg_o[``__BITS__``]

  task automatic start_uart_monitoring();
    string dut_tx;
    string dut_rx;
    fork
      forever begin
        bit [7:0] data;
        bit       parity;
        int       clk_div;
        int       prescalar;
        @(negedge uart_intf.rx);
        clk_div = `UART_CFG(11:0);
        prescalar = `UART_CFG(15:12);
        if (clk_div == 0) clk_div = 1;
        if (prescalar == 0) prescalar = 1;
        uart_intf.recv_rx(
          data,
          parity,
          ((100000000 / prescalar) / clk_div), // BAUD RATE
          `UART_CFG(18), // PARITY ENABLE
          `UART_CFG(19), // PARITY TYPE
          `UART_CFG(20), // STOP BITS
          (5 + `UART_CFG(17:16)) // DATA BITS
        );
        if (data == "\n") begin
          $display("\033[7;35m > \033[0m\033[7;38m%s\033[0m", dut_tx);
          dut_tx = "";
        end else begin
          $sformat(dut_tx, "%s%s", dut_tx, data);
        end
      end
      forever begin
        bit [7:0] data;
        bit       parity;
        @(negedge uart_intf.tx);
        uart_intf.recv_rx(data, parity);
        if (data == "\n") begin
          $display("\033[7;36m < \033[0m\033[7;38m%s\033[0m", dut_rx);
          dut_rx = "";
        end else begin
          $sformat(dut_rx, "%s%s", dut_rx, data);
        end
      end
    join_none
  endtask

  `undef UART_CFG

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TPROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    
    $timeformat(-6, 0, "us");

    if (!$value$plusargs("TEST=%s", test_name)) begin
      $fatal(1, " [FATAL] No test specified. Use +TEST=<test_name>");
    end

    if (!$value$plusargs("DEBUG=%d", debug)) begin
      $fatal(1, " [FATAL] No debug specified. Use +DEBUG=<debug_value>");
    end

    if (!$value$plusargs("BDL=%d", back_door_load)) begin
      $fatal(1, " [FATAL] No back door load specified. Use +BDL=<back_door_load_value>");
    end

    if (debug != 0) begin
      $dumpfile("sc_soc_tb.vcd");
      $dumpvars(0, sc_soc_tb);
    end

    fork
      forever begin
        #25us;
        $display("@%0t\033[1A\033[0G", $realtime);
      end
    join_none

    load_symbols("prog.sym");

    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();
    apply_reset();

    start_uart_monitoring();

    boot_addr_i <= sym["_start"];
    repeat (10) @(posedge apb_clk_i);

    load_program("prog.hex");

    core_clk_i_enable();

    `include "sc_soc_tb/runtest.sv"

    `include "sc_soc_tb/check_n_exit.sv"

  end

endmodule
