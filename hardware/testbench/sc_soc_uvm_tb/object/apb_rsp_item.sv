`ifndef __GUARD_APB_RSP_ITEM_SV__
`define __GUARD_APB_RSP_ITEM_SV__ 0

`include "sc_soc_uvm_tb/object/apb_seq_item.sv"

class apb_rsp_item extends apb_seq_item;

  // rand bit        write; // 0: Read, 1: Write
  // rand bit [31:0] addr;  // 32-bit address
  // rand bit [31:0] data;  // 32-bit write data
  bit                slverr;

  `uvm_object_utils_begin(apb_rsp_item)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor for the APB response sequence item
  function new(string name = "apb_rsp_item");
    super.new(name);
  endfunction

endclass

`endif
