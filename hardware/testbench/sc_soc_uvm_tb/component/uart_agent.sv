`ifndef __GUARD_UART_AGENT_SV__
`define __GUARD_UART_AGENT_SV__ 0

`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"
`include "sc_soc_uvm_tb/object/uart_driver.sv"
`include "sc_soc_uvm_tb/object/uart_monitor.sv"


class uart_agent extends uvm_agent;

  `uvm_component_utils(uart_agent)

  uvm_analysis_port #(uart_rsp_item) ap;

  uart_sequencer #(uart_rsp_item) sequencer;
  uart_driver driver;
  uart_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    monitor = uart_monitor::type_id::create("monitor", this);
    sequencer = uart_sequencer #(uart_rsp_item)::type_id::create("sequencer", this);
    driver = uart_driver::type_id::create("driver", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.ap.connect(ap);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass

`endif
