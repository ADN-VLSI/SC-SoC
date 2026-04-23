`ifndef __GUARD_PACKAGE_DEFAULTS_PKG_SV__
`define __GUARD_PACKAGE_DEFAULTS_PKG_SV__ 0

`include "axi/typedef.svh"

package defaults_pkg;

  `AXI_LITE_TYPEDEF_ALL(axi4l, logic[31:0], logic[63:0], logic[7:0])

endpackage

`endif
