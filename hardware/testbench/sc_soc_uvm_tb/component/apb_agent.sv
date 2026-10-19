`ifndef __GUARD_APB_AGENT_SV__
`define __GUARD_APB_AGENT_SV__ 0

`include "sc_soc_uvm_tb/object/apb_seq_item.sv"
`include "sc_soc_uvm_tb/object/apb_rsp_item.sv"
`include "sc_soc_uvm_tb/component/apb_monitor.sv"
`include "sc_soc_uvm_tb/component/apb_driver.sv"

class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  uvm_analysis_port #(apb_rsp_item) ap;

  uvm_sequencer #(apb_seq_item) sqr; 
  apb_driver                    dvr;
  apb_monitor                   mon;
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    ap  = new("ap", this);
    sqr = uvm_sequencer #(apb_seq_item)::type_id::create("sqr", this);    
    dvr = apb_driver::type_id::create("dvr", this);
    mon = apb_monitor::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    dvr.seq_item_port.connect(sqr.seq_item_export);
    mon.ap.connect(ap);
  endfunction

endclass

`endif
