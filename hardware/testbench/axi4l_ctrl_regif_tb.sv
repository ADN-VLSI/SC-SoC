// =============================================================================
// axi4l_ctrl_regif_tb.sv
// Top-level testbench for axi4l_ctrl_regif (SC-SoC control register block).
//
// Register map base: CTRL_BASE = 0x0001_0000
// All offsets are relative; tests drive the DUT at absolute addresses.
//
// TCs implemented (one task per include file):
//   TC0  — Reset behaviour
//   TC1  — RO constant reads  (SOC_ID / REV_ID)
//   TC2  — RW write/readback  (CORE_BOOT_ADDR / CORE_HART_ID)
//   TC3  — CORE_CLK_RST bit-fields
//   TC4  — PLL_CFG bit-field layout
//   TC5  — RO write protection (SOC_ID, REV_ID, PLL_CFG)
//   TC6  — BOOTMODE live sideband + write protection
//   TC7  — TOHOST / FROMHOST independence
//   TC8  — Partial write rejection
//   TC9  — Unmapped address handling
//   TC10 — AXI FIFO back-pressure
//   TC11 — DMA register + status plumbing
// =============================================================================

`include "package/sc_soc_pkg.sv"
`include "package/ctrl_pkg.sv"
`include "axi/typedef.svh"

module axi4l_ctrl_regif_tb;

  // ---------------------------------------------------------------------------
  // Imports
  // ---------------------------------------------------------------------------
  import sc_soc_pkg::*;
  import ctrl_pkg::*;

  // ---------------------------------------------------------------------------
  // Local parameters
  // ---------------------------------------------------------------------------
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;

  // AXI-Lite typedefs used by the testbench interface (structurally identical
  // to sc_soc_pkg::axil_* but under a separate prefix so the adapter below
  // can bridge them explicitly).
  `AXI_LITE_TYPEDEF_ALL(my, logic [ADDR_WIDTH-1:0], logic [DATA_WIDTH-1:0],
                        logic [DATA_WIDTH/8-1:0])

  // Base address of the control register block (used to compute abs addresses)
  localparam logic [31:0] CTRL_BASE_ADDR = 32'h0001_0000;

  // ---------------------------------------------------------------------------
  // Clock / reset
  // ---------------------------------------------------------------------------
  logic clk_i;
  logic arst_ni;

  // ---------------------------------------------------------------------------
  // DUT sideband ports
  // ---------------------------------------------------------------------------
  // Sideband outputs (DUT → TB)
  logic [31:0] core_boot_addr_o;
  logic [31:0] core_hart_id_o;
  logic        core_rst_en_o;
  logic        core_clk_en_o;
  logic [31:0] tohost_o;
  logic [13:0] pll_fb_div_o;
  logic [ 4:0] pll_ref_div_o;
  logic [31:0] fromhost_o;
  logic [31:0] gpio_out_o;
  logic [31:0] gpio_dir_o;
  logic [31:0] gpio_pull_o;
  logic [31:0] dma_src_addr_o;
  logic [31:0] dma_dst_addr_o;
  logic [31:0] dma_num_words_o;
  logic        dma_start_pulse_o;
  logic        dma_idle_irq_o;

  // Sideband inputs (TB → DUT)
  logic        bootmode_i;
  logic [31:0] gpio_in_i;
  logic        dma_busy_i;
  logic [31:0] dma_words_remaining_i;

  // ---------------------------------------------------------------------------
  // AXI4-Lite interface (parameterised with testbench's my_* types)
  // ---------------------------------------------------------------------------
  axi4l_if #(
    .req_t (my_req_t),
    .resp_t(my_resp_t)
  ) intf (
    .arst_ni(arst_ni),
    .clk_i  (clk_i)
  );

  // ---------------------------------------------------------------------------
  // Adapter: my_req_t / my_resp_t  <->  sc_soc_pkg::axil_req_t / axil_resp_t
  // ---------------------------------------------------------------------------
  axil_req_t  dut_req;
  axil_resp_t dut_resp;

  always_comb begin
    dut_req          = '0;
    // AW
    dut_req.aw_valid = intf.req.aw_valid;
    dut_req.aw.addr  = intf.req.aw.addr;
    dut_req.aw.prot  = intf.req.aw.prot;
    // W
    dut_req.w_valid  = intf.req.w_valid;
    dut_req.w.data   = intf.req.w.data;
    dut_req.w.strb   = intf.req.w.strb;
    // B
    dut_req.b_ready  = intf.req.b_ready;
    // AR
    dut_req.ar_valid = intf.req.ar_valid;
    dut_req.ar.addr  = intf.req.ar.addr;
    dut_req.ar.prot  = intf.req.ar.prot;
    // R
    dut_req.r_ready  = intf.req.r_ready;
  end

  always_comb begin
    intf.resp.aw_ready = dut_resp.aw_ready;
    intf.resp.w_ready  = dut_resp.w_ready;
    intf.resp.b_valid  = dut_resp.b_valid;
    intf.resp.b.resp   = dut_resp.b.resp;
    intf.resp.ar_ready = dut_resp.ar_ready;
    intf.resp.r_valid  = dut_resp.r_valid;
    intf.resp.r.data   = dut_resp.r.data;
    intf.resp.r.resp   = dut_resp.r.resp;
  end

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  axi4l_ctrl_regif
  #(
    .axil_req_t  (axil_req_t),
    .axil_resp_t (axil_resp_t)
)
  u_dut (
    .clk_i           (clk_i),
    .arst_ni         (arst_ni),
    .req_i           (dut_req),
    .resp_o          (dut_resp),
    .core_boot_addr_o(core_boot_addr_o),
    .core_hart_id_o  (core_hart_id_o),
    .core_rst_en_o   (core_rst_en_o),
    .core_clk_en_o   (core_clk_en_o),
    .bootmode_i      (bootmode_i),
    .gpio_in_i       (gpio_in_i),
    .gpio_out_o      (gpio_out_o),
    .gpio_dir_o      (gpio_dir_o),
    .gpio_pull_o     (gpio_pull_o),
    .tohost_o        (tohost_o),
    .pll_ref_div_o   (pll_ref_div_o),
    .pll_fb_div_o    (pll_fb_div_o),
    .fromhost_o      (fromhost_o),
    .dma_src_addr_o  (dma_src_addr_o),
    .dma_dst_addr_o  (dma_dst_addr_o),
    .dma_num_words_o (dma_num_words_o),
    .dma_start_pulse_o(dma_start_pulse_o),
    .dma_busy_i      (dma_busy_i),
    .dma_words_remaining_i(dma_words_remaining_i),
    .dma_idle_irq_o  (dma_idle_irq_o)
  );

  // ---------------------------------------------------------------------------
  // Helper: standalone regif sees local register offsets.
  // ---------------------------------------------------------------------------
  function automatic logic [31:0] reg_addr(input logic [31:0] offset);
    return offset;
  endfunction

  // ---------------------------------------------------------------------------
  // Helper: write_32 — full 32-bit write, waits for B response
  // ---------------------------------------------------------------------------
  task automatic write_32(
    input  logic [31:0] addr,
    input  logic [31:0] data,
    output logic [1:0]  resp
  );
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w ({data, 4'b1111});
      intf.recv_b (resp);
    join
  endtask

  // ---------------------------------------------------------------------------
  // Helper: read_32 — full 32-bit read, waits for R response
  // ---------------------------------------------------------------------------
  task automatic read_32(
    input  logic [31:0] addr,
    output logic [31:0] data,
    output logic [1:0]  resp
  );
    logic [33:0] r_bus;  // {data[31:0], resp[1:0]}
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r (r_bus);
    join
    data = r_bus[33:2];
    resp = r_bus[1:0];
  endtask

  // ---------------------------------------------------------------------------
  // Helper: send_aw_w — low-level AW+W only (no recv_b); used for SLVERR
  //         and back-pressure tests
  // ---------------------------------------------------------------------------
  task automatic send_aw_w(
    input logic [31:0] addr,
    input logic [31:0] data,
    input logic [3:0]  strb
  );
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w ({data, strb});
    join
  endtask

  // ---------------------------------------------------------------------------
  // Helper: check — pass/fail accumulator with optional message
  // ---------------------------------------------------------------------------
  task automatic check(
    input logic   ok,
    inout int     p,
    inout int     f,
    input string  msg
  );
    if (ok) begin
      p++;
      if (msg != "") $display("  [PASS] %s", msg);
    end else begin
      f++;
      if (msg != "") $display("  [FAIL] %s", msg);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Include test-case tasks
  // ---------------------------------------------------------------------------
  `include "axi4l_ctrl_regif_tb/tc0.sv"
  `include "axi4l_ctrl_regif_tb/tc1.sv"
  `include "axi4l_ctrl_regif_tb/tc2.sv"
  `include "axi4l_ctrl_regif_tb/tc3.sv"
  `include "axi4l_ctrl_regif_tb/tc4.sv"
  `include "axi4l_ctrl_regif_tb/tc5.sv"
  `include "axi4l_ctrl_regif_tb/tc6.sv"
  `include "axi4l_ctrl_regif_tb/tc7.sv"
  `include "axi4l_ctrl_regif_tb/tc8.sv"
  `include "axi4l_ctrl_regif_tb/tc9.sv"
  `include "axi4l_ctrl_regif_tb/tc10.sv"
  `include "axi4l_ctrl_regif_tb/tc11.sv"

  // ---------------------------------------------------------------------------
  // Main initial block
  // ---------------------------------------------------------------------------
  initial begin
    automatic int total_p     = 0;
    automatic int total_f     = 0;
    automatic int p           = 0;
    automatic int f           = 0;
    automatic int test_number = 0;

    if (!$value$plusargs("TEST=%d", test_number))
      $fatal(1, "Must specify test with +TEST=N  (0-11).");

    $display("=== axi4l_ctrl_regif_tb  TEST=%0d ===", test_number);
    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_ctrl_regif_tb.vcd");
    $dumpvars(0, axi4l_ctrl_regif_tb);

    #20;

    // Default sideband stimulus
    bootmode_i  <= 1'b0;
    gpio_in_i   <= 32'h0000_0000;
    dma_busy_i  <= 1'b0;
    dma_words_remaining_i <= 32'h0000_0000;

    // Reset sequence
    clk_i   <= 1'b0;
    arst_ni <= 1'b0;
    intf.req_reset();
    #20;
    arst_ni <= 1'b1;
    #20;

    fork
      forever #5 clk_i <= ~clk_i;
    join_none

    @(posedge clk_i);

    repeat (1) begin
      p = 0; f = 0;
      case (test_number)
        0:  tc0 (p, f);
        1:  tc1 (p, f);
        2:  tc2 (p, f);
        3:  tc3 (p, f);
        4:  tc4 (p, f);
        5:  tc5 (p, f);
        6:  tc6 (p, f);
        7:  tc7 (p, f);
        8:  tc8 (p, f);
        9:  tc9 (p, f);
        10: tc10(p, f);
        11: tc11(p, f);
        default: $fatal(1, "Invalid TEST=%0d  (valid 0-11)", test_number);
      endcase

      $display("TC%0d iteration result: PASS=%0d  FAIL=%0d", test_number, p, f);
      total_p += p;
      total_f += f;
    end

    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", total_p);
    $display("TOTAL FAIL = %0d", total_f);
    if (total_f == 0) $display("OVERALL: PASSED");
    else              $display("OVERALL: FAILED");

    repeat (20) @(posedge clk_i);
    $finish;
  end

endmodule // axi4l_ctrl_regif_tb
