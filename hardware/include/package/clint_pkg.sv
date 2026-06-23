`ifndef __GUARD_CLINT_PKG_SV__
`define __GUARD_CLINT_PKG_SV__

`include "axi/typedef.svh"

package clint_pkg;

  localparam int CLINT_ADDR_WIDTH = 16;
  localparam int CLINT_DATA_WIDTH = 32;
  localparam int CLINT_STRB_WIDTH = CLINT_DATA_WIDTH / 8;

  localparam logic [CLINT_ADDR_WIDTH-1:0] CLINT_MSIP_OFFSET        = 16'h0000;
  localparam logic [CLINT_ADDR_WIDTH-1:0] CLINT_MTIMECMP_LO_OFFSET = 16'h4000;
  localparam logic [CLINT_ADDR_WIDTH-1:0] CLINT_MTIMECMP_HI_OFFSET = 16'h4004;
  localparam logic [CLINT_ADDR_WIDTH-1:0] CLINT_MTIME_LO_OFFSET    = 16'hBFF8;
  localparam logic [CLINT_ADDR_WIDTH-1:0] CLINT_MTIME_HI_OFFSET    = 16'hBFFC;

  localparam logic [31:0] CLINT_MSIP_RESET        = 32'h0000_0000;
  localparam logic [63:0] CLINT_MTIMECMP_RESET    = 64'hFFFF_FFFF_FFFF_FFFF;
  localparam logic [63:0] CLINT_MTIME_RESET       = 64'h0000_0000_0000_0000;
  localparam logic [63:0] CLINT_MTIME_INC_DEFAULT = 64'd1;

  `AXI_LITE_TYPEDEF_ALL(clint_axil,
                        logic[CLINT_ADDR_WIDTH-1:0],
                        logic[CLINT_DATA_WIDTH-1:0],
                        logic[CLINT_STRB_WIDTH-1:0])

endpackage

`endif
