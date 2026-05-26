module axi4l_dma #(
    parameter type axil_req_t  = logic,
    parameter type axil_resp_t = logic,
    parameter int  FIFO_SIZE   = 2
) (
    input logic clk_i,
    input logic arst_ni,

    input logic        dma_start_i,
    input logic [31:0] dma_src_addr_i,
    input logic [31:0] dma_dst_addr_i,
    input logic [31:0] dma_num_words_i,

    output logic        dma_busy_o,
    output logic [31:0] dma_words_remaining_o,
    output logic        dma_idle_irq_o,

    output axil_req_t  req_o,
    input  axil_resp_t resp_i
);

  localparam int FIFO_DEPTH = 2 ** FIFO_SIZE;

  logic [31:0] src_base_addr_q;
  logic [31:0] dst_base_addr_q;
  logic [31:0] total_words_q;
  logic [31:0] src_words_issued_q;
  logic [31:0] dst_words_issued_q;
  logic [31:0] words_completed_q;
  logic [FIFO_SIZE:0] reads_inflight_q;
  logic dma_busy_q;

  logic [35:0] write_fifo_in;
  logic [35:0] write_fifo_out;
  logic        write_fifo_in_valid;
  logic        write_fifo_in_ready;
  logic        write_fifo_out_valid;
  logic        write_fifo_out_ready;
  logic [FIFO_SIZE:0] write_fifo_count;

  logic [31:0] src_addr;
  logic [31:0] dst_addr;
  logic [FIFO_SIZE+1:0] buffered_words;
  logic                  src_agu_valid;
  logic                  dst_agu_valid;
  logic                  ar_handshake;
  logic                  r_handshake;
  logic                  do_write;
  logic                  b_handshake;

  assign dma_busy_o            = dma_busy_q;
  assign dma_words_remaining_o = dma_busy_q ? (total_words_q - words_completed_q) : 32'h0000_0000;
  assign dma_idle_irq_o        = ~dma_busy_q;

  assign src_addr = src_base_addr_q + (src_words_issued_q << 2);
  assign dst_addr = dst_base_addr_q + (dst_words_issued_q << 2);

  assign buffered_words = {{1'b0}, write_fifo_count} + {{1'b0}, reads_inflight_q};
  assign src_agu_valid  = dma_busy_q && (src_words_issued_q < total_words_q) &&
      (buffered_words < FIFO_DEPTH);
  assign dst_agu_valid  = dma_busy_q && (dst_words_issued_q < total_words_q);

  assign ar_handshake = src_agu_valid && resp_i.ar_ready;
  assign r_handshake  = write_fifo_in_valid && write_fifo_in_ready;
  assign do_write     = dst_agu_valid && resp_i.aw_ready && write_fifo_out_valid && resp_i.w_ready;
  assign b_handshake  = dma_busy_q && resp_i.b_valid && req_o.b_ready;

  assign write_fifo_in       = {(resp_i.r.resp == 2'b00) ? 4'hF : 4'h0, resp_i.r.data};
  assign write_fifo_in_valid = dma_busy_q && resp_i.r_valid;
  assign write_fifo_out_ready = do_write;

  fifo #(
      .FIFO_SIZE        (FIFO_SIZE),
      .DATA_WIDTH       (36),
      .ALLOW_FALLTHROUGH(0)
  ) u_write_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (write_fifo_in),
      .data_in_valid_i (write_fifo_in_valid),
      .data_in_ready_o (write_fifo_in_ready),
      .data_out_o      (write_fifo_out),
      .data_out_valid_o(write_fifo_out_valid),
      .data_out_ready_i(write_fifo_out_ready),
      .count_o         (write_fifo_count)
  );

  always_comb begin
    req_o = '0;

    req_o.ar.addr  = src_addr;
    req_o.ar.prot  = 3'b000;
    req_o.ar_valid = src_agu_valid;

    req_o.r_ready = dma_busy_q && write_fifo_in_ready;

    req_o.aw.addr  = dst_addr;
    req_o.aw.prot  = 3'b000;
    req_o.aw_valid = do_write;

    req_o.w.data  = write_fifo_out[31:0];
    req_o.w.strb  = write_fifo_out[35:32];
    req_o.w_valid = do_write;

    req_o.b_ready = dma_busy_q;
  end

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      dma_busy_q          <= 1'b0;
      src_base_addr_q     <= 32'h0000_0000;
      dst_base_addr_q     <= 32'h0000_0000;
      total_words_q       <= 32'h0000_0000;
      src_words_issued_q  <= 32'h0000_0000;
      dst_words_issued_q  <= 32'h0000_0000;
      words_completed_q   <= 32'h0000_0000;
      reads_inflight_q    <= '0;
    end else if (dma_start_i && !dma_busy_q && (dma_num_words_i != 32'h0000_0000)) begin
      dma_busy_q          <= 1'b1;
      src_base_addr_q     <= dma_src_addr_i;
      dst_base_addr_q     <= dma_dst_addr_i;
      total_words_q       <= dma_num_words_i;
      src_words_issued_q  <= 32'h0000_0000;
      dst_words_issued_q  <= 32'h0000_0000;
      words_completed_q   <= 32'h0000_0000;
      reads_inflight_q    <= '0;
    end else if (dma_busy_q) begin
      if (ar_handshake) begin
        src_words_issued_q <= src_words_issued_q + 32'd1;
      end

      if (do_write) begin
        dst_words_issued_q <= dst_words_issued_q + 32'd1;
      end

      case ({
        ar_handshake, r_handshake
      })
        2'b10: reads_inflight_q <= reads_inflight_q + 1'b1;
        2'b01: reads_inflight_q <= reads_inflight_q - 1'b1;
        default: begin
        end
      endcase

      if (b_handshake) begin
        words_completed_q <= words_completed_q + 32'd1;
        if ((words_completed_q + 32'd1) == total_words_q) begin
          dma_busy_q <= 1'b0;
        end
      end
    end
  end

endmodule
