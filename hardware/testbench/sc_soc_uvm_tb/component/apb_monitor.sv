`ifndef __GUARD_UART_MONITOR_SV__
`define __GUARD_UART_MONITOR_SV__ 0

`include "sc_soc_uvm_tb/object/apb_rsp_item.sv"

class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  // Analysis port for publishing observed APB transactions
  uvm_analysis_port #(apb_rsp_item) ap;

  // Virtual APB interface
  virtual apb_if intf;

  // Constructor
  function new(
    string name = "apb_monitor",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction

  // Build phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap = new("ap", this);
  endfunction

  // Connect phase
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(
          this, "", "intf", intf
        )) begin
      `uvm_fatal("NOVIF", "Virtual APB interface not found")
    end
  endfunction

  // Run phase
  virtual task run_phase(uvm_phase phase);

    forever begin

      apb_rsp_item item;

      // Wait for the next rising clock edge
      @(posedge intf.clk_i);

      // Detect a completed APB transfer
      if (intf.req.psel &&
          intf.req.penable &&
          intf.resp.pready) begin

        // Create a transaction object
        item = apb_rsp_item::type_id::create("item");

        // Capture the APB address
        item.addr = intf.req.paddr;

        // Capture the operation type
        item.we = intf.req.pwrite;

        // Capture write data or read data
        if (intf.req.pwrite) begin
          item.data = intf.req.pwdata;
        end
        else begin
          item.data = intf.resp.prdata;
        end

        // Capture the slave error response
        item.slverr = intf.resp.pslverr;

        // Publish the observed transaction
        ap.write(item);

      end

    end

  endtask

endclass

`endif