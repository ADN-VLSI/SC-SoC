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

  int     exit_code;

  longint sym [string];

  // -----------------------------------------------------------------------
  // UART test constants
  //
  // Baud rate: REG_UART_CFG = 0x00031064 → 1 MHz
  // Frame: 8N1 → 10 bits per character (1 start + 8 data + 1 stop)
  // Message: "Hello World...!\n" → 16 characters
  //
  // Bit period  = 1s / 1_000_000       = 1000 ns
  // Frame time  = 10 * 1000 ns         = 10_000 ns  = 10 µs
  // 16 chars    = 16 * 10_000 ns       = 160_000 ns = 160 µs  (wire time only)
  //
  // Timeout must be >> 160 µs to account for:
  //   - busy-wait TX grant polling
  //   - busy-wait TX FIFO empty polling
  //   - busy-wait RX grant polling
  //   - busy-wait RX FIFO fill polling
  //   - 16 RX register reads + comparisons
  // 5 ms is conservative and safe.
  // -----------------------------------------------------------------------
  localparam int    UART_BAUD_RATE  = 1_000_000;
  localparam int    UART_BITS       = 10;          // 8N1: start + 8 data + stop
  localparam int    UART_MSG_LEN    = 16;
  localparam string UART_EXPECTED   = "Hello World...!\n";
  // bit period in ns as an integer, used for #delay arithmetic
  localparam int    UART_BIT_NS     = 1_000_000_000 / UART_BAUD_RATE; // 1000 ns

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // REGFILE PROBING MACRO
  //////////////////////////////////////////////////////////////////////////////////////////////////

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

  // uart_if is NOT instantiated.
  // Reason: uart_if.recv_tx() uses an internal BAUD_RATE parameter that
  // cannot be changed to 1 MHz per project constraints. Sampling a 1 MHz
  // UART frame at 115200 baud produces wrong bit windows and corrupt data.
  // The loopback wire (uart_rx_i = uart_tx_o) already provides the
  // physical check path that uart.c uses. The testbench monitor below
  // samples the wire directly using #delay arithmetic instead.

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

  // Loopback: TX feeds directly back into RX.
  // uart.c transmits then reads back via the same path.
  assign uart_rx_i = uart_tx_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

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

  function automatic void load_symbols(string filename);
    int file, r;
    string line;
    string key;
    int value;

    file = $fopen(filename, "r");
    if (file == 0) begin
      $fatal(1, " [FATAL] Could not open file %s", filename);
    end

    while (!$feof(file)) begin
      r = $fgets(line, file);
      if (r != 0) begin
        r = $sscanf(line, "%h %*s %s", value, key);
        if (r == 2) sym[key] = value;
      end
    end

    if (debug) begin
      $display(" [DEBUG] Loaded symbols:");
      foreach (sym[key])
        $display(" [DEBUG]   0x%08x %s", sym[key], key);
    end
    $fclose(file);
  endfunction

  task automatic load_program(string filename);
    automatic bit [7:0]      bmem[int];
    automatic bit [3:0][7:0] wmem[int];

    bmem.delete();
    wmem.delete();
    $readmemh(filename, bmem);
    foreach (bmem[i])
      wmem[i&'hffff_fffc][i&'h0000_0003] = bmem[i];

    foreach (wmem[i]) begin
      if (debug) $display(" [DEBUG] RAM[0x%08x] <= 0x%08x", i, wmem[i]);
      if (back_door_load) ram_write(i, wmem[i]);
      else                apb_intf.apb_write(i, wmem[i]);
    end
  endtask

  // -----------------------------------------------------------------------
  // UART RAW WIRE MONITOR
  //
  // Samples uart_tx_o directly using #delay arithmetic calibrated to
  // UART_BIT_NS (1000 ns at 1 MHz baud). No uart_if needed.
  //
  // Protocol: 8N1
  //   - idle line is high
  //   - start bit: line goes low for 1 bit period
  //   - 8 data bits LSB first, each 1 bit period wide
  //   - stop bit: line high for 1 bit period
  //
  // Sampling point: centre of each bit window (half bit period after edge).
  //
  // For each of the UART_MSG_LEN expected characters:
  //   1. Wait for falling edge (start bit)
  //   2. Skip to centre of start bit, verify it is still 0
  //   3. Sample 8 data bits at centres of their windows
  //   4. Skip stop bit
  //   5. Compare received byte to UART_EXPECTED[i]
  //
  // Accumulates mon_errors. Prints per-character result in debug mode,
  // always prints final summary.
  // -----------------------------------------------------------------------
  task automatic uart_raw_monitor();
    logic [7:0] recv_byte;
    int         mon_errors;
    byte        expected_byte;
    string      char_str;

    mon_errors = 0;
    $display(" [UART MON] Waiting for first start bit on uart_tx_o ...");
    $display(" [UART MON] Baud=%0d  Bit period=%0d ns  Expecting %0d chars",
             UART_BAUD_RATE, UART_BIT_NS, UART_MSG_LEN);

    for (int i = 0; i < UART_MSG_LEN; i++) begin

      // --- wait for start bit (falling edge on idle-high line) ---
      @(negedge uart_tx_o);

      // --- move to centre of start bit and verify ---
      #(UART_BIT_NS / 2);
      if (uart_tx_o !== 1'b0) begin
        $display(" [UART MON] char[%02d]: start bit glitch — line not low at sample point", i);
        mon_errors++;
        continue;
      end

      // --- sample 8 data bits LSB first ---
      recv_byte = 8'h00;
      for (int b = 0; b < 8; b++) begin
        #(UART_BIT_NS);                  // advance one full bit period
        recv_byte[b] = uart_tx_o;        // sample at centre of bit window
      end

      // --- skip stop bit ---
      #(UART_BIT_NS);

      // --- compare ---
      expected_byte = byte'(UART_EXPECTED[i]);

      if (recv_byte === 8'(expected_byte)) begin
        if (debug) begin
          if (expected_byte >= 8'h20 && expected_byte < 8'h7f)
            $display(" [UART MON] char[%02d] = 0x%02x ('%c') — MATCH", i, recv_byte, expected_byte);
          else
            $display(" [UART MON] char[%02d] = 0x%02x (0x%02x) — MATCH", i, recv_byte, expected_byte);
        end
      end else begin
        if (expected_byte >= 8'h20 && expected_byte < 8'h7f)
          $display(" [UART MON] char[%02d] = 0x%02x  MISMATCH  expected 0x%02x ('%c')",
                   i, recv_byte, expected_byte, expected_byte);
        else
          $display(" [UART MON] char[%02d] = 0x%02x  MISMATCH  expected 0x%02x",
                   i, recv_byte, expected_byte);
        mon_errors++;
      end

    end // for each character

    // --- summary ---
    if (mon_errors == 0)
      $display("\033[1;32m [UART MON] Wire-level PASSED — all %0d chars correct\033[0m",
               UART_MSG_LEN);
    else
      $display("\033[1;31m [UART MON] Wire-level FAILED — %0d / %0d chars wrong\033[0m",
               mon_errors, UART_MSG_LEN);

  endtask

  // -----------------------------------------------------------------------
  // DECODE ERRORS TASK
  //
  // Decodes the exit_code bitmask written by uart.c to tohost.
  // Each set bit i indicates that character i of UART_EXPECTED was not
  // matched in the RX FIFO read-back.
  //
  // Declared as a separate automatic task so that the local variable
  // 'exp' is unambiguously automatic in scope, eliminating the
  // VRFC 10-3824 warning that fires when a variable with an initializer
  // is declared inside a for-loop inside a static initial block.
  // -----------------------------------------------------------------------
  task automatic decode_errors(input int err_code);
    byte exp_byte;  // declared once outside the loop — no static/automatic ambiguity
    for (int i = 0; i < UART_MSG_LEN; i++) begin
      if (err_code & (1 << i)) begin
        exp_byte = byte'(UART_EXPECTED[i]);  // assigned, not declared+initialized in loop
        if (exp_byte >= 8'h20 && exp_byte < 8'h7f)
          $display(" [FAIL]   bit[%02d] set — expected '%c' (0x%02x) not matched in RX",
                   i, exp_byte, exp_byte);
        else
          $display(" [FAIL]   bit[%02d] set — expected 0x%02x not matched in RX",
                   i, exp_byte);
      end
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // -----------------------------------------------------------------------
  // UART monitor thread — runs fully in parallel with main test flow.
  // Triggered by its own initial block so it never blocks tohost polling.
  // -----------------------------------------------------------------------
  initial begin
    uart_raw_monitor();
  end

  // -----------------------------------------------------------------------
  // MAIN TEST FLOW
  // -----------------------------------------------------------------------
  initial begin
    $timeformat(-6, 0, "us");
    $dumpfile("sc_soc_tb.vcd");
    $dumpvars(0, sc_soc_tb);

    if (!$value$plusargs("TEST=%s", test_name))
      $fatal(1, " [FATAL] No test specified. Use +TEST=<test_name>");

    if (!$value$plusargs("DEBUG=%d", debug))
      $fatal(1, " [FATAL] No debug specified. Use +DEBUG=<debug_value>");

    if (!$value$plusargs("BDL=%d", back_door_load))
      $fatal(1, " [FATAL] No back door load specified. Use +BDL=<back_door_load_value>");

    load_symbols("prog.sym");

    system_clk_i_enable();
    xtal_in_enable();
    apb_clk_i_enable();
    apply_reset();
    boot_addr_i <= sym["_start"];
    repeat (10) @(posedge apb_clk_i);

    load_program("prog.hex");

    core_clk_i_enable();  // CPU starts — uart.c begins executing

    // Poll tohost every 100 ns.
    // uart.c writes: error = 0 (all match) or bitmask of failed chars.
    // tohost becomes non-zero only after all 16 comparisons are done.
    do #100ns; while (ram_read(sym["tohost"]) == 0);

    begin
      exit_code = 'h7fff_ffff & ram_read(sym["tohost"]);
      $display("Exit code: 0x%08x (%0d)", exit_code, exit_code);

      if (exit_code == 0) begin
        $display("\033[1;32m [PASS] %s\033[0m", test_name);
      end else begin
        $display("\033[1;31m [FAIL] %s — error bitmask 0x%08x\033[0m", test_name, exit_code);
        // Decode which characters the C program found wrong.
        // Delegated to decode_errors() to avoid VRFC 10-3824 on 'exp'.
        decode_errors(exit_code);
      end
    end

    $finish;
  end

  // -----------------------------------------------------------------------
  // TIMEOUT WATCHDOG
  //
  // Wire time alone: 16 chars * 10 bits * 1000 ns = 160 µs
  // Plus all busy-wait polling loops in uart.c.
  // 5 ms is generous and safe at 1 MHz baud.
  // Original 200 µs was far too short and would always fire first.
  // -----------------------------------------------------------------------
  initial begin
    #5ms;
    $display("\033[1;31m [FAIL] %s -- TIMEDOUT\033[0m", test_name);
    $finish;
  end

endmodule