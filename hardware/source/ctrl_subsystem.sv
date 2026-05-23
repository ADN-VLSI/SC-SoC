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

    input logic bootmode_i,

    inout wire [31:0] gpio_io
);


  logic [ 4:0] pll_ref_div;
  logic [13:0] pll_fb_div;

  assign pll_ref_div = 16;
  assign pll_fb_div  = 100;

  logic pll_clk_o;
  logic pll_locked;
  logic core_clk_en;

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
      .core_rst_en_o(core_arst_no),
      .core_clk_en_o(core_clk_en),
      .pll_ref_div_o(pll_ref_div),
      .pll_fb_div_o(pll_fb_div),
      .bootmode_i(bootmode_i),
      .gpio_in_i(),  // TODO
      .gpio_out_o(),  // TODO
      .gpio_dir_o(),  // TODO
      .gpio_pull_o(),  // TODO
      .tohost_o(),
      .fromhost_o()
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

  clk_gate u_clk_gate_sys (
      .arst_ni(glob_arst_ni),
      .en_i   (pll_locked),
      .clk_i (pll_clk_o),
      .clk_o (system_clk_o)
  );

  clk_gate u_clk_gate_core (
      .arst_ni(glob_arst_ni),
      .en_i   (core_clk_en),
      .clk_i (system_clk_o),
      .clk_o (core_clk_o)
  );

endmodule

/*

module axi4l_ctrl_regif
  import ctrl_pkg::*;
#(
    parameter type axil_req_t  = logic,
    parameter type axil_resp_t = logic
) (
    input logic clk_i,
    input logic arst_ni,

    input  axil_req_t  req_i,
    output axil_resp_t resp_o,

    output logic [31:0] core_boot_addr_o,
    output logic [31:0] core_hart_id_o,
    output logic        core_rst_en_o,
    output logic        core_clk_en_o,

    output logic [ 4:0] pll_ref_div_o,
    output logic [13:0] pll_fb_div_o,

    input logic bootmode_i,

    input  logic [31:0] gpio_in_i,
    output logic [31:0] gpio_out_o,
    output logic [31:0] gpio_dir_o,
    output logic [31:0] gpio_pull_o,

    output logic [31:0] tohost_o,
    output logic [31:0] fromhost_o
);
*/
