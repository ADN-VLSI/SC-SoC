`include "package/uart_pkg.sv"
`include "vip/axi4l.svh"

module axil_uart_regif_tb;

  //////////////////////////////////////////////////////////////////////////////////////
  // IMPORTS
  //////////////////////////////////////////////////////////////////////////////////////
  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;
  import uart_pkg::*;

  //////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  
  // Create VIP typedefs at file scope (ADDR=32, DATA=32)
  `AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////
  logic arst_ni;
  logic clk_i;

  uart_ctrl_reg_t  uart_ctrl_o;
  uart_cfg_reg_t   uart_cfg_o;
  uart_stat_reg_t  uart_stat_o;
  uart_data_t      tx_data_o;
  logic            tx_data_valid_o;
  logic            tx_data_ready_i;
  uart_data_t      rx_data_i;
  logic            rx_data_valid_i;
  logic            rx_data_ready_o;
  uart_count_t     tx_data_cnt_i;
  uart_count_t     rx_data_cnt_i;
  uart_int_reg_t   uart_int_en_o;

  //////////////////////////////////////////////////////////////////////////////////////
  // VIP INSTANCES / MAILBOXES
  //////////////////////////////////////////////////////////////////////////////////////
  axi4l_cfg cfg;
  mailbox #(axi4l_seq_item) dvr_mbx;
  mailbox #(axi4l_rsp_item) mon_mbx;

  axi4l_driver #(
    .req_t    (my_req_t),
    .rsp_t    (my_rsp_t),
    .IS_MASTER(1)
  ) dvr;

  axi4l_monitor #(
    .req_t(my_req_t),
    .rsp_t(my_rsp_t)
  ) mon;

  axi4l_if #(
    .req_t(my_req_t),
    .rsp_t(my_rsp_t)
  ) intf (
    .arst_ni(arst_ni),
    .clk_i  (clk_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // ADAPTER — inline combinational, no separate module
  // Bridges VIP interface (my_req_t/my_rsp_t) <-> DUT (uart_axil_req_t/rsp_t)
  //////////////////////////////////////////////////////////////////////////////////////
  uart_axil_req_t  adapter_req;
  uart_axil_rsp_t  adapter_rsp;

  always_comb begin
    adapter_req          = '0;
    // AW
    adapter_req.aw_valid = intf.req.aw_valid;
    adapter_req.aw.addr  = intf.req.aw.addr;
    adapter_req.aw.prot  = '0;
    // W
    adapter_req.w_valid  = intf.req.w_valid;
    adapter_req.w.data   = intf.req.w.data;
    adapter_req.w.strb   = intf.req.w.strb;
    // B
    adapter_req.b_ready  = intf.req.b_ready;
    // AR
    adapter_req.ar_valid = intf.req.ar_valid;
    adapter_req.ar.addr  = intf.req.ar.addr;
    adapter_req.ar.prot  = '0;
    // R
    adapter_req.r_ready  = intf.req.r_ready;
  end

  always_comb begin
    intf.rsp.aw_ready = adapter_rsp.aw_ready;
    intf.rsp.w_ready  = adapter_rsp.w_ready;
    intf.rsp.b_valid  = adapter_rsp.b_valid;
    intf.rsp.b.resp   = adapter_rsp.b.resp;
    intf.rsp.ar_ready = adapter_rsp.ar_ready;
    intf.rsp.r_valid  = adapter_rsp.r_valid;
    intf.rsp.r.data   = adapter_rsp.r.data;
    intf.rsp.r.resp   = adapter_rsp.r.resp;
  end

  //////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////
  axil_uart_regif u_dut (
    .clk_i           (clk_i),
    .arst_ni         (arst_ni),
    .req_i           (adapter_req),
    .resp_o          (adapter_rsp),
    .uart_ctrl_o     (uart_ctrl_o),
    .uart_cfg_o      (uart_cfg_o),
    .uart_stat_o     (uart_stat_o),
    .tx_data_o       (tx_data_o),
    .tx_data_valid_o (tx_data_valid_o),
    .tx_data_ready_i (tx_data_ready_i),
    .rx_data_i       (rx_data_i),
    .rx_data_valid_i (rx_data_valid_i),
    .rx_data_ready_o (rx_data_ready_o),
    .tx_data_cnt_i   (tx_data_cnt_i),
    .rx_data_cnt_i   (rx_data_cnt_i),
    .uart_int_en_o   (uart_int_en_o)
  );

  //////////////////////////////////////////////////////////////////////////////////////
  // HELPER TASKS
  //////////////////////////////////////////////////////////////////////////////////////

  task automatic recv_b_with_timeout(output logic [1:0] resp, input int timeout_cycles);
    fork
      begin
        intf.recv_b(resp);
      end
      begin
        repeat (timeout_cycles) @(posedge clk_i);
        $display("[%0t] ERROR: timeout waiting for B response", $time);
        resp = 2'bxx;
        disable fork;
      end
    join_any
    disable fork;
  endtask

  task automatic recv_r_with_timeout(
    output logic [31:0] data,
    output logic [1:0]  resp,
    input  int          timeout_cycles
  );
    fork
      begin
        intf.recv_r({data, resp});
      end
      begin
        repeat (timeout_cycles) @(posedge clk_i);
        $display("[%0t] ERROR: timeout waiting for R response", $time);
        data = '0;
        resp = 2'bxx;
        disable fork;
      end
    join_any
    disable fork;
  endtask

  task automatic write_32(
    input logic [15:0] addr,
    input logic [31:0] data,
    input int          timeout_cycles
  );
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic [1:0]  bresp;
    wdata = data << ((addr % 4) * 8);
    wstrb = 4'b1111 << (addr % 4);
    fork
      begin
        intf.send_aw({addr, 3'h0});
        intf.send_w({wdata, wstrb});
        recv_b_with_timeout(bresp, timeout_cycles);
      end
    join
  endtask

  task automatic read_32(
    input  logic [15:0] addr,
    output logic [31:0] data,
    input  int          timeout_cycles
  );
    logic [31:0] rdata;
    logic [1:0]  rresp;
    fork
      begin
        intf.send_ar({addr, 3'h0});
        recv_r_with_timeout(rdata, rresp, timeout_cycles);
      end
    join
    data = rdata >> ((addr % 4) * 8);
  endtask

  task automatic write_16(input logic [15:0] addr, input logic [15:0] data);
    write_32(addr, {16'h0, data}, 1000);
  endtask

  task automatic write_8(input logic [15:0] addr, input logic [7:0] data);
    write_32(addr, {24'h0, data}, 1000);
  endtask

  task automatic check(input logic ok, inout int p, inout int f, input string msg);
    if (ok) begin
      p++;
      if (msg != "") $display("[PASS] %s", msg);
    end else begin
      f++;
      if (msg != "") $display("[FAIL] %s", msg);
    end
  endtask

  task automatic write_seq(
    input logic [31:0] _addr,
    input logic [31:0] data,
    input logic [3:0]  strb
  );
    axi4l_seq_item sit;
    cfg = new();
    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;
    sit = new();
    sit.configure(cfg);
    sit.is_write = 1;
    sit.addr     = _addr;
    sit.size      = $clog2(DATA_WIDTH/8);
    sit.data     = data;
    sit.strb     = strb;
    dvr_mbx.put(sit);
  endtask

  task automatic read_seq(input logic [31:0] _addr);
    axi4l_seq_item sit;
    cfg = new();
    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;
    sit = new();
    sit.configure(cfg);
    sit.is_write = 0;
    sit.addr     = _addr;
    sit.size     = $clog2(DATA_WIDTH/8);
    dvr_mbx.put(sit);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////
  // INCLUDE TESTCASES
  //////////////////////////////////////////////////////////////////////////////////////
  `include "axil_uart_regif_tb/tc0.sv"
  `include "axil_uart_regif_tb/tc1.sv"
  `include "axil_uart_regif_tb/tc2.sv"
  `include "axil_uart_regif_tb/tc3.sv"
  `include "axil_uart_regif_tb/tc4.sv"
  `include "axil_uart_regif_tb/tc5.sv"
  `include "axil_uart_regif_tb/tc6.sv"
  `include "axil_uart_regif_tb/tc7.sv"
  `include "axil_uart_regif_tb/tc8.sv"
  `include "axil_uart_regif_tb/tc9.sv"
  `include "axil_uart_regif_tb/tc10.sv"
  `include "axil_uart_regif_tb/tc11.sv"

  //////////////////////////////////////////////////////////////////////////////////////
  // MAIN INITIAL
  //////////////////////////////////////////////////////////////////////////////////////
  initial begin
    automatic int total_p     = 0;
    automatic int total_f     = 0;
    automatic int p           = 0;
    automatic int f           = 0;
    automatic int test_number = 0;

    if (!$value$plusargs("TEST=%d", test_number)) begin
      $fatal(1, "Must specify test number with TEST=N.");
    end else begin
      $display("Running test number %0d", test_number);
    end

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axil_uart_regif_tb.vcd");
    $dumpvars(0, axil_uart_regif_tb);

    // BUILD
    cfg     = new();
    dvr_mbx = new(1);
    mon_mbx = new();
    dvr     = new();
    mon     = new();

    // CONNECT VIP
    dvr.connect_interface(intf);
    mon.connect_interface(intf);
    dvr.connect_mailbox(dvr_mbx);
    mon.connect_mailbox(mon_mbx);

    // Safe defaults for DUT stimulus inputs
    tx_data_ready_i     = 1'b0;
    rx_data_i           = '0;
    rx_data_valid_i     = 1'b0;
    tx_data_cnt_i.count = '0;
    rx_data_cnt_i.count = '0;

    // RESET + CLOCK
    clk_i   <= 1'b0;
    arst_ni <= 1'b0;
    intf.req_reset();
    #20;
    arst_ni <= 1'b1;
    #20;

    cfg.addr_width = ADDR_WIDTH;
    cfg.data_width = DATA_WIDTH;

    fork
      forever #5 clk_i <= ~clk_i;
    join_none
    @(posedge clk_i);

    if (test_number != 0) begin
      dvr.run();
      mon.run();
    end

    case (test_number)
      0:  tc0 (p, f);
      1:  tc1 (p, f);
      2:  tc2 (p, f);
      3:  tc3 (p, f);
      4:  tc4 (p, f);
      5:  tc5 (p, f);
      6:  tc6 (p, f);
      7:  tc7 (p, f);
      8:  tc8 (p, f);
      9:  tc9 (p, f);
      10: tc10(p, f);
      11: tc11(p, f);
      default: $fatal(1, "Invalid test number %0d. Valid range is 0-11.", test_number);
    endcase

    $display("SELECTED TEST %0d RESULT: PASS=%0d FAIL=%0d", test_number, p, f);
    total_p += p;
    total_f += f;

    $display("\n==== FINAL RESULT ====");
    $display("TOTAL PASS = %0d", total_p);
    $display("TOTAL FAIL = %0d", total_f);
    if (total_f == 0) $display("OVERALL PASSED");
    else              $display("OVERALL FAILED");

    repeat (20) @(posedge clk_i);
    $finish;
  end

endmodule // axil_uart_regif_tb
