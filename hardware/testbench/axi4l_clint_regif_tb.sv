`include "package/clint_pkg.sv"

module axi4l_clint_regif_tb;
  import clint_pkg::*;

  logic clk_i;
  logic arst_ni;
  logic timer_en_i;

  logic        msip_irq_o;
  logic        timer_irq_o;
  logic [63:0] mtime_o;
  logic [63:0] mtimecmp_o;

  int pass_count;
  int fail_count;

  axi4l_if #(
      .req_t (clint_axil_req_t),
      .resp_t(clint_axil_resp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  axi4l_clint_regif #(
      .axil_req_t (clint_axil_req_t),
      .axil_resp_t(clint_axil_resp_t)
  ) u_dut (
      .clk_i      (clk_i),
      .arst_ni    (arst_ni),
      .timer_en_i (timer_en_i),
      .req_i      (intf.req),
      .resp_o     (intf.resp),
      .msip_irq_o (msip_irq_o),
      .timer_irq_o(timer_irq_o),
      .mtime_o    (mtime_o),
      .mtimecmp_o (mtimecmp_o)
  );

  task automatic check(input logic ok, input string msg);
    if (ok) begin
      pass_count++;
      $display("  [PASS] %s", msg);
    end else begin
      fail_count++;
      $display("  [FAIL] %s", msg);
    end
  endtask

  task automatic write_32(
      input  logic [15:0] addr,
      input  logic [31:0] data,
      output logic [ 1:0] resp
  );
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({data, 4'b1111});
      intf.recv_b(resp);
    join
  endtask

  task automatic write_32_strb(
      input  logic [15:0] addr,
      input  logic [31:0] data,
      input  logic [ 3:0] strb,
      output logic [ 1:0] resp
  );
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({data, strb});
      intf.recv_b(resp);
    join
  endtask

  task automatic read_32(
      input  logic [15:0] addr,
      output logic [31:0] data,
      output logic [ 1:0] resp
  );
    logic [33:0] r_bus;
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r(r_bus);
    join
    data = r_bus[33:2];
    resp = r_bus[1:0];
  endtask

  task automatic reset_dut();
    timer_en_i <= 1'b0;
    arst_ni    <= 1'b0;
    intf.req_reset();
    repeat (4) @(posedge clk_i);
    arst_ni <= 1'b1;
    repeat (4) @(posedge clk_i);
  endtask

  task automatic tc_reset_values();
    logic [31:0] data;
    logic [ 1:0] resp;

    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MSIP resets to zero");
    check(!msip_irq_o, "software interrupt is low after reset");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFFFF_FFFF, "MTIMECMP_LO resets to all ones");

    read_32(CLINT_MTIMECMP_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFFFF_FFFF, "MTIMECMP_HI resets to all ones");

    read_32(CLINT_MTIME_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MTIME_LO resets to zero");

    read_32(CLINT_MTIME_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MTIME_HI resets to zero");
    check(!timer_irq_o, "timer interrupt is low after reset");
  endtask

  task automatic tc_msip();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MSIP_OFFSET, 32'hFFFF_FFFF, resp);
    check(resp == 2'b00, "MSIP write returns OKAY");
    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0001, "MSIP stores only bit 0");
    check(msip_irq_o, "MSIP bit 0 asserts software interrupt");

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0000, resp);
    check(resp == 2'b00, "MSIP clear write returns OKAY");
    read_32(CLINT_MSIP_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0000_0000, "MSIP clears to zero");
    check(!msip_irq_o, "clearing MSIP deasserts software interrupt");
  endtask

  task automatic tc_64b_register_rw();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h89AB_CDEF, resp);
    check(resp == 2'b00, "MTIMECMP_LO write returns OKAY");
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0123_4567, resp);
    check(resp == 2'b00, "MTIMECMP_HI write returns OKAY");
    check(mtimecmp_o == 64'h0123_4567_89AB_CDEF, "MTIMECMP output is 64-bit assembled value");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h89AB_CDEF, "MTIMECMP_LO reads back");
    read_32(CLINT_MTIMECMP_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h0123_4567, "MTIMECMP_HI reads back");

    write_32(CLINT_MTIME_LO_OFFSET, 32'h7654_3210, resp);
    check(resp == 2'b00, "MTIME_LO write returns OKAY");
    write_32(CLINT_MTIME_HI_OFFSET, 32'hFEDC_BA98, resp);
    check(resp == 2'b00, "MTIME_HI write returns OKAY");
    check(mtime_o == 64'hFEDC_BA98_7654_3210, "MTIME output is 64-bit assembled value");

    read_32(CLINT_MTIME_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'h7654_3210, "MTIME_LO reads back");
    read_32(CLINT_MTIME_HI_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hFEDC_BA98, "MTIME_HI reads back");
  endtask

  task automatic tc_timer_count_and_irq();
    logic [ 1:0] resp;
    logic [63:0] start_time;

    write_32(CLINT_MTIME_LO_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIME_HI_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0003, resp);
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0000, resp);
    check(!timer_irq_o, "future MTIMECMP keeps timer interrupt low");

    start_time = mtime_o;
    timer_en_i <= 1'b1;
    repeat (3) @(posedge clk_i);
    #1;
    check(mtime_o == start_time + 64'd3, "MTIME increments by one per enabled clock");
    check(timer_irq_o, "MTIME reaching MTIMECMP asserts timer interrupt");

    timer_en_i <= 1'b0;
    start_time = mtime_o;
    repeat (3) @(posedge clk_i);
    #1;
    check(mtime_o == start_time, "MTIME stops when timer_en_i is low");

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0100, resp);
    check(resp == 2'b00 && !timer_irq_o, "writing a future MTIMECMP clears timer interrupt");
  endtask

  task automatic tc_error_responses();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32_strb(CLINT_MSIP_OFFSET, 32'h0000_0001, 4'b0001, resp);
    check(resp == 2'b10, "partial write returns SLVERR");

    write_32(16'h0004, 32'hDEAD_BEEF, resp);
    check(resp == 2'b10, "write to unmapped offset returns SLVERR");

    read_32(16'h0004, data, resp);
    check(resp == 2'b10 && data == 32'h0000_0000, "read from unmapped offset returns SLVERR and zero data");
  endtask

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    pass_count = 0;
    fail_count = 0;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_clint_regif_tb.vcd");
    $dumpvars(0, axi4l_clint_regif_tb);

    reset_dut();
    tc_reset_values();
    tc_msip();
    tc_64b_register_rw();
    tc_timer_count_and_irq();
    tc_error_responses();

    $display("axi4l_clint_regif_tb summary: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count != 0) $fatal(1, "axi4l_clint_regif_tb failed");
    $finish;
  end

endmodule
