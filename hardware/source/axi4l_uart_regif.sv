`include "package/uart_pkg.sv"
`include "package/uart_subsystem_pkg.sv"

module axi4l_uart_regif

  import uart_pkg::uart_axil_req_t;
  import uart_pkg::uart_axil_resp_t;
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
  import uart_subsystem_pkg::UART_FIFO_DEPTH;
  import uart_subsystem_pkg::UART_FIFO_COUNT_W;

(
    input logic clk_i,
    input logic arst_ni,

    input  uart_axil_req_t req_i,
    output uart_axil_resp_t resp_o,

    output uart_ctrl_reg_t uart_ctrl_o,
    output uart_cfg_reg_t  uart_cfg_o,
    output uart_stat_reg_t uart_stat_o,

    output uart_data_t tx_data_o,
    output logic       tx_data_valid_o,
    input  logic       tx_data_ready_i,

    input  uart_data_t rx_data_i,
    input  logic       rx_data_valid_i,
    output logic       rx_data_ready_o,

    input uart_count_t tx_data_cnt_i,
    input uart_count_t rx_data_cnt_i,
    input logic        tx_uart_idle_i,

    output uart_int_reg_t uart_int_en_o
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4L FIFO
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_axil_req_t fifo_req;
  uart_axil_resp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t(uart_axil_req_t),
      .axi4l_resp_t(uart_axil_resp_t),
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

  logic [5:0] mem_waddr;
  logic [31:0] mem_wdata;
  logic [3:0] mem_wstrb;
  logic mem_wenable;
  logic mem_werror;
  logic [5:0] mem_raddr;
  logic [31:0] mem_rdata;
  logic mem_rerror;
  logic mem_write_ok;
  logic mem_read_active;
  logic mem_wnsecure_unused;
  logic mem_rnsecure_unused;
  uart_axil_resp_t mem_resp;

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
  // AXI4-Lite to local memory-interface bridge
  ////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_to_memif #(
      .axi4l_req_t (uart_axil_req_t),
      .axi4l_resp_t(uart_axil_resp_t),
      .ADDR_WIDTH  (6),
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


  always_comb tx_data_o = mem_wdata;
  always_comb tx_id_in  = mem_wdata;
  always_comb rx_id_in  = mem_wdata;
  always_comb mem_read_active = mem_resp.r_valid && mem_resp.ar_ready;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // READ DATA MUX — combinational
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    mem_rdata      = '0;
    mem_rerror     = 1'b1;
    rx_data_ready_o  = 1'b0;
    tx_id_out_ready  = 1'b0;
    rx_id_out_ready  = 1'b0;

    if (mem_read_active) begin
      case (mem_raddr)

        UART_CTRL_OFFSET: begin
          mem_rdata  = uart_ctrl_o;
          mem_rerror = 1'b0;
        end

        UART_CFG_OFFSET: begin
          mem_rdata  = uart_cfg_o;
          mem_rerror = 1'b0;
        end

        UART_STAT_OFFSET: begin
          mem_rdata  = uart_stat_o;
          mem_rerror = 1'b0;
        end

        UART_TXR_OFFSET: begin
          mem_rdata  = '0;
          mem_rerror = 1'b0;
        end

        UART_TXGP_OFFSET: begin
          if (tx_id_out_valid) begin
            mem_rdata  = {'0, tx_id_out};  // 8-bit ID → 32-bit
            mem_rerror = 1'b0;
            // tx_id_out_ready stays 0 — peek, no pop
          end
        end

        UART_TXG_OFFSET: begin
          if (tx_id_out_valid) begin
            mem_rdata = {'0, tx_id_out};
            mem_rerror = 1'b0;
            tx_id_out_ready  = '1;  // consuming read — pop TXQ
          end
        end

        UART_TXD_OFFSET: begin
          mem_rdata  = '0;
          mem_rerror = 1'b0;
        end

        UART_RXR_OFFSET: begin
          mem_rdata  = '0;
          mem_rerror = 1'b0;
        end

        UART_RXGP_OFFSET: begin
          if (rx_id_out_valid) begin
            mem_rdata  = {'0, rx_id_out};
            mem_rerror = 1'b0;
            // rx_id_out_ready stays 0 — peek, no pop
          end
        end

        UART_RXG_OFFSET: begin
          if (rx_id_out_valid) begin
            mem_rdata = {'0, rx_id_out};
            mem_rerror = 1'b0;
            rx_id_out_ready  = '1;  // consuming read — pop RXQ
          end
        end

        UART_RXD_OFFSET: begin
          if (rx_data_valid_i) begin
            mem_rdata = {'0, rx_data_i};  // 8-bit byte → 32-bit
            mem_rerror = 1'b0;
            rx_data_ready_o  = '1;  // pop RX CDC FIFO
          end
        end

        UART_INT_EN_OFFSET: begin
          mem_rdata  = uart_int_en_o;
          mem_rerror = 1'b0;
        end

        default: begin
        end

      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE ERROR + WO PULSES — combinational
  // strb must be 4'b1111 — partial writes rejected
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    mem_werror      = 1'b1;
    tx_data_valid_o  = 1'b0;
    tx_id_in_valid   = 1'b0;
    rx_id_in_valid   = 1'b0;

    // axi4l_to_memif intentionally does not enforce byte strobe policy.
    // This register interface requires full-word writes only.
    if (mem_wstrb == 4'b1111 && mem_wenable) begin
      case (mem_waddr)

        UART_CTRL_OFFSET: begin
          mem_werror = 1'b0;
        end

        UART_CFG_OFFSET: begin
          if (tx_data_cnt_i == '0 && rx_data_cnt_i == '0) mem_werror = 1'b0;
        end

        UART_TXR_OFFSET: begin
          if (tx_id_in_ready) begin
            mem_werror      = 1'b0;
            tx_id_in_valid   = '1;
          end
        end

        UART_TXD_OFFSET: begin
          if (tx_data_ready_i) begin
            mem_werror      = 1'b0;
            tx_data_valid_o  = '1;
          end
        end

        UART_RXR_OFFSET: begin
          if (rx_id_in_ready) begin
            mem_werror      = 1'b0;
            rx_id_in_valid   = '1;
          end
        end

        UART_INT_EN_OFFSET: begin
          mem_werror = 1'b0;
        end

        default: begin
        end

      endcase
    end
  end

  always_comb mem_write_ok = mem_wenable && !mem_werror;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SEQUENTIAL — CTRL CFG INT registers
  // Updates only when b.resp == OKAY (S1 pattern)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      uart_ctrl_o   <= '0;
      uart_cfg_o    <= 32'h0003_405B;
      uart_int_en_o <= '0;
    end else if (mem_write_ok) begin
      case (mem_waddr)
        UART_CTRL_OFFSET: uart_ctrl_o <= mem_wdata;
        UART_CFG_OFFSET: uart_cfg_o <= mem_wdata;
        UART_INT_EN_OFFSET: uart_int_en_o <= mem_wdata;
        default: begin
        end
      endcase
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // UART_STAT — combinational from FIFO counts (not stored)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    uart_stat_o.reserved = '0;
    uart_stat_o.tx_cnt   = tx_data_cnt_i.count;
    uart_stat_o.tx_empty = (tx_data_cnt_i == '0) & tx_uart_idle_i;
    uart_stat_o.tx_full  = (tx_data_cnt_i.count == uart_subsystem_pkg::UART_FIFO_DEPTH);
    uart_stat_o.rx_cnt   = rx_data_cnt_i.count;
    uart_stat_o.rx_empty = (rx_data_cnt_i == '0);
    uart_stat_o.rx_full  = (rx_data_cnt_i.count == uart_subsystem_pkg::UART_FIFO_DEPTH);
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
