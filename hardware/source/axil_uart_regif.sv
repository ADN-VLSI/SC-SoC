// Module: axil_uart_regif
//
// AXI4-Lite UART Register Interface for SC-SoC project.
// Follows S1 reference design pattern with packed structs.
//
// Internal structure:
//   1. axi4l_fifo  — buffers all 5 AXI channels (like S1 axi_fifo)
//   2. Write logic — combinational, fires when aw_valid+w_valid+b_ready
//   3. Read  logic — combinational, fires when ar_valid+r_ready
//   4. always_ff  — updates CTRL/CFG/INT only when b.resp==OKAY
//   5. TX ID queue — fifo.sv for TXR/TXGP/TXG arbitration
//   6. RX ID queue — fifo.sv for RXR/RXGP/RXG arbitration

`include "axi4l/typedef.svh"

module axil_uart_regif

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

    // ── AXI4-Lite interface (struct ports) ───────────────────
    input  uart_axil_req_t       req_i,
    output uart_axil_rsp_t       resp_o,

    // ── UART control register outputs ────────────────────────
    output uart_ctrl_reg_t       uart_ctrl_o,  // → clk_div, uart_tx, uart_rx
    output uart_cfg_reg_t        uart_cfg_o,   // → clk_div, uart_tx, uart_rx
    output uart_stat_reg_t       uart_stat_o,  // → driven by FIFO hardware

    // ── TX data path ─────────────────────────────────────────
    output uart_data_t           tx_data_o,
    output logic                 tx_data_valid_o,
    input  logic                 tx_data_ready_i,  // TX FIFO not full

    // ── RX data path ─────────────────────────────────────────
    input  uart_data_t           rx_data_i,
    input  logic                 rx_data_valid_i,  // RX FIFO not empty
    output logic                 rx_data_ready_o,  // pop RX FIFO

    // ── FIFO count inputs — for UART_STAT and CFG gate ───────
    input  uart_count_t          tx_data_cnt_i,
    input  uart_count_t          rx_data_cnt_i,
    // ── Interrupt enable register output ─────────────────────
    output uart_int_reg_t        uart_int_en_o
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4L FIFO — buffered request/response
  // CPU → req_i/resp_o (slave side)
  // Register logic ← fifo_req/fifo_resp (master side)
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_axil_req_t fifo_req;
  uart_axil_rsp_t fifo_resp;

  axi4l_fifo #(
      .axi4l_req_t(uart_axil_req_t),
      .axi4l_rsp_t(uart_axil_rsp_t),
      .FIFO_SIZE  (2)
  ) u_axi4l_fifo (
      .clk_i    (clk_i),
      .rst_ni   (arst_ni),
      .slv_req_i(req_i),
      .slv_rsp_o(resp_o),
      .mst_req_o(fifo_req),
      .mst_rsp_i(fifo_resp)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic wr_en;
  logic rd_en;

  // TX ID queue signals
  uart_id_t  tx_id_in;
  logic      tx_id_in_valid;
  logic      tx_id_in_ready;
  uart_id_t  tx_id_out;
  logic      tx_id_out_valid;
  logic      tx_id_out_ready;

  // RX ID queue signals
  uart_id_t  rx_id_in;
  logic      rx_id_in_valid;
  logic      rx_id_in_ready;
  uart_id_t  rx_id_out;
  logic      rx_id_out_valid;
  logic      rx_id_out_ready;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE / READ FIRE — purely combinational, S1 style
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
  // WO COMBINATIONAL OUTPUTS — wired directly from write data
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb tx_data_o = fifo_req.w.data;   // full 32-bit word; only [7:0] used
  always_comb tx_id_in  = fifo_req.w.data;   // [7:0] is master ID
  always_comb rx_id_in  = fifo_req.w.data;   // [7:0] is master ID

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // READ DATA MUX — combinational
  // Uses packed struct fields directly — cleaner than bit indexing
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    fifo_resp.r.data  = '0;
    fifo_resp.r.resp  = 2'b10;    // default SLVERR
    rx_data_ready_o   = 1'b0;
    tx_id_out_ready   = 1'b0;
    rx_id_out_ready   = 1'b0;

    case (fifo_req.ar.addr[5:0])

      UART_CTRL_OFFSET: begin
        fifo_resp.r.data = {'0, uart_ctrl_o};
        fifo_resp.r.resp = 2'b00;
      end

      UART_CFG_OFFSET: begin
        fifo_resp.r.data = {'0, uart_cfg_o};
        fifo_resp.r.resp = 2'b00;
      end

      UART_STAT_OFFSET: begin
        fifo_resp.r.data = {'0, uart_stat_o};
        fifo_resp.r.resp = 2'b00;
      end

      UART_TXR_OFFSET: begin
        fifo_resp.r.data = '0;
        fifo_resp.r.resp = 2'b00;
      end

      UART_TXGP_OFFSET: begin
        if (tx_id_out_valid) begin
          fifo_resp.r.data = {'0, tx_id_out};
          fifo_resp.r.resp = 2'b00;
        end
      end

      UART_TXG_OFFSET: begin
        if (tx_id_out_valid) begin
          fifo_resp.r.data = {'0, tx_id_out};
          fifo_resp.r.resp = 2'b00;
          tx_id_out_ready  = rd_en;   // consuming — pop TX ID queue
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
        end
      end

      UART_RXG_OFFSET: begin
        if (rx_id_out_valid) begin
          fifo_resp.r.data = {'0, rx_id_out};
          fifo_resp.r.resp = 2'b00;
          rx_id_out_ready  = rd_en;   // consuming — pop RX ID queue
        end
      end

      UART_RXD_OFFSET: begin
        if (rx_data_valid_i) begin
          fifo_resp.r.data = {'0, rx_data_i};
          fifo_resp.r.resp = 2'b00;
          rx_data_ready_o  = rd_en;   // pop RX data FIFO
        end
      end

      UART_INT_EN_OFFSET: begin
        fifo_resp.r.data = {'0, uart_int_en_o};
        fifo_resp.r.resp = 2'b00;
      end

      default: begin end

    endcase
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // WRITE RESPONSE + WO PULSES — combinational
  // Only full-word writes (strb==4'b1111) accepted
  // CFG only when both FIFOs empty — prevent mid-transfer baud change
  // TXD only when TX FIFO has space
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
          // CFG only writable when both FIFOs are empty
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
  // SEQUENTIAL — RW register updates
  // S1 pattern: only update when fifo_resp.b.resp == OKAY
  // uart_stat_o is driven by hardware inputs — not stored here
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      uart_ctrl_o   <= '0;                   // reset = 0x00000000
      uart_cfg_o    <= 32'h0003_405B;        // reset = 0x0003405B
      uart_int_en_o <= '0;                   // reset = 0x00000000
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
  // UART_STAT — driven combinationally from hardware inputs
  // Not stored — always reflects live FIFO state
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    uart_stat_o.reserved = '0;
    uart_stat_o.rx_full  = rx_data_cnt_i.count == 10'd512; // approximated
    uart_stat_o.rx_empty = (rx_data_cnt_i == '0);
    uart_stat_o.tx_full  = tx_data_cnt_i.count == 10'd512; // approximated
    uart_stat_o.tx_empty = (tx_data_cnt_i == '0);
    uart_stat_o.rx_cnt   = rx_data_cnt_i.count;
    uart_stat_o.tx_cnt   = tx_data_cnt_i.count;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // TX ID QUEUE — TXR write pushes, TXGP peeks, TXG pops
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
  // RX ID QUEUE — RXR write pushes, RXGP peeks, RXG pops
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
