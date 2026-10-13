// Include guard to prevent multiple inclusions of this file
`ifndef __GUARD_UART_RSP_ITEM_SV__
`define __GUARD_UART_RSP_ITEM_SV__ 0

// Include the base UART sequence item class
`include "sc_soc_uvm_tb/object/uart_seq_item.sv"

// UART Response Sequence Item
// This class extends uart_seq_item to include response-specific fields
// for UART transactions, such as direction indicator.
class uart_rsp_item extends uart_seq_item;

  // // Data field
  // rand bit [7:0] data;  // 8-bit data
  // rand int       data_bits;
  // Response field
  int direction;        // 0 for RX, 1 for TX
  int baud_rate;        // Baud rate for the UART transaction
  int parity_enable;    // Parity enable for the UART transaction
  int parity_type;      // Parity setting for the UART transaction
  int parity;           // Parity setting for the UART transaction
  int second_stop_bit;  // Second stop bit setting for the UART transaction

  // UVM object utilities for factory registration
  `uvm_object_utils_begin(uart_rsp_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(data_bits, UVM_ALL_ON)
    `uvm_field_int(direction, UVM_ALL_ON)
    `uvm_field_int(baud_rate, UVM_ALL_ON)
    `uvm_field_int(parity_enable, UVM_ALL_ON)
    `uvm_field_int(parity_type, UVM_ALL_ON)
    `uvm_field_int(parity, UVM_ALL_ON)
    `uvm_field_int(second_stop_bit, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor for the UART response sequence item
  function new(string name = "uart_rsp_item");
    super.new(name);
  endfunction : new

endclass

`endif