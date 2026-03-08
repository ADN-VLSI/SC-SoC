`include "vip/axi4l.svh"

module axi4l_vip_pkg_tb;

  initial $display("\033[7;38m TEST STARTED \033[0m");
  final $display("\033[7;38m  TEST ENDED  \033[0m");

  import axi4l_vip_pkg::axi4l_cfg;
  import axi4l_vip_pkg::axi4l_seq_item;
  import axi4l_vip_pkg::axi4l_rsp_item;

  axi4l_cfg cfg;
  axi4l_rsp_item item;

  initial begin
    cfg = new();
    item = new();

    cfg.addr_width = 16;  // Example configuration
    cfg.data_width = 64;  // Example configuration

    item.cfg.print();

    if (item.randomize()) begin
      $display("Randomized item:");
      item.print();
    end else begin
      $display("Failed to randomize item");
    end

    item.configure(cfg);  // Set the configuration for the item

    item.cfg.print();

    if (item.randomize()) begin
      $display("Randomized item with configuration:");
      item.print();
    end else begin
      $display("Failed to randomize item with configuration");
    end

    $finish;
  end

endmodule
