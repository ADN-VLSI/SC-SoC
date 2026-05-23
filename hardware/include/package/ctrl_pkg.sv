        
`ifndef __GUARD_CTRL_PKG_SV__
`define __GUARD_CTRL_PKG_SV__

package ctrl_pkg;
        
        localparam int CTRL_GPIO_DIR_OFFSET       = 32'h0A8;         // Defining Register Offsets
        localparam int CTRL_SOC_ID_OFFSET         = 32'h000;         // Defining Register Offsets
        localparam int CTRL_REV_ID_OFFSET         = 32'h004;         // Defining Register Offsets
        localparam int CTRL_CORE_BOOT_ADDR_OFFSET = 32'h020;         // Defining Register Offsets
        localparam int CTRL_CORE_HART_ID_OFFSET   = 32'h024;         // Defining Register Offsets
        localparam int CTRL_CORE_CLK_RST_OFFSET   = 32'h028;         // Defining Register Offsets
        localparam int CTRL_PLL_CFG_OFFSET        = 32'h040;         // Defining Register Offsets
        localparam int CTRL_TOHOST_OFFSET         = 32'h060;         // Defining Register Offsets
        localparam int CTRL_FROMHOST_OFFSET       = 32'h068;         // Defining Register Offsets
        localparam int CTRL_BOOTMODE_OFFSET       = 32'h080;         // Defining Register Offsets
        localparam int CTRL_GPIO_IN_OFFSET        = 32'h0A0;         // Defining Register Offsets
        localparam int CTRL_GPIO_OUT_OFFSET       = 32'h0A4;         // Defining Register Offsets
        localparam int CTRL_GPIO_PULL_OFFSET      = 32'h0AC;         // Defining Register Offsets

        localparam int CTRL_SOC_ID_RESET         = 32'h4467_0931;    // Defining Constants
        localparam int CTRL_REV_ID_RESET         = 32'h0000_0001;    // Defining Constants 
        localparam int CTRL_CORE_BOOT_ADDR_RESET = 32'h4000_0000;    // Defining Constants 
        localparam int CTRL_PLL_CFG_RESET        = 32'h0000_0C90;    // Defining Constants 

        // AXI4-Lite types: ADDR=6 DATA=32
        `AXI_LITE_TYPEDEF_ALL(ctrl_axil, logic[7:0], logic[31:0], logic[3:0])
  
endpackage

`endif