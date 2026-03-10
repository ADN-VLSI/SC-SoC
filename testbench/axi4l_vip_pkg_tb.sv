`include "axi4l/typedef.svh"
`include "vip/axi4l.svh"

module axi4l_vip_pkg_tb;

  initial $display("\033[7;38m TEST STARTED \033[0m");
  final $display("\033[7;38m  TEST ENDED  \033[0m");

  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;
  import axi4l_vip_pkg::axi4l_driver;
  import axi4l_vip_pkg::axi4l_monitor;

  `AXI4L_ALL(axi4l, 32, 32)

  logic arst_ni;
  logic clk_i;

  axi4l_if #(
      .req_t(axi4l_req_t),
      .rsp_t(axi4l_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  axi4l_mem #(
      .axi4l_req_t(axi4l_req_t),
      .axi4l_rsp_t(axi4l_rsp_t),
      .ADDR_WIDTH (32),
      .DATA_WIDTH (32)
  ) u_mem (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_rsp_o(intf.rsp)
  );

  axi4l_driver #(
      .req_t(axi4l_req_t),
      .rsp_t(axi4l_rsp_t),
      .IS_MASTER(1)
  ) dvr;

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

  initial begin

    axi4l_seq_item item;

    item = new();
    dvr  = new();

    dvr.connect_interface(intf);

    apply_reset();

    dvr.run();
    start_clock();

    repeat (5) begin

      if (item.randomize() with {item.is_write == 1;}) begin
        $display("Randomized item:");
        item.print();
      end else begin
        $display("Failed to randomize item");
      end

      dvr.mbx.put(item);

    end

    #500ns;

    $finish;
  end

endmodule
