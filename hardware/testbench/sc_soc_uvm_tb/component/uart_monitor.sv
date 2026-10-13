`ifndef __GUARD_UART_MONITOR_SV__
`define __GUARD_UART_MONITOR_SV__ 0

`include "sc_soc_uvm_tb/object/uart_rsp_item.sv"

class uart_monitor extends uvm_monitor;

  `uvm_component_utils(uart_monitor)

  uvm_analysis_port#(uart_transaction) ap;
  virtual uart_if vif;

  // UART configuration parameters
  int baud_rate;
  bit parity_enable;
  bit parity_type;
  bit second_stop_bit;
  int data_bits;


  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "intf", vif)) begin
        `uvm_fatal("NO_VIF", "Virtual interface not found")
    end

  endfunction

  task run_phase(uvm_phase phase);
    uart_rsp_item rsp_tx;
    uart_rsp_item rsp_rx;
    fork
      // Monitor TX transactions
      forever begin
        `uvm_info(get_type_name(), "UART Monitor waiting for TX data...", UVM_DEBUG)
        rsp_tx = uart_rsp_item::type_id::create("rsp_tx");
        @(negedge vif.tx);
        set_config();
        vif.recv_tx(rsp_tx.data, rsp_tx.parity, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);
        rsp_tx.direction        = 0;  // TX direction
        rsp_tx.baud_rate        = baud_rate;
        rsp_tx.parity_enable    = parity_enable;
        rsp_tx.parity_type      = parity_type;
        rsp_tx.second_stop_bit  = second_stop_bit;
        rsp_tx.data_bits        = data_bits;
        ap.write(rsp_tx);
        `uvm_info(get_type_name(), $sformatf("UART TX Data Received: 0x%0h", rsp_tx.data),
                  UVM_DEBUG)
      end
      // Monitor RX transactions
      forever begin
        `uvm_info(get_type_name(), "UART Monitor waiting for RX data...", UVM_DEBUG)
        rsp_rx = uart_rsp_item::type_id::create("rsp_rx");
        @(negedge vif.rx);
        set_config();
        vif.recv_rx(rsp_rx.data, rsp_rx.parity, baud_rate, parity_enable, parity_type, second_stop_bit, data_bits);
        rsp_rx.direction         = 1;  // RX direction
        rsp_rx.baud_rate         = baud_rate;
        rsp_rx.parity_enable     = parity_enable;
        rsp_rx.parity_type       = parity_type;
        rsp_rx.second_stop_bit   = second_stop_bit;
        rsp_rx.data_bits         = data_bits;
        ap.write(rsp_rx);
        `uvm_info(get_type_name(), $sformatf("UART RX Data Received: 0x%0h", rsp_rx.data),
                  UVM_DEBUG)
      end
    join
  endtask

  // Task to retrieve UART configuration from the database
  task set_config();
    void'(uvm_config_db#(int)::get(uvm_root::get(), "uart", "baud_rate", baud_rate));
    void'(uvm_config_db#(bit)::get(uvm_root::get(), "uart", "parity_enable", parity_enable));
    void'(uvm_config_db#(bit)::get(uvm_root::get(), "uart", "parity_type", parity_type));
    void'(uvm_config_db#(bit)::get(uvm_root::get(), "uart", "second_stop_bit", second_stop_bit));
    void'(uvm_config_db#(int)::get(uvm_root::get(), "uart", "data_bits", data_bits));
  endtask
  endclass
`endif