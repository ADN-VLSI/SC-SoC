`include "package/clint_pkg.sv"

module axi4l_clint
  import clint_pkg::*;
#(
    parameter type        axil_req_t  = clint_axil_req_t,
    parameter type        axil_resp_t = clint_axil_resp_t,
    parameter logic [63:0] MTIME_INC  = CLINT_MTIME_INC_DEFAULT
) (
    input logic clk_i,
    input logic arst_ni,

    input logic timer_en_i,

    input  axil_req_t  axi4l_req_i,
    output axil_resp_t axi4l_resp_o,

    input  logic        ext_irq_i,
    output logic [31:0] irq_o,
    output logic        msip_irq_o,
    output logic        timer_irq_o,
    output logic [63:0] mtime_o,
    output logic [63:0] mtimecmp_o
);

  axi4l_clint_regif #(
      .axil_req_t (axil_req_t),
      .axil_resp_t(axil_resp_t),
      .ADDR_WIDTH (CLINT_ADDR_WIDTH),
      .DATA_WIDTH (CLINT_DATA_WIDTH),
      .MTIME_INC  (MTIME_INC)
  ) u_regif (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),
      .timer_en_i (timer_en_i),
      .req_i      (axi4l_req_i),
      .resp_o     (axi4l_resp_o),
      .msip_irq_o (msip_irq_o),
      .timer_irq_o(timer_irq_o),
      .mtime_o    (mtime_o),
      .mtimecmp_o (mtimecmp_o)
  );

  always_comb begin
    irq_o     = '0;
    irq_o[3]  = msip_irq_o;
    irq_o[7]  = timer_irq_o;
    irq_o[11] = ext_irq_i;
  end

endmodule
