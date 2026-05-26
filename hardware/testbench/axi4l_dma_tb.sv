`include "package/sc_soc_pkg.sv"

module axi4l_dma_tb;
  import sc_soc_pkg::*;

  logic clk_i;
  logic arst_ni;

  logic        dma_start_i;
  logic [31:0] dma_src_addr_i;
  logic [31:0] dma_dst_addr_i;
  logic [31:0] dma_num_words_i;
  logic        dma_busy_o;
  logic [31:0] dma_words_remaining_o;
  logic        dma_idle_irq_o;

  axil_req_t dma_req;
  axil_resp_t dma_resp;

  axi4l_dma #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t)
  ) u_dut (
      .clk_i                (clk_i),
      .arst_ni              (arst_ni),
      .dma_start_i          (dma_start_i),
      .dma_src_addr_i       (dma_src_addr_i),
      .dma_dst_addr_i       (dma_dst_addr_i),
      .dma_num_words_i      (dma_num_words_i),
      .dma_busy_o           (dma_busy_o),
      .dma_words_remaining_o(dma_words_remaining_o),
      .dma_idle_irq_o       (dma_idle_irq_o),
      .req_o                (dma_req),
      .resp_i               (dma_resp)
  );

  axi4l_mem #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) u_mem (
      .arst_ni     (arst_ni),
      .clk_i       (clk_i),
      .axi4l_req_i (dma_req),
      .axi4l_resp_o(dma_resp)
  );

  task automatic check(input logic ok, inout int pass_count, inout int fail_count, input string msg);
    if (ok) begin
      pass_count++;
      $display("  [PASS] %s", msg);
    end else begin
      fail_count++;
      $display("  [FAIL] %s", msg);
    end
  endtask

  task automatic ram_write(input int addr, input logic [31:0] data);
    logic [3:0][7:0] byte_data;
    int aligned_addr;
    aligned_addr = addr & 'hffff_fffc;
    byte_data = data;
    foreach (byte_data[i]) u_mem.mem[0][aligned_addr+i] = byte_data[i];
  endtask

  function automatic logic [31:0] ram_read(input int addr);
    logic [3:0][7:0] byte_data;
    int aligned_addr;
    aligned_addr = addr & 'hffff_fffc;
    foreach (byte_data[i]) byte_data[i] = u_mem.mem[0][aligned_addr+i];
    return byte_data;
  endfunction

  initial begin
    int p;
    int f;
    int cycles;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_dma_tb.vcd");
    $dumpvars(0, axi4l_dma_tb);

    clk_i          = 1'b0;
    arst_ni        = 1'b0;
    dma_start_i    = 1'b0;
    dma_src_addr_i = 32'h0000_0000;
    dma_dst_addr_i = 32'h0000_0000;
    dma_num_words_i = 32'h0000_0000;
    p = 0;
    f = 0;

    fork
      forever #5 clk_i = ~clk_i;
    join_none

    repeat (4) @(posedge clk_i);
    arst_ni <= 1'b1;
    @(posedge clk_i);

    check(dma_busy_o === 1'b0, p, f, "DMA starts idle");
    check(dma_idle_irq_o === 1'b1, p, f, "Idle IRQ asserted when DMA is idle");
    check(dma_words_remaining_o === 32'h0000_0000, p, f, "Words remaining resets to zero");

    ram_write('h0000_0040, 32'h1111_AAAA);
    ram_write('h0000_0044, 32'h2222_BBBB);
    ram_write('h0000_0048, 32'h3333_CCCC);
    ram_write('h0000_0080, 32'hDEAD_BEEF);
    ram_write('h0000_0084, 32'hDEAD_BEEF);
    ram_write('h0000_0088, 32'hDEAD_BEEF);

    dma_src_addr_i  <= 32'h0000_0040;
    dma_dst_addr_i  <= 32'h0000_0080;
    dma_num_words_i <= 32'h0000_0003;
    dma_start_i     <= 1'b1;
    @(posedge clk_i);
    dma_start_i <= 1'b0;

    cycles = 0;
    while ((dma_busy_o !== 1'b1) && (cycles < 20)) begin
      @(posedge clk_i);
      cycles++;
    end
    check(dma_busy_o === 1'b1, p, f, "DMA becomes busy after start");
    check(dma_idle_irq_o === 1'b0, p, f, "Idle IRQ deasserts during transfer");
    check(dma_words_remaining_o <= 32'h0000_0003, p, f, "Words remaining stays within transfer length");

    cycles = 0;
    while ((dma_busy_o !== 1'b0) && (cycles < 50)) begin
      @(posedge clk_i);
      cycles++;
    end
    check(dma_busy_o === 1'b0, p, f, "DMA completes transfer");
    check(dma_idle_irq_o === 1'b1, p, f, "Idle IRQ reasserts after transfer");
    check(dma_words_remaining_o === 32'h0000_0000, p, f, "Words remaining returns to zero");

    check(ram_read('h0000_0080) === 32'h1111_AAAA, p, f, "DMA copies word 0");
    check(ram_read('h0000_0084) === 32'h2222_BBBB, p, f, "DMA copies word 1");
    check(ram_read('h0000_0088) === 32'h3333_CCCC, p, f, "DMA copies word 2");

    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", p);
    $display("TOTAL FAIL = %0d", f);
    if (f == 0) $display("OVERALL: PASSED");
    else        $display("OVERALL: FAILED");

    repeat (10) @(posedge clk_i);
    $finish;
  end

endmodule
