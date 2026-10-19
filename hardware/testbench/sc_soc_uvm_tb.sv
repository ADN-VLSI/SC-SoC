`include "package/sc_soc_pkg.sv"
`include "uvm_macros.svh"

module sc_soc_uvm_tb;

  import uvm_pkg::*;

  `include "sc_soc_uvm_tb/component/base_test.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic          bootmode_i;
  wire    [31:0] gpio_io;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // VARIABLES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  string         test_name;

  bit            back_door_load;

  int            exit_code;

  int            debug;

  longint        sym            [string];

  bit            mem_fault;
  bit            uart_fault;

  // `include "sc_soc_tb/reg_wave_mon.sv"

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  ctrl_if glob_ctrl ();

  ctrl_if apb_ctrl ();

  apb_if apb_intf (
      .clk_i  (apb_ctrl.clk),
      .arst_ni(apb_ctrl.arst_ni)
  );

  uart_if uart_intf ();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT INSTANTIATION
  //////////////////////////////////////////////////////////////////////////////////////////////////

  sc_soc u_dut (
      .xtal_i      (glob_ctrl.clk),
      .glob_arst_ni(glob_ctrl.arst_ni),
      .apb_clk_i   (apb_ctrl.clk),
      .apb_arst_ni (apb_ctrl.arst_ni),
      .apb_req_i   (apb_intf.req),
      .apb_resp_o  (apb_intf.resp),
      .uart_tx_o   (uart_intf.rx),
      .uart_rx_i   (uart_intf.tx),
      .bootmode_i  (bootmode_i),
      .gpio_io     (gpio_io)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `include "sc_soc_uvm_tb/methods.sv"
  // function automatic void ram_write(int addr, int data);
  // function automatic int ram_read(int addr);
  // function automatic void load_symbols(string filename);
  // task automatic load_program(string filename);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    if (!$value$plusargs("TEST=%s", test_name)) begin
      $fatal(1, " [FATAL] No test specified. Use +TEST=<test_name>");
    end
    if (test_name == "default") begin
      test_name = "base_test";
    end

    if (!$value$plusargs("BDL=%d", back_door_load)) begin
      $fatal(1, " [FATAL] No back door load specified. Use +BDL=<back_door_load_value>");
    end

    if (!$value$plusargs("DEBUG=%d", debug)) begin
      $fatal(1, " [FATAL] No debug specified. Use +DEBUG=<debug_value>");
    end

    $timeformat(-6, 0, "us");

    if (debug != 0) begin
      $dumpfile("sc_soc_uvm_tb.vcd");
      $dumpvars(0, sc_soc_uvm_tb);
    end

    fork
      forever begin
        #25us;
        $display("@%0t\033[1A\033[0G", $realtime);
      end
    join_none

    // Register Virtual Interfaces
    uvm_config_db#(virtual ctrl_if)::set(uvm_root::get(), "*.env.glob.*", "ctrl", glob_ctrl);

    uvm_config_db#(virtual ctrl_if)::set(uvm_root::get(), "*.env.apb.*", "ctrl", apb_ctrl);
    uvm_config_db#(virtual apb_if)::set(uvm_root::get(), "*.env.apb.*", "intf", apb_intf);

    uvm_config_db#(virtual uart_if)::set(uvm_root::get(), "*.env.uart.*", "intf", uart_intf);

    uvm_config_db#(int)::set(uvm_root::get(), "*.env.uart.*", "baud_rate", 115200);
    uvm_config_db#(bit)::set(uvm_root::get(), "*.env.uart.*", "parity_enable", 0);
    uvm_config_db#(bit)::set(uvm_root::get(), "*.env.uart.*", "parity_type", 0);
    uvm_config_db#(bit)::set(uvm_root::get(), "*.env.uart.*", "second_stop_bit", 0);
    uvm_config_db#(int)::set(uvm_root::get(), "*.env.uart.*", "data_bits", 8);

    run_test(test_name);

  end

endmodule
