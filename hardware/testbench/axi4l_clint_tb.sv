`include "package/clint_pkg.sv"

module axi4l_clint_tb;
  import clint_pkg::*;

  logic clk_i;
  logic arst_ni;
  logic timer_en_i;
  logic ext_irq_i;

  logic [31:0] irq_o;
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

  axi4l_clint #(
      .axil_req_t (clint_axil_req_t),
      .axil_resp_t(clint_axil_resp_t)
  ) u_dut (
      .clk_i       (clk_i),
      .arst_ni     (arst_ni),
      .timer_en_i  (timer_en_i),
      .axi4l_req_i (intf.req),
      .axi4l_resp_o(intf.resp),
      .ext_irq_i   (ext_irq_i),
      .irq_o       (irq_o),
      .msip_irq_o  (msip_irq_o),
      .timer_irq_o (timer_irq_o),
      .mtime_o     (mtime_o),
      .mtimecmp_o  (mtimecmp_o)
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
    ext_irq_i  <= 1'b0;
    arst_ni    <= 1'b0;
    intf.req_reset();
    repeat (4) @(posedge clk_i);
    arst_ni <= 1'b1;
    repeat (4) @(posedge clk_i);
  endtask

  task automatic tc_irq_vector_packing();
    logic [1:0] resp;

    check(irq_o == 32'h0000_0000, "IRQ vector resets low");

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0001, resp);
    check(resp == 2'b00, "MSIP write through wrapper returns OKAY");
    check(msip_irq_o && irq_o[3], "MSIP maps to irq_o[3]");
    check(!irq_o[7] && !irq_o[11], "timer and external IRQ bits remain low");

    ext_irq_i <= 1'b1;
    #1;
    check(irq_o[11], "external interrupt input maps to irq_o[11]");

    write_32(CLINT_MTIME_LO_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIME_HI_OFFSET, 32'h0000_0000, resp);
    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'h0000_0001, resp);
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0000, resp);

    timer_en_i <= 1'b1;
    repeat (1) @(posedge clk_i);
    #1;
    check(timer_irq_o && irq_o[7], "timer interrupt maps to irq_o[7]");
    check(irq_o[3] && irq_o[7] && irq_o[11], "wrapper can present MSIP, MTIP, and MEIP together");
  endtask

  task automatic tc_register_access_through_wrapper();
    logic [31:0] data;
    logic [ 1:0] resp;

    write_32(CLINT_MSIP_OFFSET, 32'h0000_0000, resp);
    check(resp == 2'b00 && !irq_o[3], "clearing MSIP through wrapper clears irq_o[3]");

    write_32(CLINT_MTIMECMP_LO_OFFSET, 32'hCAFE_BABE, resp);
    write_32(CLINT_MTIMECMP_HI_OFFSET, 32'h0000_0002, resp);
    check(mtimecmp_o == 64'h0000_0002_CAFE_BABE, "wrapper exposes 64-bit MTIMECMP output");

    read_32(CLINT_MTIMECMP_LO_OFFSET, data, resp);
    check(resp == 2'b00 && data == 32'hCAFE_BABE, "wrapper forwards CLINT register reads");
  endtask

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    pass_count = 0;
    fail_count = 0;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axi4l_clint_tb.vcd");
    $dumpvars(0, axi4l_clint_tb);

    reset_dut();
    tc_irq_vector_packing();
    tc_register_access_through_wrapper();

    $display("axi4l_clint_tb summary: pass=%0d fail=%0d", pass_count, fail_count);
    if (fail_count != 0) $fatal(1, "axi4l_clint_tb failed");
    $finish;
  end

endmodule
