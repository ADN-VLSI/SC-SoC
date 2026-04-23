`include "vip/axi4l.svh"

module axi4l_vip_pkg_tb;

  initial $display("\033[7;38m TEST STARTED \033[0m");
  final $display("\033[7;38m  TEST ENDED  \033[0m");

  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;

  `AXI_LITE_TYPEDEF_ALL(axi4l, logic[31:0], logic[31:0], logic[3:0])

  logic arst_ni;
  logic clk_i;

  axi4l_if #(
      .req_t(axi4l_req_t),
      .resp_t(axi4l_resp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  axi4l_mem #(
      .axi4l_req_t(axi4l_req_t),
      .axi4l_resp_t(axi4l_resp_t),
      .ADDR_WIDTH (32),
      .DATA_WIDTH (32)
  ) u_mem (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_resp_o(intf.resp)
  );

  axi4l_driver #(
      .req_t(axi4l_req_t),
      .resp_t(axi4l_resp_t),
      .IS_MASTER(1)
  ) dvr;

  axi4l_monitor #(
      .req_t(axi4l_req_t),
      .resp_t(axi4l_resp_t)
  ) mon;

  task automatic apply_reset();
    #10ns;
    arst_ni <= '0;
    clk_i   <= '0;
    dvr.reset();
    #10ns;
    arst_ni <= '1;
    #10ns;
  endtask

  task automatic start_clock();
    fork
      forever begin
        clk_i <= '1;
        #5ns;
        clk_i <= '0;
        #5ns;
      end
    join_none
    @(posedge clk_i);
  endtask

  task automatic do_tx(input bit is_write, input longint addr);
      axi4l_seq_item item;
      item = new();
      void'(item.randomize() with {
        item.is_write == is_write;
        item.addr == addr;
        });
      dvr.mbx.put(item);
  endtask

  initial begin

    dvr = new();
    mon = new();
    dvr.connect_interface(intf);
    mon.connect_interface(intf);

    apply_reset();

    dvr.run();
    mon.run();
    start_clock();

    // repeat (5) begin
    //   axi4l_seq_item item;
    //   item = new();
    //   void'(item.randomize() with {item.is_write == 1;});
    //   dvr.mbx.put(item);
    // end
    do_tx(0,'h000);
    do_tx(1,'h000);
    do_tx(1,'h100);
    do_tx(1,'h200);
    do_tx(0,'h200);
    do_tx(0,'h000);
    do_tx(0,'h100);

    mon.wait_for_idle();

    while (mon.mbx.num()) begin
      axi4l_rsp_item item;
      mon.mbx.get(item);
      $display("Received item:");
      item.print();
    end

    $finish;
  end

endmodule
