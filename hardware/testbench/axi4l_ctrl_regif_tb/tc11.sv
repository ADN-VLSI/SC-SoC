// tc11.sv -- TC11: DMA Register Bringup
//
// Verifies:
//   1. DMA source/destination/word-count reset values.
//   2. Aligned source/destination writes are accepted.
//   3. Misaligned source/destination writes are rejected (no realignment).
//   4. DMA idle interrupt reports idle when num_words == 0.
// -----------------------------------------------------------------------------
task automatic tc11(inout int p, inout int f);
  logic [31:0] rdata;
  logic [1:0]  resp;
  logic [31:0] src_before;
  logic [31:0] dst_before;
  p = 0; f = 0;

  $display("\n-- TC11: DMA Register Bringup --");

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

  // Aligned writes
  write_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), 32'h2000_0040, resp);
  check(resp === 2'b00, p, f, "DMA_SRC_ADDR aligned write resp=OKAY");
  write_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), 32'h2000_0080, resp);
  check(resp === 2'b00, p, f, "DMA_DST_ADDR aligned write resp=OKAY");
  write_32(reg_addr(CTRL_DMA_NUM_WORDS_OFFSET), 32'h0000_0010, resp);
  check(resp === 2'b00, p, f, "DMA_NUM_WORDS write resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_DMA_SRC_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_SRC_ADDR aligned read resp=OKAY");
  check(rdata === 32'h2000_0040, p, f, "DMA_SRC_ADDR aligned value retained");
  check(dma_src_addr_o === 32'h2000_0040, p, f, "dma_src_addr_o aligned value");

  read_32(reg_addr(CTRL_DMA_DST_ADDR_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_DST_ADDR aligned read resp=OKAY");
  check(rdata === 32'h2000_0080, p, f, "DMA_DST_ADDR aligned value retained");
  check(dma_dst_addr_o === 32'h2000_0080, p, f, "dma_dst_addr_o aligned value");

  read_32(reg_addr(CTRL_DMA_IDLE_IRQ_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_IDLE_IRQ active transfer read resp=OKAY");
  check(rdata === 32'h0000_0000, p, f, "DMA idle interrupt deasserted when words!=0");
  check(dma_idle_irq_o === 1'b0, p, f, "dma_idle_irq_o deasserted when words!=0");

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
  write_32(reg_addr(CTRL_DMA_NUM_WORDS_OFFSET), 32'h0000_0000, resp);
  check(resp === 2'b00, p, f, "DMA_NUM_WORDS clear write resp=OKAY");
  @(posedge clk_i);

  read_32(reg_addr(CTRL_DMA_IDLE_IRQ_OFFSET), rdata, resp);
  check(resp  === 2'b00, p, f, "DMA_IDLE_IRQ idle read resp=OKAY");
  check(rdata === 32'h0000_0001, p, f, "DMA idle interrupt asserted when words==0");
  check(dma_idle_irq_o === 1'b1, p, f, "dma_idle_irq_o asserted when words==0");

endtask
