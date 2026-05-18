`ifndef __GUARD_SC_SOC_PKG_SV__
`define __GUARD_SC_SOC_PKG_SV__

`include "apb/typedef.svh"
`include "axi/typedef.svh"

package sc_soc_pkg;

  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;

  localparam int UART_BASE = 32'h0001_1000;
  localparam int UART_LEN  = 32'h0000_1000;

  localparam int I2C_BASE  = 32'h0001_2000;
  localparam int I2C_LEN   = 32'h0000_1000;

  localparam int CTRL_BASE = 32'h0001_0000;
  localparam int CTRL_LEN  = 32'h0000_1000;

  localparam int SLAVE_PORTS = 3;
  localparam int MASTER_PORTS = 4;

  `APB_TYPEDEF_ALL(apb, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])

  `AXI_LITE_TYPEDEF_ALL(axil, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])

  localparam int NumRules = 3;
  localparam axi_pkg::xbar_rule_32_t [NumRules-1:0] addr_map = '{
      '{idx: 1, start_addr: UART_BASE, end_addr: UART_BASE + UART_LEN - 1},  // u_uart
      '{idx: 2, start_addr: I2C_BASE,  end_addr: I2C_BASE  + I2C_LEN  - 1},  // u_i2c
      '{idx: 3, start_addr: CTRL_BASE, end_addr: CTRL_BASE + CTRL_LEN - 1}   // u_ctrl
      // DEFAULT RULE (idx: 0) will route to u_ram
  };
  localparam axi_pkg::xbar_cfg_t noc_cfg = '{
      NoSlvPorts : SLAVE_PORTS,
      NoMstPorts : MASTER_PORTS,
      MaxMstTrans: 2,
      MaxSlvTrans: 2,
      LatencyMode: axi_pkg::CUT_ALL_PORTS,
      PipelineStages: 2,
      UniqueIds: 1,
      AxiAddrWidth: ADDR_WIDTH,
      AxiDataWidth: DATA_WIDTH,
      NoAddrRules: NumRules,
      default: '0
  };

endpackage

`endif
