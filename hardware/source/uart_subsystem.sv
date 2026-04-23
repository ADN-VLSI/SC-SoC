`include "package/uart_pkg.sv"
`include "package/uart_subsystem_pkg.sv"

module uart_subsystem #(
    parameter int FIFO_DEPTH = uart_subsystem_pkg::UART_FIFO_DEPTH
) (
    input  logic                     clk_i,
    input  logic                     arst_ni,

    input  uart_pkg::uart_axil_req_t req_i,
    output uart_pkg::uart_axil_resp_t resp_o,

    input  logic                     rx_i,
    output logic                     tx_o,
    output logic                     int_en_o
);

  import uart_pkg::*;

  localparam int FIFO_COUNT_W = $clog2(FIFO_DEPTH + 1);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // REGIF <-> CORE SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_ctrl_reg_t uart_ctrl;
  uart_cfg_reg_t  uart_cfg;
  uart_stat_reg_t uart_stat;
  uart_int_reg_t  uart_int_en;

  uart_data_t     tx_data_from_regif;
  logic           tx_data_valid_from_regif;
  logic           tx_data_ready_to_regif;

  uart_data_t     rx_data_to_regif;
  logic           rx_data_valid_to_regif;
  logic           rx_data_ready_from_regif;

  uart_count_t    tx_data_cnt;
  uart_count_t    rx_data_cnt;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCKS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic prescale_clk;
  logic tx_clk;
  logic rx_clk;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // TX FIFO SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic [7:0] tx_fifo_rd_data;
  logic       tx_fifo_rd_valid;
  logic       tx_fifo_rd_ready;
  logic [FIFO_COUNT_W-1:0] tx_fifo_wr_count;
  logic [FIFO_COUNT_W-1:0] tx_fifo_rd_count;

  logic tx_data_ready_from_uart;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // RX FIFO SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic [7:0] rx_data_from_uart;
  logic       rx_data_valid_from_uart;
  logic       rx_parity_error;

  logic [7:0] rx_fifo_rd_data;
  logic       rx_fifo_rd_valid;
  logic       rx_fifo_rd_ready;
  logic [FIFO_COUNT_W-1:0] rx_fifo_wr_count;
  logic [FIFO_COUNT_W-1:0] rx_fifo_rd_count;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // COUNT ADAPTATION FOR REGIF STATUS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    tx_data_cnt       = '0;
    rx_data_cnt       = '0;
    tx_data_cnt.count = tx_fifo_wr_count;
    rx_data_cnt.count = rx_fifo_rd_count;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // REGIF OUTPUTS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    rx_data_to_regif.data = rx_fifo_rd_data;
    rx_data_valid_to_regif = rx_fifo_rd_valid;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // AXI4-LITE UART REGIF
  // Keep original uploaded module unchanged.
  // Only instance naming uses axi4l wording.
  ////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_uart_regif #(
      
  ) u_axi4l_regif (
      .clk_i           (clk_i),
      .arst_ni         (arst_ni),
      .req_i           (req_i),
      .resp_o          (resp_o),
      .uart_ctrl_o     (uart_ctrl),
      .uart_cfg_o      (uart_cfg),
      .uart_stat_o     (uart_stat),
      .tx_data_o       (tx_data_from_regif),
      .tx_data_valid_o (tx_data_valid_from_regif),
      .tx_data_ready_i (tx_data_ready_to_regif),
      .rx_data_i       (rx_data_to_regif),
      .rx_data_valid_i (rx_data_valid_to_regif),
      .rx_data_ready_o (rx_data_ready_from_regif),
      .tx_data_cnt_i   (tx_data_cnt),
      .rx_data_cnt_i   (rx_data_cnt),
      .uart_int_en_o   (uart_int_en)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // CLOCK DIVIDER CHAIN
  ////////////////////////////////////////////////////////////////////////////////////////////////

  clk_div #(
      .DIV_WIDTH(4)
  ) u_prescaler_div (
      .arst_ni (arst_ni),
      .clk_i   (clk_i),
      .div_i   (uart_cfg.psclr),
      .clk_o   (prescale_clk)
  );

  clk_div #(
      .DIV_WIDTH(12)
  ) u_rx_clk_div (
      .arst_ni (arst_ni),
      .clk_i   (prescale_clk),
      .div_i   (uart_cfg.clk_div >> 3),
      .clk_o   (rx_clk)
  );

  clk_div #(
      .DIV_WIDTH(4)
  ) u_tx_clk_div (
      .arst_ni (arst_ni),
      .clk_i   (rx_clk),
      .div_i   ('d4),
      .clk_o   (tx_clk)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // TX CDC FIFO : clk_i -> tx_clk
  ////////////////////////////////////////////////////////////////////////////////////////////////

  cdc_fifo #(
      .DATA_WIDTH (8),
      .FIFO_DEPTH (FIFO_DEPTH)
  ) u_tx_cdc_fifo (
      .arst_ni    (arst_ni & ~uart_ctrl.tx_fifo_flush),
      .wr_clk_i   (clk_i),
      .wr_data_i  (tx_data_from_regif.data),
      .wr_valid_i (tx_data_valid_from_regif),
      .wr_ready_o (tx_data_ready_to_regif),
      .wr_count_o (tx_fifo_wr_count),
      .rd_clk_i   (tx_clk),
      .rd_ready_i (tx_fifo_rd_ready),
      .rd_valid_o (tx_fifo_rd_valid),
      .rd_data_o  (tx_fifo_rd_data),
      .rd_count_o (tx_fifo_rd_count)
  );


  ////////////////////////////////////////////////////////////////////////////////////////////////
  // UART TRANSMITTER
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_tx u_uart_tx (
      .clk_i         (tx_clk),
      .arst_ni       (arst_ni & ~uart_ctrl.tx_fifo_flush),
      .data_i        (tx_fifo_rd_data),
      .data_valid_i  (tx_fifo_rd_valid & uart_ctrl.tx_en),
      .data_bits_i   (uart_cfg.db),
      .parity_en_i   (uart_cfg.pen),
      .parity_type_i (uart_cfg.ptp),
      .extra_stop_i  (uart_cfg.sb),
      .tx_o          (tx_o),
      .data_ready_o  (tx_data_ready_from_uart)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // UART RECEIVER
  ////////////////////////////////////////////////////////////////////////////////////////////////

  uart_rx u_uart_rx (
      .clk_i          (rx_clk),
      .arst_ni        (arst_ni & ~uart_ctrl.rx_fifo_flush),
      .rx_i           (rx_i | ~uart_ctrl.rx_en),
      .data_bits_i    (uart_cfg.db),
      .parity_en_i    (uart_cfg.pen),
      .parity_type_i  (uart_cfg.ptp),
      .data_o         (rx_data_from_uart),
      .data_valid_o   (rx_data_valid_from_uart),
      .parity_error_o (rx_parity_error)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // RX CDC FIFO : rx_clk -> clk_i
  ////////////////////////////////////////////////////////////////////////////////////////////////

  cdc_fifo #(
      .DATA_WIDTH (8),
      .FIFO_DEPTH (FIFO_DEPTH)
  ) u_rx_cdc_fifo (
      .arst_ni    (arst_ni & ~uart_ctrl.rx_fifo_flush),
      .wr_clk_i   (rx_clk),
      .wr_data_i  (rx_data_from_uart),
      .wr_valid_i (rx_data_valid_from_uart),
      .wr_ready_o (),
      .wr_count_o (rx_fifo_wr_count),
      .rd_clk_i   (clk_i),
      .rd_ready_i (rx_fifo_rd_ready),
      .rd_valid_o (rx_fifo_rd_valid),
      .rd_data_o  (rx_fifo_rd_data),
      .rd_count_o (rx_fifo_rd_count)
  );

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // FIFO READY SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  always_comb begin
    tx_fifo_rd_ready = tx_data_ready_from_uart & uart_ctrl.tx_en;
    rx_fifo_rd_ready = rx_data_ready_from_regif;
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERRUPT OUTPUT
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic tx_empty_irq;
  logic tx_full_irq;
  logic rx_empty_irq;
  logic rx_full_irq;

  always_comb begin
    tx_empty_irq = uart_int_en.tx_empty_en & (tx_fifo_wr_count == '0);
    tx_full_irq  = uart_int_en.tx_full_en  & (tx_fifo_wr_count == FIFO_DEPTH);
    rx_empty_irq = uart_int_en.rx_empty_en & (rx_fifo_rd_count == '0);
    rx_full_irq  = uart_int_en.rx_full_en  & (rx_fifo_wr_count == FIFO_DEPTH);
    int_en_o     = tx_empty_irq | tx_full_irq | rx_empty_irq | rx_full_irq;
  end

endmodule