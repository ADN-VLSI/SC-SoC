`ifndef __GUARD_UART_AGENT_SV__
`define __GUARD_UART_AGENT_SV__ 0

`include "sc_soc_uvm_tb/object/uart_seq_item.sv"
`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"
`include "sc_soc_uvm_tb/component/uart_driver.sv"
`include "sc_soc_uvm_tb/component/uart_monitor.sv"

class uart_agent extends uvm_agent;

  `uvm_component_utils(uart_agent)

  uvm_analysis_port #(uart_rsp_item) ap;

  uvm_sequencer #(uart_seq_item) sqr;
  uart_driver dvr;
  uart_monitor mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    sqr = uvm_sequencer #(uart_seq_item)::type_id::create("sqr", this);
    dvr = uart_driver::type_id::create("dvr", this);
    mon = uart_monitor::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(ap);
    dvr.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass

`endif
