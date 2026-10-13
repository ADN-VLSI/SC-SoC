`ifndef __GUARD_UART_AGENT_SV__
`define __GUARD_UART_AGENT_SV__ 0

`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"

class uart_agent extends uvm_agent;

  `uvm_component_utils(uart_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  uvm_analysis_port #(uart_rsp_item) ap;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

endclass

`endif
