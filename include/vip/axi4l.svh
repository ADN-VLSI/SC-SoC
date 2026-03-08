`ifndef __GUARD_VIP_AXI4L_SVH__
`define __GUARD_VIP_AXI4L_SVH__

package axi4l_vip_pkg;

  function automatic void print(input string msg = "", input int fmt = 0, input int clr = 0);
    $display("\n\033[%0d;3%0dm%s\033[0m\n", fmt, clr, msg);
  endfunction

  `include "vip/axi4l/cfg.sv"
  
  `include "vip/axi4l/seq_item.sv"
  
  `include "vip/axi4l/rsp_item.sv"

endpackage

`endif
