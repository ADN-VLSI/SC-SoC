// tc11.sv -- TC11: DMA Register + Status Plumbing
//
// Verifies:
//   1. DMA source/destination/word-count reset values.
//   2. Aligned source/destination writes are accepted.
//   3. Misaligned source/destination writes are rejected (no realignment).
//   4. DMA start pulse/status readback plumbing is exposed through CTRL space.
// -----------------------------------------------------------------------------
task automatic tc11(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  logic [31:0] src_before;
  logic [31:0] dst_before;
  logic        start_pulse_observed;
  logic        start_pulse_timeout;
  p = 0; f = 0;

  $display("\n-- TC11: DMA Register + Status Plumbing --");

  // Reset defaults
  read_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_SRC_ADDR reset read resp=OKAY");
  check(rdata === CTRL_DMA_SRC_ADDR_RESET, p, f, "DMA_SRC_ADDR reset value");

  read_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_DST_ADDR reset read resp=OKAY");
  check(rdata === CTRL_DMA_DST_ADDR_RESET, p, f, "DMA_DST_ADDR reset value");

  read_32(reg_addr(CTRL_DMA_NUM_WORDS_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_NUM_WORDS reset read resp=OKAY");
  check(rdata === CTRL_DMA_NUM_WORDS_RESET, p, f, "DMA_NUM_WORDS reset value");

  read_32(reg_addr(CTRL_DMA_IDLE_IRQ_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_IDLE_IRQ reset read resp=OKAY");
  check(rdata === 32'h0000_0001, p, f, "DMA idle interrupt asserted at reset");
  check(dma_idle_irq_o === 1'b1, p, f, "dma_idle_irq_o asserted at reset");

  read_32(reg_addr(CTRL_DMA_BUSY_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_BUSY reset read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA busy deasserted at reset");

  read_32(reg_addr(CTRL_DMA_WORDS_REMAINING_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_WORDS_REMAINING reset read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA words remaining reset value");

  // Aligned writes
  write_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), 32'h2000_0040, resp);
  check(resp === 2'b00, p, f, "DMA_SRC_ADDR aligned write resp=OKAY");
  write_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), 32'h2000_0080, resp);
  check(resp === 2'b00, p, f, "DMA_DST_ADDR aligned write resp=OKAY");
  start_pulse_observed = 1'b0;
  start_pulse_timeout  = 1'b0;
  fork
    begin
      write_32(reg_addr(CTRL_DMA_NUM_WORDS_OFFSET), 32'h0000_0010, resp);
    end
    begin
      @(posedge dma_start_pulse_o);
      start_pulse_observed = 1'b1;
    end
    begin
      repeat (20) @(posedge clk_i);
      if (!start_pulse_observed) start_pulse_timeout = 1'b1;
    end
  join
  check(resp === 2'b00, p, f, "DMA_NUM_WORDS write resp=OKAY");
  check(start_pulse_observed === 1'b1, p, f, "DMA start pulse asserted on non-zero length write");
  check(start_pulse_timeout === 1'b0, p, f, "DMA start pulse observed before timeout");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_SRC_ADDR aligned read resp=OKAY");
  check(rdata === 32'h2000_0040, p, f, "DMA_SRC_ADDR aligned value retained");
  check(dma_src_addr_o === 32'h2000_0040, p, f, "dma_src_addr_o aligned value");

  read_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_DST_ADDR aligned read resp=OKAY");
  check(rdata === 32'h2000_0080, p, f, "DMA_DST_ADDR aligned value retained");
  check(dma_dst_addr_o === 32'h2000_0080, p, f, "dma_dst_addr_o aligned value");

  dma_busy_i            <= 1'b1;
  dma_words_remaining_i <= 32'h0000_0010;
  @(posedge clk_i);

  read_32(reg_addr(CTRL_DMA_BUSY_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_BUSY active read resp=OKAY");
  check(rdata === 32'h0000_0001, p, f, "DMA busy asserted when status input is high");

  read_32(reg_addr(CTRL_DMA_WORDS_REMAINING_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_WORDS_REMAINING active read resp=OKAY");
  check(rdata === 32'h0000_0010, p, f, "DMA words remaining mirrors status input");

  read_32(reg_addr(CTRL_DMA_IDLE_IRQ_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_IDLE_IRQ active transfer read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA idle interrupt deasserted when busy=1");
  check(dma_idle_irq_o === 1'b0, p, f, "dma_idle_irq_o deasserted when busy=1");

  // Misaligned writes must be rejected and values must not change
  read_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), src_before, resp);
  read_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), dst_before, resp);

  fork
    send_aw_w(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), 32'h2000_0041, 4'b1111);
    intf.recv_b(resp);
  join
  check(resp === 2'b10, p, f, "DMA_SRC_ADDR misaligned write resp=SLVERR");

  fork
    send_aw_w(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), 32'h2000_0082, 4'b1111);
    intf.recv_b(resp);
  join
  check(resp === 2'b10, p, f, "DMA_DST_ADDR misaligned write resp=SLVERR");

  read_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_SRC_ADDR post-misaligned read resp=OKAY");
  check(rdata === src_before, p, f, "DMA_SRC_ADDR unchanged after misaligned write");

  read_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_DST_ADDR post-misaligned read resp=OKAY");
  check(rdata === dst_before, p, f, "DMA_DST_ADDR unchanged after misaligned write");

  // Return to idle
  dma_busy_i            <= 1'b0;
  dma_words_remaining_i <= 32'h0000_0000;
  write_32(reg_addr(CTRL_DMA_NUM_WORDS_OFFSET), 32'h0000_0000, resp);
  check(resp === 2'b00, p, f, "DMA_NUM_WORDS clear write resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_DMA_BUSY_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_BUSY idle read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA busy deasserted when idle");

  read_32(reg_addr(CTRL_DMA_WORDS_REMAINING_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_WORDS_REMAINING idle read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA words remaining returns to zero");

  read_32(reg_addr(CTRL_DMA_IDLE_IRQ_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_IDLE_IRQ idle read resp=OKAY");
  check(rdata === 32'h0000_0001, p, f, "DMA idle interrupt asserted when busy==0");
  check(dma_idle_irq_o === 1'b1, p, f, "dma_idle_irq_o asserted when busy==0");

endtask
