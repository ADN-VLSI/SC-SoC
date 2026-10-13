// Include guard to prevent multiple inclusions of this file
`ifndef __GUARD_UART_SEQ_ITEM_SV__
`define __GUARD_UART_SEQ_ITEM_SV__ 0

// UART Sequence Item
// This class represents a sequence item for UART transactions,
// extending uvm_sequence_item to include data fields.
class uart_seq_item extends uvm_sequence_item;

  // Data field
  rand bit [7:0] data;  // 8-bit data
  rand int       data_bits;

  // UVM object utilities for factory registration and field automation
  `uvm_object_utils_begin(uart_seq_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(data_bits, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor for the UART sequence item
  function new(string name = "uart_seq_item");
    super.new(name);
  endfunction : new

  constraint data_bits_c { 
    data_bits inside {[5:8]};
    soft data_bits == 8;
 }

endclass

`endif
