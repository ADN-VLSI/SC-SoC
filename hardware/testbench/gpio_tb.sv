/*
 * Testbench  : gpio_tb.sv
 * Author     : Adnan Sami Anirban
 * Description: Self-checking testbench for gpio.sv
 *
 * Test Cases:
 *   TC1  - Output test           : all pins output, drive 0xAAAAAAAA
 *   TC2  - Output value change   : all pins output, drive 0x55555555
 *   TC3  - Input test            : all pins input, TB drives 0xDEADBEEF
 *   TC4  - Pull-down idle        : all pins input, pull active, no external drive -> 0
 *   TC5  - Pull-down override    : pull active, TB drives strong 1 -> strong wins
 *   TC6  - Mixed mode            : lower 16 output, upper 16 input
 *   TC7  - Walking ones output   : each pin driven HIGH one at a time
 *   TC8  - Direction change      : output -> input -> output, check no conflict
 */

module gpio_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-LOCALPARAMS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int GPIO_WIDTH = 32;

  // ── ANSI color codes ──
  localparam string GREEN  = "\033[0;32m";
  localparam string RED    = "\033[0;31m";
  localparam string YELLOW = "\033[0;33m";
  localparam string CYAN   = "\033[0;36m";
  localparam string BOLD   = "\033[1m";
  localparam string RESET  = "\033[0m";

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-COUNTERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  int pass_count = 0;
  int fail_count = 0;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // ── DUT signals ──
  logic [GPIO_WIDTH-1:0] gpio_dir_i;
  logic [GPIO_WIDTH-1:0] gpio_out_i;
  logic [GPIO_WIDTH-1:0] gpio_pull_i;
  logic [GPIO_WIDTH-1:0] gpio_in_o;
  wire  [GPIO_WIDTH-1:0] gpio_pin_io;

  // ── TB drive signals ──
  logic [GPIO_WIDTH-1:0] tb_drive;
  logic [GPIO_WIDTH-1:0] tb_drive_en;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-INOUT DRIVE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  genvar i;
  generate
    for (i = 0; i < GPIO_WIDTH; i++) begin : gen_tb_drive
      assign gpio_pin_io[i] = tb_drive_en[i] ? tb_drive[i] : 1'bz;
    end
  endgenerate

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-DUT INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  gpio #(
      .GPIO_WIDTH(GPIO_WIDTH)
  ) u_dut (
      .gpio_dir_i  (gpio_dir_i),
      .gpio_out_i  (gpio_out_i),
      .gpio_pull_i (gpio_pull_i),
      .gpio_in_o   (gpio_in_o),
      .gpio_pin_io (gpio_pin_io)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-TASKS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task apply_stimulus(
      input logic [GPIO_WIDTH-1:0] dir,
      input logic [GPIO_WIDTH-1:0] out,
      input logic [GPIO_WIDTH-1:0] pull,
      input logic [GPIO_WIDTH-1:0] tb_en,
      input logic [GPIO_WIDTH-1:0] tb_val
  );
    gpio_dir_i  = dir;
    gpio_out_i  = out;
    gpio_pull_i = pull;
    tb_drive_en = tb_en;
    tb_drive    = tb_val;
    #10;
  endtask

  task check_pin(
      input string                 tc_name,
      input logic [GPIO_WIDTH-1:0] expected,
      input logic [GPIO_WIDTH-1:0] actual
  );
    if (actual === expected) begin
      $display("%s[PASS]%s %s", GREEN, RESET, tc_name);
      pass_count++;
    end else begin
      $display("%s[FAIL]%s %s -- expected: %h, got: %h", RED, RESET, tc_name, expected, actual);
      fail_count++;
    end
  endtask

  task check_pin_partial(
      input string                 tc_name,
      input logic [GPIO_WIDTH-1:0] expected,
      input logic [GPIO_WIDTH-1:0] actual,
      input logic [GPIO_WIDTH-1:0] mask
  );
    if ((actual & mask) === (expected & mask)) begin
      $display("%s[PASS]%s %s", GREEN, RESET, tc_name);
      pass_count++;
    end else begin
      $display("%s[FAIL]%s %s -- expected: %h, got: %h", RED, RESET, tc_name, expected & mask, actual & mask);
      fail_count++;
    end
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-TEST
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    // ── initialize ──
    gpio_dir_i  = '0;
    gpio_out_i  = '0;
    gpio_pull_i = '0;
    tb_drive    = '0;
    tb_drive_en = '0;
    #10;

    $display("%s--- GPIO Testbench Start ---%s", CYAN, RESET);

    // ── TC1: Output test ──────────────────────────────────────────────────────────────────────
    // gpio_dir=all output, gpio_out=0xAAAAAAAA, TB disconnect
    // expect: gpio_pin_io = 0xAAAAAAAA
    apply_stimulus(32'hFFFFFFFF, 32'hAAAAAAAA, 32'h00000000, 32'h00000000, 32'h00000000);
    check_pin("TC1-output-AAAA", 32'hAAAAAAAA, gpio_pin_io);

    // ── TC2: Output value change ──────────────────────────────────────────────────────────────
    // gpio_out changes to 0x55555555
    // expect: gpio_pin_io = 0x55555555
    apply_stimulus(32'hFFFFFFFF, 32'h55555555, 32'h00000000, 32'h00000000, 32'h00000000);
    check_pin("TC2-output-5555", 32'h55555555, gpio_pin_io);

    // ── TC3: Input test ───────────────────────────────────────────────────────────────────────
    // gpio_dir=all input, pull=0, TB drives 0xBEEFEEEE
    // expect: gpio_in_o = 0xBEEFEEEE
    apply_stimulus(32'h00000000, 32'h00000000, 32'h00000000, 32'hFFFFFFFF, 32'hBEEFEEEE);
    check_pin("TC3-input-drive", 32'hBEEFEEEE, gpio_in_o);

    // ── TC4: Pull-down idle ───────────────────────────────────────────────────────────────────
    // gpio_dir=all input, pull=all active, TB disconnect
    // expect: gpio_in_o = 0x00000000 (pull-down wins)

    apply_stimulus(32'h00000000, 32'h00000000, 32'hFFFFFFFF, 32'h00000000, 32'h00000000);
    check_pin("TC4-pulldown-idle", 32'h00000000, gpio_in_o);

    // ── TC5: Pull-down override ───────────────────────────────────────────────────────────────
    // gpio_dir=all input, pull=all active, TB drives strong 1
    // expect: gpio_in_o = 0xFFFFFFFF (strong beats weak)

    apply_stimulus(32'h00000000, 32'h00000000, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
    check_pin("TC5-pulldown-override", 32'hFFFFFFFF, gpio_in_o);

    // ── TC6: Mixed mode ───────────────────────────────────────────────────────────────────────
    // lower 16 = output (drive 0xABCD)
    // upper 16 = input  (TB drives 0x1234, pull active)
    // expect: gpio_pin_io[15:0] = 0xABCD
    //         gpio_in_o[31:16]  = 0x1234

    apply_stimulus(32'h0000FFFF, 32'h0000ABCD, 32'hFFFF0000, 32'hFFFF0000, 32'h12340000);
    check_pin_partial("TC6-mixed-output", 32'h0000ABCD, gpio_pin_io, 32'h0000FFFF);
    check_pin_partial("TC6-mixed-input",  32'h12340000, gpio_in_o,   32'hFFFF0000);

    // ── TC7: Walking ones output ──────────────────────────────────────────────────────────────
    // each pin driven HIGH one at a time, rest LOW
    // expect: gpio_pin_io = 1 << j for each j
    begin
      logic [GPIO_WIDTH-1:0] walking;
      logic pass;
      pass = 1;
      for (int j = 0; j < GPIO_WIDTH; j++) begin
        walking = (32'h1 << j);
        apply_stimulus(32'hFFFFFFFF, walking, 32'h00000000, 32'h00000000, 32'h00000000);
        if (gpio_pin_io !== walking) begin
          $display("%s[FAIL]%s TC7-walking-ones -- bit %0d: expected %h, got %h",
                   RED, RESET, j, walking, gpio_pin_io);
          pass = 0;
          fail_count++;
        end
      end
      if (pass) begin
        $display("%s[PASS]%s TC7-walking-ones", GREEN, RESET);
        pass_count++;
      end
    end

    // ── TC8: Direction change test ────────────────────────────────────────────────────────────
    // Step A: all output, drive 0xCAFEBABE
    // Step B: switch to input, TB drives 0x12345678
    // Step C: switch back to output, drive 0xDEADC0DE

    apply_stimulus(32'hFFFFFFFF, 32'hCAFEBABE, 32'h00000000, 32'h00000000, 32'h00000000);
    check_pin("TC8A-dir-output", 32'hCAFEBABE, gpio_pin_io);

    apply_stimulus(32'h00000000, 32'h00000000, 32'h00000000, 32'hFFFFFFFF, 32'h12345678);
    check_pin("TC8B-dir-input", 32'h12345678, gpio_in_o);

    apply_stimulus(32'hFFFFFFFF, 32'hDEADC0DE, 32'h00000000, 32'h00000000, 32'h00000000);
    check_pin("TC8C-dir-output-again", 32'hDEADC0DE, gpio_pin_io);

    // ── SUMMARY ───────────────────────────────────────────────────────────────────────────────
    $display("%s--------------------------------------%s", YELLOW, RESET);
    $display("%sTEST SUMMARY%s", BOLD, RESET);
    $display("  Total  : %0d", pass_count + fail_count);
    $display("  %s[PASS]%s   : %0d", GREEN, RESET, pass_count);
    $display("  %s[FAIL]%s   : %0d", RED,   RESET, fail_count);
    if (fail_count == 0)
      $display("  Result : %sALL PASS%s", GREEN, RESET);
    else
      $display("  Result : %sFAIL%s", RED, RESET);
    $display("%s--------------------------------------%s", YELLOW, RESET);

    $finish;

  end

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-WAVEFORM DUMP
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin
    $dumpfile("gpio_tb.vcd");
    $dumpvars(0, gpio_tb);
  end

endmodule