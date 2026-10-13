`ifndef __GUARD_ENVIRONMENT_SV__
`define __GUARD_ENVIRONMENT_SV__ 0

`include "sc_soc_uvm_tb/component/apb_agent.sv"
`include "sc_soc_uvm_tb/component/uart_agent.sv"
`include "sc_soc_uvm_tb/component/scoreboard.sv"

`include "sc_soc_uvm_tb/object/apb_rsp_item.sv"
`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"

class environment extends uvm_env;

  `uvm_component_utils(environment)

  uvm_analysis_port #(apb_rsp_item) apb_ap;
  uvm_analysis_port #(uart_rsp_item) uart_ap;

  apb_agent  apb;
  uart_agent uart;
  scoreboard scbd;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb = apb_agent::type_id::create("apb", this);
    uart = uart_agent::type_id::create("uart", this);
    scbd = scoreboard::type_id::create("scbd", this);
    apb_ap = new("apb_ap", this);
    uart_ap = new("uart_ap", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb.ap.connect(apb_ap);
    uart.ap.connect(uart_ap);
    apb_ap.connect(scbd.imp_apb);
    uart_ap.connect(scbd.imp_uart);
  endfunction

endclass

`endif
