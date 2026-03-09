// `ifndef __GUARD_VIP_AXI4L_MONITOR_SV__
// `define __GUARD_VIP_AXI4L_MONITOR_SV__ 0

`include "axi4l/typedef.svh"
`include "vip/axi4l/rsp_item.sv"

class axi4l_monitor #(
    parameter type req_t = defaults_pkg::axi4l_req_t,
    parameter type rsp_t = defaults_pkg::axi4l_rsp_t
);

  mailbox #(axi4l_rsp_item) mbx = new();

  virtual axi4l_if #(
      .req_t(req_t),
      .rsp_t(rsp_t)
  ) vif;

  function automatic void connect_interface(
  virtual axi4l_if #(
  .req_t(req_t),
  .rsp_t(rsp_t)
  ) vif);
    this.vif = vif;
  endfunction

  function automatic void connect_mailbox(mailbox #(axi4l_rsp_item) mbx);
    this.mbx = mbx;
  endfunction

endclass

// `endif
