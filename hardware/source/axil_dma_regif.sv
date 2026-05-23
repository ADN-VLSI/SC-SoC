`include "axi4l_dma_pkg.sv"

`include "package/axi4l_dma_pkg.sv"

module axil_dma_regif

  import axi4l_dma_pkg::dma_axil_req_t;
  import axi4l_dma_pkg::dma_axil_resp_t;
  import axi4l_dma_pkg::dma_src_addr_reg_t;
  import axi4l_dma_pkg::dma_dst_addr_reg_t;
  import axi4l_dma_pkg::dma_num_words_reg_t;
  import axi4l_dma_pkg::dma_remaining_reg_t;
  import axi4l_dma_pkg::dma_ctrl_reg_t;
  import axi4l_dma_pkg::dma_stat_reg_t;
  import axi4l_dma_pkg::DMA_SRC_ADDR_OFFSET;
  import axi4l_dma_pkg::DMA_DST_ADDR_OFFSET;
  import axi4l_dma_pkg::DMA_NUM_WORDS_OFFSET;
  import axi4l_dma_pkg::DMA_REMAINING_OFFSET;
  import axi4l_dma_pkg::DMA_CTRL_OFFSET;
  import axi4l_dma_pkg::DMA_STAT_OFFSET;

(
    input logic clk_i,
    input logic arst_ni,

    input  dma_axil_req_t req_i,
    output dma_axil_resp_t resp_o,

    output dma_src_addr_reg_t dma_src_addr_o,
    output dma_dst_addr_reg_t dma_dst_addr_o,
    output dma_num_words_reg_t dma_num_words_o,
    output dma_ctrl_reg_t dma_ctrl_o,
    input  dma_stat_reg_t dma_stat_i,
    input  dma_remaining_reg_t dma_remaining_i
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4L FIFO
  ////////////////////////////////////////////////////////////////////////////////////////////////

  dma_axil_req_t fifo_req;
  dma_axil_resp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t(dma_axil_req_t),
      .axi4l_resp_t(dma_axil_resp_t),
      .ADDR_WIDTH  (6),
      .DATA_WIDTH  (32),
      .FIFO_SIZE  (2)
  ) u_axi4l_fifo (
      .clk_i    (clk_i),
      .arst_ni  (arst_ni),
      .slv_req_i(req_i),
      .slv_resp_o(resp_o),
      .mst_req_o(fifo_req),
      .mst_resp_i(fifo_resp)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic wr_en;
  logic rd_en;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE / READ FIRE — combinational
  ////////////////////////////////////////////////////////////////////////////////////////////////

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

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // READ DATA MUX — combinational
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    fifo_resp.r.data = '0;
    fifo_resp.r.resp = 2'b10;  // default SLVERR

    if (rd_en) begin
      case (fifo_req.ar.addr)

        DMA_SRC_ADDR_OFFSET: begin
          fifo_resp.r.data = dma_src_addr_o;
          fifo_resp.r.resp = 2'b00;
        end

        DMA_DST_ADDR_OFFSET: begin
          fifo_resp.r.data = dma_dst_addr_o;
          fifo_resp.r.resp = 2'b00;
        end

        DMA_NUM_WORDS_OFFSET: begin
          fifo_resp.r.data = dma_num_words_o;
          fifo_resp.r.resp = 2'b00;
        end

        DMA_REMAINING_OFFSET: begin
          fifo_resp.r.data = dma_remaining_i;
          fifo_resp.r.resp = 2'b00;
        end

        DMA_CTRL_OFFSET: begin
          fifo_resp.r.data = dma_ctrl_o;
          fifo_resp.r.resp = 2'b00;
        end

        DMA_STAT_OFFSET: begin
          fifo_resp.r.data = dma_stat_i;
          fifo_resp.r.resp = 2'b00;
        end

        default: begin
        end

      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE RESPONSE + REGISTER UPDATES — combinational & sequential
  // strb must be 4'b1111 — partial writes rejected
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    fifo_resp.b.resp = 2'b10;  // default SLVERR

    if (fifo_req.w.strb == 4'b1111 && wr_en) begin
      case (fifo_req.aw.addr)

        DMA_SRC_ADDR_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        DMA_DST_ADDR_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        DMA_NUM_WORDS_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        DMA_CTRL_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        default: begin
        end

      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL — Registers (SRC_ADDR, DST_ADDR, NUM_WORDS, CTRL)
  // Updates only when b.resp == OKAY (S1 pattern)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      dma_src_addr_o  <= '0;
      dma_dst_addr_o  <= '0;
      dma_num_words_o <= '0;
      dma_ctrl_o      <= '0;
    end else if (fifo_resp.b.resp == 2'b00) begin
      case (fifo_req.aw.addr)
        DMA_SRC_ADDR_OFFSET:  dma_src_addr_o  <= fifo_req.w.data;
        DMA_DST_ADDR_OFFSET:  dma_dst_addr_o  <= fifo_req.w.data;
        DMA_NUM_WORDS_OFFSET: dma_num_words_o <= fifo_req.w.data;
        DMA_CTRL_OFFSET:      dma_ctrl_o      <= fifo_req.w.data;
        default: begin
        end
      endcase
    end
  end

endmodule
