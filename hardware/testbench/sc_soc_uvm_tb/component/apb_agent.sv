`ifndef __GUARD_APB_AGENT_SV__
`define __GUARD_APB_AGENT_SV__ 0

`include "sc_soc_uvm_tb/object/apb_rsp_item.sv"

class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  uvm_analysis_port #(apb_rsp_item) ap;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

endclass

`endif
