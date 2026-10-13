`ifndef __GUARD_BASE_TEST_SV__
`define __GUARD_BASE_TEST_SV__ 0

`include "sc_soc_uvm_tb/component/environment.sv"

class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual ctrl_if glob_ctrl;
  virtual ctrl_if apb_ctrl;
  virtual apb_if  apb_intf;
  virtual uart_if uart_intf;

  environment env;

  virtual function automatic void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = environment::type_id::create("env", this);
  endfunction

  virtual function automatic void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (!uvm_config_db#(virtual ctrl_if)::get(
            uvm_root::get(), "*.env.glob.*", "ctrl", glob_ctrl
        )) begin
      `uvm_fatal("BUILD", "Failed to get glob_ctrl from config DB");
    end
    if (!uvm_config_db#(virtual ctrl_if)::get(
            uvm_root::get(), "*.env.apb.*", "ctrl", apb_ctrl
        )) begin
      `uvm_fatal("BUILD", "Failed to get apb_ctrl from config DB");
    end
    if (!uvm_config_db#(virtual apb_if)::get(
            uvm_root::get(), "*.env.apb.*", "intf", apb_intf
        )) begin
      `uvm_fatal("BUILD", "Failed to get apb_intf from config DB");
    end
    if (!uvm_config_db#(virtual uart_if)::get(
            uvm_root::get(), "*.env.uart.*", "intf", uart_intf
        )) begin
      `uvm_fatal("BUILD", "Failed to get uart_intf from config DB");
    end
  endfunction

  virtual function automatic void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task reset_phase(uvm_phase phase);
    super.reset_phase(phase);
    phase.raise_objection(this);
    glob_ctrl.start_clk(16_000_000);
    apb_ctrl.start_clk(50_000_000);
    glob_ctrl.apply_reset();
    apb_ctrl.apply_reset();
    phase.drop_objection(this);
  endtask

  virtual task shutdown_phase(uvm_phase phase);
    super.shutdown_phase(phase);
    phase.raise_objection(this);
    apb_intf.wait_till_idle();
    uart_intf.wait_till_idle();
    phase.drop_objection(this);
  endtask

endclass

`endif
