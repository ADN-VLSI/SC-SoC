module ctrl_subsystem (
    input logic xtal_i,       // 16MHz Crystal oscillator input
    input logic glob_arst_ni, // active low asynchronous reset

    output logic system_arst_no,
    output logic system_clk_o,

    input  ctrl_pkg::ctrl_axil_req_t  req_i,
    output ctrl_pkg::ctrl_axil_resp_t resp_o,

    output logic [31:0] boot_addr_o,
    output logic [31:0] hart_id_o,
    output logic        core_clk_o,
    output logic        core_arst_no,
    output logic [31:0] dma_src_addr_o,
    output logic [31:0] dma_dst_addr_o,
    output logic [31:0] dma_num_words_o,
    output logic        dma_start_pulse_o,

    input logic        dma_busy_i,
    input logic [31:0] dma_words_remaining_i,

    input logic bootmode_i,

    inout wire [31:0] gpio_io
);

  logic [4:0] pll_ref_div;
  logic [13:0] pll_fb_div;

  logic pll_clk_o;
  logic pll_locked;

  logic allow_sys_clk;
  logic allow_core_clk;

  logic core_rst_en;
  logic core_clk_en;

  logic [31:0] gpio_dir;
  logic [31:0] gpio_out;
  logic [31:0] gpio_pull;
  logic [31:0] gpio_in;
  (* unused = "true" *) logic [31:0] tohost_reg;
  (* unused = "true" *) logic [31:0] fromhost_reg;

  logic core_reset_n;

  delay_gen #(
      .DELAY_CYCLES(8)
  ) sys_rst_delay (
      .arst_ni(glob_arst_ni),
      .real_time_clk_i(xtal_i),
      .clk_i(xtal_i),
      .enable_i(glob_arst_ni),
      .enable_o(system_arst_no)
  );

  delay_gen #(
      .DELAY_CYCLES(8)
  ) core_rst_delay (
      .arst_ni(core_reset_n),
      .real_time_clk_i(xtal_i),
      .clk_i(xtal_i),
      .enable_i(core_reset_n),
      .enable_o(core_arst_no)
  );

  always_comb core_reset_n = glob_arst_ni & (~core_rst_en);

  axi4l_ctrl_regif #(
      .axil_req_t (ctrl_pkg::ctrl_axil_req_t),
      .axil_resp_t(ctrl_pkg::ctrl_axil_resp_t)
  ) u_regif (
      .clk_i(system_clk_o),
      .arst_ni(system_arst_no),
      .req_i(req_i),
      .resp_o(resp_o),
      .core_boot_addr_o(boot_addr_o),
      .core_hart_id_o(hart_id_o),
      .core_rst_en_o(core_rst_en),
      .core_clk_en_o(core_clk_en),
      .pll_ref_div_o(pll_ref_div),
      .pll_fb_div_o(pll_fb_div),
      .bootmode_i(bootmode_i),
      .gpio_in_i(gpio_in),
      .gpio_out_o(gpio_out),
      .gpio_dir_o(gpio_dir),
      .gpio_pull_o(gpio_pull),
      .tohost_o(tohost_reg),
      .fromhost_o(fromhost_reg),
      .dma_src_addr_o(dma_src_addr_o),
      .dma_dst_addr_o(dma_dst_addr_o),
      .dma_num_words_o(dma_num_words_o),
      .dma_start_pulse_o(dma_start_pulse_o),
      .dma_busy_i(dma_busy_i),
      .dma_words_remaining_i(dma_words_remaining_i),
      .dma_idle_irq_o()
  );

  pll #(
      .REF_DEV_WIDTH(5),
      .FB_DIV_WIDTH (14)
  ) u_pll (
      .arst_ni  (glob_arst_ni),
      .clk_ref_i(xtal_i),
      .ref_div_i(pll_ref_div),
      .fb_div_i (pll_fb_div),
      .clk_o    (pll_clk_o),
      .locked_o (pll_locked)
  );

  delay_gen #(
      .DELAY_CYCLES(8)
  ) sys_clk_delay (
      .arst_ni(system_arst_no),
      .real_time_clk_i(xtal_i),
      .clk_i(pll_clk_o),
      .enable_i(pll_locked),
      .enable_o(allow_sys_clk)
  );

  clk_gate u_clk_gate_sys (
      .arst_ni(glob_arst_ni),
      .en_i   (allow_sys_clk),
      .clk_i  (pll_clk_o),
      .clk_o  (system_clk_o)
  );

  delay_gen #(
      .DELAY_CYCLES(8)
  ) core_clk_delay (
      .arst_ni(core_arst_no),
      .real_time_clk_i(xtal_i),
      .clk_i(pll_clk_o),
      .enable_i(core_clk_en),
      .enable_o(allow_core_clk)
  );

  clk_gate u_clk_gate_core (
      .arst_ni(glob_arst_ni),
      .en_i   (allow_core_clk),
      .clk_i  (system_clk_o),
      .clk_o  (core_clk_o)
  );

  gpio #(
      .GPIO_WIDTH(32)
  ) u_gpio (
      .gpio_dir_i (gpio_dir),
      .gpio_out_i (gpio_out),
      .gpio_pull_i(gpio_pull),
      .gpio_in_o  (gpio_in),
      .gpio_pin_io(gpio_io)
  );

endmodule
