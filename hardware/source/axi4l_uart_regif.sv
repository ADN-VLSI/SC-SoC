`include "package/uart_pkg.sv"

module axi4l_uart_regif

  import uart_pkg::uart_axil_req_t;
  import uart_pkg::uart_axil_rsp_t;
  import uart_pkg::uart_ctrl_reg_t;
  import uart_pkg::uart_cfg_reg_t;
  import uart_pkg::uart_stat_reg_t;
  import uart_pkg::uart_int_reg_t;
  import uart_pkg::uart_id_t;
  import uart_pkg::uart_data_t;
  import uart_pkg::uart_count_t;
  import uart_pkg::UART_CTRL_OFFSET;
  import uart_pkg::UART_CFG_OFFSET;
  import uart_pkg::UART_STAT_OFFSET;
  import uart_pkg::UART_TXR_OFFSET;
  import uart_pkg::UART_TXGP_OFFSET;
  import uart_pkg::UART_TXG_OFFSET;
  import uart_pkg::UART_TXD_OFFSET;
  import uart_pkg::UART_RXR_OFFSET;
  import uart_pkg::UART_RXGP_OFFSET;
  import uart_pkg::UART_RXG_OFFSET;
  import uart_pkg::UART_RXD_OFFSET;
  import uart_pkg::UART_INT_EN_OFFSET;

(
    input  logic clk_i,
    input  logic arst_ni,

    input  uart_axil_req_t  req_i,
    output uart_axil_rsp_t  resp_o,

    output uart_ctrl_reg_t  uart_ctrl_o,
    output uart_cfg_reg_t   uart_cfg_o,
    output uart_stat_reg_t  uart_stat_o,

    output uart_data_t      tx_data_o,
    output logic            tx_data_valid_o,
    input  logic            tx_data_ready_i,

    input  uart_data_t      rx_data_i,
    input  logic            rx_data_valid_i,
    output logic            rx_data_ready_o,

    input  uart_count_t     tx_data_cnt_i,
    input  uart_count_t     rx_data_cnt_i,

    output uart_int_reg_t   uart_int_en_o
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4L FIFO
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_axil_req_t fifo_req;
  uart_axil_rsp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t (uart_axil_req_t),
      .axi4l_rsp_t (uart_axil_rsp_t),
      .FIFO_SIZE   (2)
  ) u_axi4l_fifo (
      .clk_i    (clk_i),
      .arst_ni  (arst_ni),
      .slv_req_i(req_i),
      .slv_rsp_o(resp_o),
      .mst_req_o(fifo_req),
      .mst_rsp_i(fifo_resp)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic     wr_en;
  logic     rd_en;

  uart_id_t tx_id_in;
  logic     tx_id_in_valid;
  logic     tx_id_in_ready;
  uart_id_t tx_id_out;
  logic     tx_id_out_valid;
  logic     tx_id_out_ready;

  uart_id_t rx_id_in;
  logic     rx_id_in_valid;
  logic     rx_id_in_ready;
  uart_id_t rx_id_out;
  logic     rx_id_out_valid;
  logic     rx_id_out_ready;

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


  always_comb tx_data_o = fifo_req.w.data;
  always_comb tx_id_in  = fifo_req.w.data;
  always_comb rx_id_in  = fifo_req.w.data;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // READ DATA MUX — combinational
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    fifo_resp.r.data  = '0;
    fifo_resp.r.resp  = 2'b10;   // default SLVERR
    rx_data_ready_o   = 1'b0;
    tx_id_out_ready   = 1'b0;
    rx_id_out_ready   = 1'b0;

    case (fifo_req.ar.addr[5:0])

      UART_CTRL_OFFSET: begin
        fifo_resp.r.data = uart_ctrl_o;   
        fifo_resp.r.resp = 2'b00;
      end

      UART_CFG_OFFSET: begin
        fifo_resp.r.data = uart_cfg_o;
        fifo_resp.r.resp = 2'b00;
      end

      UART_STAT_OFFSET: begin
        fifo_resp.r.data = uart_stat_o;
        fifo_resp.r.resp = 2'b00;
      end

      UART_TXR_OFFSET: begin
        fifo_resp.r.data = '0;
        fifo_resp.r.resp = 2'b00;
      end

      UART_TXGP_OFFSET: begin
        if (tx_id_out_valid) begin
          fifo_resp.r.data = {'0, tx_id_out};  // 8-bit ID → 32-bit
          fifo_resp.r.resp = 2'b00;
          // tx_id_out_ready stays 0 — peek, no pop
        end
      end

      UART_TXG_OFFSET: begin
        if (tx_id_out_valid) begin
          fifo_resp.r.data = {'0, tx_id_out};
          fifo_resp.r.resp = 2'b00;
          tx_id_out_ready  = rd_en;   // consuming read — pop TXQ
        end
      end

      UART_TXD_OFFSET: begin
        fifo_resp.r.data = '0;
        fifo_resp.r.resp = 2'b00;
      end

      UART_RXR_OFFSET: begin
        fifo_resp.r.data = '0;
        fifo_resp.r.resp = 2'b00;
      end

      UART_RXGP_OFFSET: begin
        if (rx_id_out_valid) begin
          fifo_resp.r.data = {'0, rx_id_out};
          fifo_resp.r.resp = 2'b00;
          // rx_id_out_ready stays 0 — peek, no pop
        end
      end

      UART_RXG_OFFSET: begin
        if (rx_id_out_valid) begin
          fifo_resp.r.data = {'0, rx_id_out};
          fifo_resp.r.resp = 2'b00;
          rx_id_out_ready  = rd_en;   // consuming read — pop RXQ
        end
      end

      UART_RXD_OFFSET: begin
        if (rx_data_valid_i) begin
          fifo_resp.r.data = {'0, rx_data_i};  // 8-bit byte → 32-bit
          fifo_resp.r.resp = 2'b00;
          rx_data_ready_o  = rd_en;   // pop RX CDC FIFO
        end
      end

      UART_INT_EN_OFFSET: begin
        fifo_resp.r.data = uart_int_en_o;
        fifo_resp.r.resp = 2'b00;
      end

      default: begin end

    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE RESPONSE + WO PULSES — combinational
  // strb must be 4'b1111 — partial writes rejected
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    fifo_resp.b.resp = 2'b10;   // default SLVERR
    tx_data_valid_o  = 1'b0;
    tx_id_in_valid   = 1'b0;
    rx_id_in_valid   = 1'b0;

    if (fifo_req.w.strb == 4'b1111) begin
      case (fifo_req.aw.addr[5:0])

        UART_CTRL_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        UART_CFG_OFFSET: begin
          if (tx_data_cnt_i == '0 && rx_data_cnt_i == '0)
            fifo_resp.b.resp = 2'b00;
        end

        UART_TXR_OFFSET: begin
          if (tx_id_in_ready) begin
            fifo_resp.b.resp = 2'b00;
            tx_id_in_valid   = wr_en;
          end
        end

        UART_TXD_OFFSET: begin
          if (tx_data_ready_i) begin
            fifo_resp.b.resp = 2'b00;
            tx_data_valid_o  = wr_en;
          end
        end

        UART_RXR_OFFSET: begin
          if (rx_id_in_ready) begin
            fifo_resp.b.resp = 2'b00;
            rx_id_in_valid   = wr_en;
          end
        end

        UART_INT_EN_OFFSET: begin
          fifo_resp.b.resp = 2'b00;
        end

        default: begin end

      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL — CTRL CFG INT registers
  // Updates only when b.resp == OKAY (S1 pattern)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      uart_ctrl_o   <= '0;
      uart_cfg_o    <= 32'h0003_405B;
      uart_int_en_o <= '0;
    end else if (fifo_resp.b.resp == 2'b00) begin
      case (fifo_req.aw.addr[5:0])
        UART_CTRL_OFFSET:   uart_ctrl_o   <= fifo_req.w.data;
        UART_CFG_OFFSET:    uart_cfg_o    <= fifo_req.w.data;
        UART_INT_EN_OFFSET: uart_int_en_o <= fifo_req.w.data;
        default: begin end
      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_STAT — combinational from FIFO counts (not stored)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    uart_stat_o.reserved = '0;
    uart_stat_o.tx_cnt   = tx_data_cnt_i.count;
    uart_stat_o.tx_empty = (tx_data_cnt_i == '0);
    uart_stat_o.tx_full  = (tx_data_cnt_i.count == 10'd512);
    uart_stat_o.rx_cnt   = rx_data_cnt_i.count;
    uart_stat_o.rx_empty = (rx_data_cnt_i == '0);
    uart_stat_o.rx_full  = (rx_data_cnt_i.count == 10'd512);
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // TXQ_fifo — TX arbitration (TXR push / TXGP peek / TXG pop)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  fifo #(
      .FIFO_SIZE        (3),
      .DATA_WIDTH       ($bits(uart_id_t)),
      .ALLOW_FALLTHROUGH(1)
  ) u_tx_id_queue (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (tx_id_in),
      .data_in_valid_i (tx_id_in_valid),
      .data_in_ready_o (tx_id_in_ready),
      .data_out_o      (tx_id_out),
      .data_out_valid_o(tx_id_out_valid),
      .data_out_ready_i(tx_id_out_ready),
      .count_o         ()
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // RXQ_fifo — RX arbitration (RXR push / RXGP peek / RXG pop)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  fifo #(
      .FIFO_SIZE        (3),
      .DATA_WIDTH       ($bits(uart_id_t)),
      .ALLOW_FALLTHROUGH(1)
  ) u_rx_id_queue (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (rx_id_in),
      .data_in_valid_i (rx_id_in_valid),
      .data_in_ready_o (rx_id_in_ready),
      .data_out_o      (rx_id_out),
      .data_out_valid_o(rx_id_out_valid),
      .data_out_ready_i(rx_id_out_ready),
      .count_o         ()
  );

endmodule
