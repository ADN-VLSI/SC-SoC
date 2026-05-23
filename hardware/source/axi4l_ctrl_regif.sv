`include "package/sc_soc_pkg.sv"
`include "package/ctrl_reg_pkg.sv"

module axi4l_ctrl_regif
  import sc_soc_pkg::*;
  import ctrl_reg_pkg::*;
(
    input logic clk_i,
    input logic arst_ni,

    input  axil_req_t  req_i,
    output axil_resp_t resp_o,

    output logic [31:0] core_boot_addr_o,
    output logic [31:0] core_hart_id_o,
    output logic        core_rst_en_o,
    output logic        core_clk_en_o,

    output logic [ 4:0] pll_ref_div_o,
    output logic [14:0] pll_fb_div_o,

    input logic bootmode_i,

    input  logic [31:0] gpio_in_i,
    output logic [31:0] gpio_out_o,
    output logic [31:0] gpio_dir_o,
    output logic [31:0] gpio_pull_o,

    output logic [31:0] tohost_o,
    output logic [31:0] fromhost_o
);

  // ---------------------------------------------------------------------------
  // AXI4-Lite FIFO (decouples slave handshake from register logic)
  // ---------------------------------------------------------------------------

  axil_req_t  fifo_req;
  axil_resp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (32),
      .DATA_WIDTH  (32),
      .FIFO_SIZE   (2)
  ) u_axi4l_fifo (
      .clk_i     (clk_i),
      .arst_ni   (arst_ni),
      .slv_req_i (req_i),
      .slv_resp_o(resp_o),
      .mst_req_o (fifo_req),
      .mst_resp_i(fifo_resp)
  );

  // ---------------------------------------------------------------------------
  // Channel enable signals
  // ---------------------------------------------------------------------------

  logic wr_en;
  logic rd_en;

  always_comb begin
    wr_en              = fifo_req.aw_valid && fifo_req.w_valid && fifo_req.b_ready;
    fifo_resp.aw_ready = wr_en;
    fifo_resp.w_ready  = wr_en;
    fifo_resp.b_valid  = wr_en;
  end

  always_comb begin
    rd_en              = fifo_req.ar_valid && fifo_req.r_ready;
    fifo_resp.ar_ready = rd_en;
    fifo_resp.r_valid  = rd_en;
  end

  // ---------------------------------------------------------------------------
  // GPIO_IN two-stage synchronizer
  // gpio_in_i arrives from asynchronous pad logic. Two capture flops clocked
  // by clk_i reduce metastability probability to a safe level before the value
  // is read back through the AXI register interface.
  // ---------------------------------------------------------------------------

  (* ASYNC_REG = "TRUE" *)logic [31:0] gpio_in_meta_q;
  (* ASYNC_REG = "TRUE" *)logic [31:0] gpio_in_sync_q;

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      gpio_in_meta_q <= 32'h0000_0000;
      gpio_in_sync_q <= 32'h0000_0000;
    end else begin
      gpio_in_meta_q <= gpio_in_i;
      gpio_in_sync_q <= gpio_in_meta_q;
    end
  end

  // ---------------------------------------------------------------------------
  // Register storage
  // ---------------------------------------------------------------------------

  logic [31:0] core_boot_addr_q;
  logic [31:0] core_hart_id_q;
  logic [31:0] core_clk_rst_q;
  logic [31:0] tohost_q;
  logic [31:0] fromhost_q;  // RW per register map; host path reads this value.
  logic [31:0] gpio_out_q;
  logic [31:0] gpio_dir_q;
  logic [31:0] gpio_pull_q;

  assign core_boot_addr_o = core_boot_addr_q;
  assign core_hart_id_o   = core_hart_id_q;
  assign core_rst_en_o    = core_clk_rst_q[0];
  assign core_clk_en_o    = core_clk_rst_q[1];
  assign tohost_o         = tohost_q;
  assign fromhost_o       = fromhost_q;
  assign gpio_out_o       = gpio_out_q;
  assign gpio_dir_o       = gpio_dir_q;
  assign gpio_pull_o      = gpio_pull_q;
  assign pll_fb_div_o     = CTRL_PLL_CFG_RESET[18:5];
  assign pll_ref_div_o    = CTRL_PLL_CFG_RESET[4:0];

  // ---------------------------------------------------------------------------
  // Register write logic
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      core_boot_addr_q <= CTRL_CORE_BOOT_ADDR_RESET;
      core_hart_id_q   <= 32'h0000_0000;
      core_clk_rst_q   <= 32'h0000_0000;
      tohost_q         <= 32'h0000_0000;
      fromhost_q       <= 32'h0000_0000;
      gpio_out_q       <= 32'h0000_0000;
      gpio_dir_q       <= 32'h0000_0000;
      gpio_pull_q      <= 32'h0000_0000;
    end else if (fifo_resp.b.resp == 2'b00) begin
      case (fifo_req.aw.addr)
        CTRL_CORE_BOOT_ADDR_OFFSET: core_boot_addr_q <= fifo_req.w.data;
        CTRL_CORE_HART_ID_OFFSET:   core_hart_id_q <= fifo_req.w.data;
        CTRL_CORE_CLK_RST_OFFSET:   core_clk_rst_q <= {30'b0, fifo_req.w.data[1:0]};
        CTRL_TOHOST_OFFSET:         tohost_q <= fifo_req.w.data;
        CTRL_FROMHOST_OFFSET:       fromhost_q <= fifo_req.w.data;
        CTRL_GPIO_OUT_OFFSET:       gpio_out_q <= fifo_req.w.data;
        CTRL_GPIO_DIR_OFFSET:       gpio_dir_q <= fifo_req.w.data;
        CTRL_GPIO_PULL_OFFSET:      gpio_pull_q <= fifo_req.w.data;
        default: begin
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Write response logic
  // ---------------------------------------------------------------------------

  always_comb begin
    fifo_resp.b.resp = 2'b10;  // SLVERR by default

    if (wr_en && fifo_req.w.strb == 4'b1111 && fifo_req.aw.prot[1] == 0) begin
      case (fifo_req.aw.addr)
        CTRL_CORE_BOOT_ADDR_OFFSET,
            CTRL_CORE_HART_ID_OFFSET,
            CTRL_CORE_CLK_RST_OFFSET,
            CTRL_TOHOST_OFFSET,
            CTRL_FROMHOST_OFFSET,
            CTRL_GPIO_OUT_OFFSET,
            CTRL_GPIO_DIR_OFFSET,
            CTRL_GPIO_PULL_OFFSET:
        fifo_resp.b.resp = 2'b00;  // OKAY
        default: fifo_resp.b.resp = 2'b10;  // SLVERR
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Read mux logic
  // ---------------------------------------------------------------------------

  always_comb begin
    fifo_resp.r.data = 32'h0000_0000;
    fifo_resp.r.resp = 2'b10;  // SLVERR by default

    if (rd_en && fifo_req.ar.prot[1] == 0) begin
      case (fifo_req.ar.addr)
        CTRL_SOC_ID_OFFSET: begin
          fifo_resp.r.data = CTRL_SOC_ID_RESET;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_REV_ID_OFFSET: begin
          fifo_resp.r.data = CTRL_REV_ID_RESET;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_CORE_BOOT_ADDR_OFFSET: begin
          fifo_resp.r.data = core_boot_addr_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_CORE_HART_ID_OFFSET: begin
          fifo_resp.r.data = core_hart_id_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_CORE_CLK_RST_OFFSET: begin
          fifo_resp.r.data = core_clk_rst_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_PLL_CFG_OFFSET: begin
          // PLL_CFG is a read-only constant; no writable fields.
          fifo_resp.r.data = CTRL_PLL_CFG_RESET;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_TOHOST_OFFSET: begin
          fifo_resp.r.data = tohost_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_FROMHOST_OFFSET: begin
          fifo_resp.r.data = fromhost_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_BOOTMODE_OFFSET: begin
          fifo_resp.r.data = {31'b0, bootmode_i};
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_GPIO_IN_OFFSET: begin
          // gpio_in_sync_q is the output of the two-stage synchronizer;
          // gpio_in_i must never be read directly from this domain.
          fifo_resp.r.data = gpio_in_sync_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_GPIO_OUT_OFFSET: begin
          fifo_resp.r.data = gpio_out_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_GPIO_DIR_OFFSET: begin
          fifo_resp.r.data = gpio_dir_q;
          fifo_resp.r.resp = 2'b00;
        end

        CTRL_GPIO_PULL_OFFSET: begin
          fifo_resp.r.data = gpio_pull_q;
          fifo_resp.r.resp = 2'b00;
        end

        default: begin
        end
      endcase
    end
  end

endmodule
