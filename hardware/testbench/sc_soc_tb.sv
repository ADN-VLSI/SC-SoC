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

  `define REGFILE sc_soc_tb.u_dut.u_core.core_i.id_stage_i.register_file_i
  // regfile internal probing
  logic [31:0] x0_zero;
  assign x0_zero = `REGFILE.mem[0];
  logic [31:0] x1_ra;
  assign x1_ra = `REGFILE.mem[1];
  logic [31:0] x2_sp;
  assign x2_sp = `REGFILE.mem[2];
  logic [31:0] x3_gp;
  assign x3_gp = `REGFILE.mem[3];
  logic [31:0] x4_tp;
  assign x4_tp = `REGFILE.mem[4];
  logic [31:0] x5_t0;
  assign x5_t0 = `REGFILE.mem[5];
  logic [31:0] x6_t1;
  assign x6_t1 = `REGFILE.mem[6];
  logic [31:0] x7_t2;
  assign x7_t2 = `REGFILE.mem[7];
  logic [31:0] x8_s0_fp;
  assign x8_s0_fp = `REGFILE.mem[8];
  logic [31:0] x9_s1;
  assign x9_s1 = `REGFILE.mem[9];
  logic [31:0] x10_a0;
  assign x10_a0 = `REGFILE.mem[10];
  logic [31:0] x11_a1;
  assign x11_a1 = `REGFILE.mem[11];
  logic [31:0] x12_a2;
  assign x12_a2 = `REGFILE.mem[12];
  logic [31:0] x13_a3;
  assign x13_a3 = `REGFILE.mem[13];
  logic [31:0] x14_a4;
  assign x14_a4 = `REGFILE.mem[14];
  logic [31:0] x15_a5;
  assign x15_a5 = `REGFILE.mem[15];
  logic [31:0] x16_a6;
  assign x16_a6 = `REGFILE.mem[16];
  logic [31:0] x17_a7;
  assign x17_a7 = `REGFILE.mem[17];
  logic [31:0] x18_s2;
  assign x18_s2 = `REGFILE.mem[18];
  logic [31:0] x19_s3;
  assign x19_s3 = `REGFILE.mem[19];
  logic [31:0] x20_s4;
  assign x20_s4 = `REGFILE.mem[20];
  logic [31:0] x21_s5;
  assign x21_s5 = `REGFILE.mem[21];
  logic [31:0] x22_s6;
  assign x22_s6 = `REGFILE.mem[22];
  logic [31:0] x23_s7;
  assign x23_s7 = `REGFILE.mem[23];
  logic [31:0] x24_s8;
  assign x24_s8 = `REGFILE.mem[24];
  logic [31:0] x25_s9;
  assign x25_s9 = `REGFILE.mem[25];
  logic [31:0] x26_s10;
  assign x26_s10 = `REGFILE.mem[26];
  logic [31:0] x27_s11;
  assign x27_s11 = `REGFILE.mem[27];
  logic [31:0] x28_t3;
  assign x28_t3 = `REGFILE.mem[28];
  logic [31:0] x29_t4;
  assign x29_t4 = `REGFILE.mem[29];
  logic [31:0] x30_t5;
  assign x30_t5 = `REGFILE.mem[30];
  logic [31:0] x31_t6;
  assign x31_t6 = `REGFILE.mem[31];

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

    $display("Exit code: 0x%08x (%0d)", ram_read(sym["tohost"]), ram_read(sym["tohost"]));

    $finish;
  end

endmodule
