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
  apb_req_t                   apb_req_i;
  apb_resp_t                  apb_resp_o;
  logic                       uart_tx_o;
  wire                        uart_rx_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK MACRO
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `define CLOCK(__NAME__, __PERIOD__)                                  \
      logic ``__NAME__``;                                              \
      bit ``__NAME__``_state = '0;                                     \
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

  int     pass_count = 0;
  int     fail_count = 0;

  longint sym            [string];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  apb_if apb_intf (
      .clk_i  (apb_clk_i),
      .arst_ni(apb_arst_ni)
  );

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
      .uart_tx_o   (uart_tx_o),
      .uart_rx_i   (uart_rx_i)
  );

  // loopback
  assign uart_rx_i = uart_tx_o;

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
    u_dut.u_ram.mem_inst.mem_array[addr>>2] = data;
  endfunction

  function automatic int ram_read(int addr);
    return u_dut.u_ram.mem_inst.mem_array[addr>>2];
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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TPROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    $timeformat(-6, 0, "us");
    $dumpfile("sc_soc_tb.vcd");
    $dumpvars(0, sc_soc_tb);

    if (!$value$plusargs("TEST=%s", test_name)) begin
      $fatal(1, " [FATAL] No test specified. Use +TEST=<test_name>");
    end

    if (!$value$plusargs("DEBUG=%d", debug)) begin
      $fatal(1, " [FATAL] No debug specified. Use +DEBUG=<debug_value>");
    end

    if (!$value$plusargs("BDL=%d", back_door_load)) begin
      $fatal(1, " [FATAL] No back door load specified. Use +BDL=<back_door_load_value>");
    end

    load_symbols("prog.sym");

    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();
    apply_reset();
    boot_addr_i <= sym["_start"];
    repeat (10) @(posedge apb_clk_i);

    load_program("prog.hex");

    core_clk_i_enable();

    do #100ns; while (ram_read(sym["tohost"]) == 0);

    $display("Exit code: 0x%08x", ram_read(sym["tohost"]));

    $finish;
  end

endmodule
