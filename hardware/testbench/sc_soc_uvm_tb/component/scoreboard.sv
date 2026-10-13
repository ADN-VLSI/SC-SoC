`ifndef __GUARD_SCOREBOARD_SV__
`define __GUARD_SCOREBOARD_SV__ 0

`include "sc_soc_uvm_tb/object/apb_rsp_item.sv"
`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"

`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_uart)

class scoreboard extends uvm_env;

  `uvm_component_utils(scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  uvm_analysis_imp_apb #(apb_rsp_item, scoreboard) imp_apb;
  uvm_analysis_imp_uart #(uart_rsp_item, scoreboard) imp_uart;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    imp_apb = new("imp_apb", this);
    imp_uart = new("imp_uart", this);
  endfunction

  function void write_apb(apb_rsp_item item);
    // TODO
  endfunction

  function void write_uart(uart_rsp_item item);
    // TODO
  endfunction
  
endclass

`endif
