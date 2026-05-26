`include "package/sc_soc_pkg.sv"
`include "package/ctrl_pkg.sv"

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
    output logic [31:0] fromhost_o,

    output logic [31:0] dma_src_addr_o,
    output logic [31:0] dma_dst_addr_o,
    output logic [31:0] dma_num_words_o,
    output logic        dma_start_pulse_o,
    input  logic        dma_busy_i,
    input  logic [31:0] dma_words_remaining_i,
    output logic        dma_idle_irq_o
);

  // ---------------------------------------------------------------------------
  // AXI4-Lite FIFO (decouples slave handshake from register logic)
  // ---------------------------------------------------------------------------

  axil_req_t  fifo_req;
  axil_resp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (8),
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
  // AXI4-Lite to local memory-interface bridge
  // ---------------------------------------------------------------------------

  logic       [ 7:0] mem_waddr;
  logic       [31:0] mem_wdata;
  logic       [ 3:0] mem_wstrb;
  logic              mem_wenable;
  logic              mem_werror;
  logic       [ 7:0] mem_raddr;
  logic       [31:0] mem_rdata;
  logic              mem_rerror;
  logic              mem_read_active;
  logic              mem_write_ok;
  (* unused = "true" *)logic              mem_wnsecure_unused;
  (* unused = "true" *)logic              mem_rnsecure_unused;
  axil_resp_t        mem_resp;

  axi4l_to_memif #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (8),
      .DATA_WIDTH  (32)
  ) u_axi4l_to_memif (
      .axi4l_req_i (fifo_req),
      .axi4l_resp_o(mem_resp),
      .waddr_o     (mem_waddr),
      .wnsecure_o  (mem_wnsecure_unused),
      .wdata_o     (mem_wdata),
      .wstrb_o     (mem_wstrb),
      .wenable_o   (mem_wenable),
      .werror_i    (mem_werror),
      .raddr_o     (mem_raddr),
      .rnsecure_o  (mem_rnsecure_unused),
      .rdata_i     (mem_rdata),
      .rerror_i    (mem_rerror)
  );

  // Keep legacy SLVERR encoding (2'b10) at this block boundary.
  always_comb begin
    fifo_resp        = mem_resp;
    fifo_resp.b.resp = (mem_resp.b.resp == 2'b11) ? 2'b10 : mem_resp.b.resp;
    fifo_resp.r.resp = (mem_resp.r.resp == 2'b11) ? 2'b10 : mem_resp.r.resp;
  end

  always_comb mem_read_active = mem_resp.r_valid && mem_resp.ar_ready;

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
  logic [31:0] dma_src_addr_q;
  logic [31:0] dma_dst_addr_q;
  logic [31:0] dma_num_words_q;
  logic        dma_start_pulse_q;

  assign core_boot_addr_o = core_boot_addr_q;
  assign core_hart_id_o   = core_hart_id_q;
  assign core_rst_en_o    = core_clk_rst_q[0];
  assign core_clk_en_o    = core_clk_rst_q[1];
  assign gpio_out_o       = gpio_out_q;
  assign gpio_dir_o       = gpio_dir_q;
  assign gpio_pull_o      = gpio_pull_q;
  assign tohost_o         = tohost_q;
  assign fromhost_o       = fromhost_q;
  assign dma_src_addr_o   = dma_src_addr_q;
  assign dma_dst_addr_o   = dma_dst_addr_q;
  assign dma_num_words_o  = dma_num_words_q;
  assign dma_start_pulse_o = dma_start_pulse_q;
  assign dma_idle_irq_o   = ~dma_busy_i;
  assign pll_fb_div_o     = CTRL_PLL_CFG_RESET[18:5];
  assign pll_ref_div_o    = CTRL_PLL_CFG_RESET[4:0];

  // ---------------------------------------------------------------------------
  // Register write logic
  // ---------------------------------------------------------------------------

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      core_boot_addr_q <= CTRL_CORE_BOOT_ADDR_RESET;
      core_hart_id_q   <= 32'h0000_0000;
      core_clk_rst_q   <= bootmode_i ? 32'h0000_0002 : 32'h0000_0000;
      tohost_q         <= 32'h0000_0000;
      fromhost_q       <= 32'h0000_0000;
      gpio_out_q       <= 32'h0000_0000;
      gpio_dir_q       <= 32'h0000_0000;
      gpio_pull_q      <= 32'h0000_0000;
      dma_src_addr_q   <= CTRL_DMA_SRC_ADDR_RESET;
      dma_dst_addr_q   <= CTRL_DMA_DST_ADDR_RESET;
      dma_num_words_q  <= CTRL_DMA_NUM_WORDS_RESET;
      dma_start_pulse_q <= 1'b0;
    end else begin
      dma_start_pulse_q <= 1'b0;
      if (mem_write_ok) begin
        case (mem_waddr)
          CTRL_CORE_BOOT_ADDR_OFFSET: core_boot_addr_q <= mem_wdata;
          CTRL_CORE_HART_ID_OFFSET:   core_hart_id_q <= mem_wdata;
          CTRL_CORE_CLK_RST_OFFSET:   core_clk_rst_q <= {30'b0, mem_wdata[1:0]};
          CTRL_TOHOST_OFFSET:         tohost_q <= mem_wdata;
          CTRL_FROMHOST_OFFSET:       fromhost_q <= mem_wdata;
          CTRL_GPIO_OUT_OFFSET:       gpio_out_q <= mem_wdata;
          CTRL_GPIO_DIR_OFFSET:       gpio_dir_q <= mem_wdata;
          CTRL_GPIO_PULL_OFFSET:      gpio_pull_q <= mem_wdata;
          CTRL_DMA_SRC_ADDR_OFFSET:   dma_src_addr_q <= mem_wdata;
          CTRL_DMA_DST_ADDR_OFFSET:   dma_dst_addr_q <= mem_wdata;
          CTRL_DMA_NUM_WORDS_OFFSET: begin
            dma_num_words_q <= mem_wdata;
            dma_start_pulse_q <= (mem_wdata != 32'h0000_0000) && !dma_busy_i;
          end
          default: begin
          end
        endcase
      end
    end
  end

  always_comb begin
    mem_werror = 1'b1;
    // axi4l_to_memif intentionally does not enforce byte strobe policy.
    // Control registers in this block only accept full-word writes.
    if (mem_wstrb == 4'b1111) begin
      case (mem_waddr)
        CTRL_CORE_BOOT_ADDR_OFFSET,
            CTRL_CORE_HART_ID_OFFSET,
            CTRL_CORE_CLK_RST_OFFSET,
            CTRL_TOHOST_OFFSET,
            CTRL_FROMHOST_OFFSET,
            CTRL_GPIO_OUT_OFFSET,
            CTRL_GPIO_DIR_OFFSET,
            CTRL_GPIO_PULL_OFFSET,
            CTRL_DMA_NUM_WORDS_OFFSET:
        mem_werror = 1'b0;
        CTRL_DMA_SRC_ADDR_OFFSET, CTRL_DMA_DST_ADDR_OFFSET:
        // No realignment in DMA bringup path: reject unaligned byte addresses.
        mem_werror = (mem_wdata[1:0] != 2'b00);
        default: begin
        end
      endcase
    end
  end

  always_comb mem_write_ok = mem_wenable && !mem_werror;

  // ---------------------------------------------------------------------------
  // Read mux/error logic
  // ---------------------------------------------------------------------------

  always_comb begin
    mem_rdata  = 32'h0000_0000;
    mem_rerror = 1'b1;

    if (mem_read_active) begin
      case (mem_raddr)
        CTRL_SOC_ID_OFFSET: begin
          mem_rdata  = CTRL_SOC_ID_RESET;
          mem_rerror = 1'b0;
        end

        CTRL_REV_ID_OFFSET: begin
          mem_rdata  = CTRL_REV_ID_RESET;
          mem_rerror = 1'b0;
        end

        CTRL_CORE_BOOT_ADDR_OFFSET: begin
          mem_rdata  = core_boot_addr_q;
          mem_rerror = 1'b0;
        end

        CTRL_CORE_HART_ID_OFFSET: begin
          mem_rdata  = core_hart_id_q;
          mem_rerror = 1'b0;
        end

        CTRL_CORE_CLK_RST_OFFSET: begin
          mem_rdata  = core_clk_rst_q;
          mem_rerror = 1'b0;
        end

        CTRL_PLL_CFG_OFFSET: begin
          // PLL_CFG is a read-only constant; no writable fields.
          mem_rdata  = CTRL_PLL_CFG_RESET;
          mem_rerror = 1'b0;
        end

        CTRL_TOHOST_OFFSET: begin
          mem_rdata  = tohost_q;
          mem_rerror = 1'b0;
        end

        CTRL_FROMHOST_OFFSET: begin
          mem_rdata  = fromhost_q;
          mem_rerror = 1'b0;
        end

        CTRL_BOOTMODE_OFFSET: begin
          mem_rdata  = {31'b0, bootmode_i};
          mem_rerror = 1'b0;
        end

        CTRL_GPIO_IN_OFFSET: begin
          // gpio_in_sync_q is the output of the two-stage synchronizer;
          // gpio_in_i must never be read directly from this domain.
          mem_rdata  = gpio_in_sync_q;
          mem_rerror = 1'b0;
        end

        CTRL_GPIO_OUT_OFFSET: begin
          mem_rdata  = gpio_out_q;
          mem_rerror = 1'b0;
        end

        CTRL_GPIO_DIR_OFFSET: begin
          mem_rdata  = gpio_dir_q;
          mem_rerror = 1'b0;
        end

        CTRL_GPIO_PULL_OFFSET: begin
          mem_rdata  = gpio_pull_q;
          mem_rerror = 1'b0;
        end

        CTRL_DMA_SRC_ADDR_OFFSET: begin
          mem_rdata  = dma_src_addr_q;
          mem_rerror = 1'b0;
        end

        CTRL_DMA_DST_ADDR_OFFSET: begin
          mem_rdata  = dma_dst_addr_q;
          mem_rerror = 1'b0;
        end

        CTRL_DMA_NUM_WORDS_OFFSET: begin
          mem_rdata  = dma_num_words_q;
          mem_rerror = 1'b0;
        end

        CTRL_DMA_IDLE_IRQ_OFFSET: begin
          mem_rdata  = {31'b0, dma_idle_irq_o};
          mem_rerror = 1'b0;
        end

        CTRL_DMA_BUSY_OFFSET: begin
          mem_rdata  = {31'b0, dma_busy_i};
          mem_rerror = 1'b0;
        end

        CTRL_DMA_WORDS_REMAINING_OFFSET: begin
          mem_rdata  = dma_words_remaining_i;
          mem_rerror = 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

endmodule
