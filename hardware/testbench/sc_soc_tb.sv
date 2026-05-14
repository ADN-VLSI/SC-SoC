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

  logic [31:0] pc;
  assign pc = sc_soc_tb.u_dut.u_core.core_i.id_stage_i.pc_id_i[31:0];

  // regfile internal probing
  `define REGFILE_SEE(__NAME__,__INDEX__,__TYPE__,__EXT__)                                         \
    logic [31:0] ``__TYPE__``_``__INDEX__``_``__NAME__``;                                          \
    assign ``__TYPE__``_``__INDEX__``_``__NAME__`` =                                               \
    sc_soc_tb.u_dut.u_core.core_i.id_stage_i.register_file_i.``__EXT__``[``__INDEX__``];           \


  `REGFILE_SEE(zero,0,x,mem)
  `REGFILE_SEE(ra,1,x,mem)
  `REGFILE_SEE(sp,2,x,mem)
  `REGFILE_SEE(gp,3,x,mem)
  `REGFILE_SEE(tp,4,x,mem)
  `REGFILE_SEE(t0,5,x,mem)
  `REGFILE_SEE(t1,6,x,mem)
  `REGFILE_SEE(t2,7,x,mem)
  `REGFILE_SEE(s0_fp,8,x,mem)
  `REGFILE_SEE(s1,9,x,mem)
  `REGFILE_SEE(a0,10,x,mem)
  `REGFILE_SEE(a1,11,x,mem)
  `REGFILE_SEE(a2,12,x,mem)
  `REGFILE_SEE(a3,13,x,mem)
  `REGFILE_SEE(a4,14,x,mem)
  `REGFILE_SEE(a5,15,x,mem)
  `REGFILE_SEE(a6,16,x,mem)
  `REGFILE_SEE(a7,17,x,mem)
  `REGFILE_SEE(s2,18,x,mem)
  `REGFILE_SEE(s3,19,x,mem)
  `REGFILE_SEE(s4,20,x,mem)
  `REGFILE_SEE(s5,21,x,mem)
  `REGFILE_SEE(s6,22,x,mem)
  `REGFILE_SEE(s7,23,x,mem)
  `REGFILE_SEE(s8,24,x,mem)
  `REGFILE_SEE(s9,25,x,mem)
  `REGFILE_SEE(s10,26,x,mem)
  `REGFILE_SEE(s11,27,x,mem)
  `REGFILE_SEE(t3,28,x,mem)
  `REGFILE_SEE(t4,29,x,mem)
  `REGFILE_SEE(t5,30,x,mem)
  `REGFILE_SEE(t6,31,x,mem)

  `REGFILE_SEE(ft0,0,f,mem_fp)
  `REGFILE_SEE(ft1,1,f,mem_fp)
  `REGFILE_SEE(ft2,2,f,mem_fp)
  `REGFILE_SEE(ft3,3,f,mem_fp)
  `REGFILE_SEE(ft4,4,f,mem_fp)
  `REGFILE_SEE(ft5,5,f,mem_fp)
  `REGFILE_SEE(ft6,6,f,mem_fp)
  `REGFILE_SEE(ft7,7,f,mem_fp)
  `REGFILE_SEE(fs0,8,f,mem_fp)
  `REGFILE_SEE(fs1,9,f,mem_fp)
  `REGFILE_SEE(fa0,10,f,mem_fp)
  `REGFILE_SEE(fa1,11,f,mem_fp)
  `REGFILE_SEE(fa2,12,f,mem_fp)
  `REGFILE_SEE(fa3,13,f,mem_fp)
  `REGFILE_SEE(fa4,14,f,mem_fp)
  `REGFILE_SEE(fa5,15,f,mem_fp)
  `REGFILE_SEE(fa6,16,f,mem_fp)
  `REGFILE_SEE(fa7,17,f,mem_fp)
  `REGFILE_SEE(fs2,18,f,mem_fp)
  `REGFILE_SEE(fs3,19,f,mem_fp)
  `REGFILE_SEE(fs4,20,f,mem_fp)
  `REGFILE_SEE(fs5,21,f,mem_fp)
  `REGFILE_SEE(fs6,22,f,mem_fp)
  `REGFILE_SEE(fs7,23,f,mem_fp)
  `REGFILE_SEE(fs8,24,f,mem_fp)
  `REGFILE_SEE(fs9,25,f,mem_fp)
  `REGFILE_SEE(fs10,26,f,mem_fp)
  `REGFILE_SEE(fs11,27,f,mem_fp)
  `REGFILE_SEE(t8,28,f,mem_fp)
  `REGFILE_SEE(t9,29,f,mem_fp)
  `REGFILE_SEE(t10,30,f,mem_fp)
  `REGFILE_SEE(t11,31,f,mem_fp)

  `undef REGFILE_SEE

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

  // LOOP-BACK
  assign uart_intf.tx = uart_intf.rx;

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

    fork
      forever begin
        #25us;
        $display("%0t\033[1A\033[0G", $realtime);
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

    do #100ns; while (ram_read(sym["tohost"]) == 0);

    begin
      exit_code = 'h7fff_ffff & ram_read(sym["tohost"]);
      $display("Exit code: 0x%08x (%0d)", exit_code, exit_code);
      if (exit_code == 0) $display("\033[1;32m [PASS] %s\033[0m", test_name);
      else                $display("\033[1;31m [FAIL] %s\033[0m", test_name);
    end

    $finish;
  end

endmodule
