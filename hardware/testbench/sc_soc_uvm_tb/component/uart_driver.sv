`ifndef __GUARD_UART_DRIVER_SV__
`define __GUARD_UART_DRIVER_SV__ 0

`include "sc_soc_uvm_tb/object/uart_seq_item.sv"

class uart_driver extends uvm_driver #(uart_seq_item);

  `uvm_component_utils(uart_driver)

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual uart_if intf;
  
  int baud_rate;
  bit parity_enable;
  bit parity_type;
  bit second_stop_bit;
  int data_bits;

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (!uvm_config_db#(virtual uart_if)::get(this, "", "intf", intf)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);

    forever begin
      seq_item_port.get_next_item(req);
      set_config();
      intf.send_tx(req.data, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);
      seq_item_port.item_done();
    end
  endtask

  // Task to retrieve UART configuration from the database
  task set_config();
    void'(uvm_config_db#(int)::get(this, "", "baud_rate", baud_rate));
    void'(uvm_config_db#(bit)::get(this, "", "parity_enable", parity_enable));
    void'(uvm_config_db#(bit)::get(this, "", "parity_type", parity_type));
    void'(uvm_config_db#(bit)::get(this, "", "second_stop_bit", second_stop_bit));
    void'(uvm_config_db#(int)::get(this, "", "data_bits", data_bits));
  endtask

endclass

`endif
