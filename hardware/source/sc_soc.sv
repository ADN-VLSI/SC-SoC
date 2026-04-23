`include "package/sc_soc_pkg.sv"

module sc_soc
  import sc_soc_pkg::*;
(
    //---------------------------REMOVE---------------------------
    input logic                  system_arst_ni,
    input logic                  system_clk_i,
    input logic                  core_clk_i,
    input logic [ADDR_WIDTH-1:0] boot_addr_i,
    input logic [DATA_WIDTH-1:0] hart_id_i,
    //---------------------------REMOVE---------------------------

    // Clock and Reset
    input logic xtal_in,      // 16MHz Crystal oscillator input
    input logic glob_arst_ni, // active low asynchronous reset

    // APB3 Interface
    input  logic      apb_arst_ni,  // active low asynchronous reset for APB domain
    input  logic      apb_clk_i,    // APB clock input
    input  apb_req_t  apb_req_i,    // APB request input
    output apb_resp_t apb_resp_o,   // APB response output

    // UART Interface
    output logic uart_tx_o,  // UART transmit output
    input  logic uart_rx_i   // UART receive input
);

  logic                                         instr_req;
  logic                                         instr_gnt;
  logic                                         instr_rvalid;
  logic                      [  ADDR_WIDTH-1:0] instr_addr;
  logic                      [  DATA_WIDTH-1:0] instr_rdata;

  logic                                         data_req;
  logic                                         data_gnt;
  logic                                         data_rvalid;
  logic                                         data_we;
  logic                      [DATA_WIDTH/8-1:0] data_be;
  logic                      [  ADDR_WIDTH-1:0] data_addr;
  logic                      [  DATA_WIDTH-1:0] data_wdata;
  logic                      [  DATA_WIDTH-1:0] data_rdata;

  axil_req_t                 [ SLAVE_PORTS-1:0] axil_slave_port_req;
  axil_resp_t                [ SLAVE_PORTS-1:0] axil_slave_port_resp;

  axil_req_t                 [MASTER_PORTS-1:0] axil_master_port_req;
  axil_resp_t                [MASTER_PORTS-1:0] axil_master_port_resp;

  uart_pkg::uart_axil_req_t                     uart_req;
  uart_pkg::uart_axil_resp_t                    uart_resp;

  always_comb begin  // TODO REMOVE
    axil_master_port_resp[2] = '0;
    axil_master_port_resp[3] = '0;
  end

  rv32imf u_core (
      .clk_i              (system_clk_i),
      .rst_ni             (system_arst_ni),
      .boot_addr_i        (boot_addr_i),
      .dm_halt_addr_i     ('0),
      .hart_id_i          (hart_id_i),
      .dm_exception_addr_i('0),
      .instr_req_o        (instr_req),
      .instr_gnt_i        (instr_gnt),
      .instr_rvalid_i     (instr_rvalid),
      .instr_addr_o       (instr_addr),
      .instr_rdata_i      (instr_rdata),
      .data_req_o         (data_req),
      .data_gnt_i         (data_gnt),
      .data_rvalid_i      (data_rvalid),
      .data_we_o          (data_we),
      .data_be_o          (data_be),
      .data_addr_o        (data_addr),
      .data_wdata_o       (data_wdata),
      .data_rdata_i       (data_rdata),
      .irq_i              ('0),              // TODO
      .irq_ack_o          (),                // TODO
      .irq_id_o           ()                 // TODO
  );

  s1_obi_2_axil #(
      .OBI_ADDRW  (32),
      .OBI_DATAW  (32),
      .axil_req_t (axil_req_t),
      .axil_resp_t(axil_resp_t)
  ) i_bus (
      .clk_i      (system_clk_i),
      .arst_ni    (system_arst_ni),
      .addr_i     (instr_addr),
      .we_i       ('0),
      .wdata_i    ('0),
      .be_i       ('0),
      .req_i      (instr_req),
      .gnt_o      (instr_gnt),
      .rvalid_o   (instr_rvalid),
      .rdata_o    (instr_rdata),
      .axil_req_o (axil_slave_port_req[0]),
      .axil_resp_i(axil_slave_port_resp[0])
  );

  s1_obi_2_axil #(
      .OBI_ADDRW  (32),
      .OBI_DATAW  (32),
      .axil_req_t (axil_req_t),
      .axil_resp_t(axil_resp_t)
  ) d_bus (
      .clk_i      (system_clk_i),
      .arst_ni    (system_arst_ni),
      .addr_i     (data_addr),
      .we_i       (data_we),
      .wdata_i    (data_wdata),
      .be_i       (data_be),
      .req_i      (data_req),
      .gnt_o      (data_gnt),
      .rvalid_o   (data_rvalid),
      .rdata_o    (data_rdata),
      .axil_req_o (axil_slave_port_req[1]),
      .axil_resp_i(axil_slave_port_resp[1])
  );

  axi_lite_xbar #(
      .Cfg       (noc_cfg),
      .aw_chan_t (axil_aw_chan_t),
      .w_chan_t  (axil_w_chan_t),
      .b_chan_t  (axil_b_chan_t),
      .ar_chan_t (axil_ar_chan_t),
      .r_chan_t  (axil_r_chan_t),
      .axi_req_t (axil_req_t),
      .axi_resp_t(axil_resp_t),
      .rule_t    (axi_pkg::xbar_rule_32_t)
  ) NoC (
      .clk_i                (system_clk_i),
      .rst_ni               (system_arst_ni),
      .test_i               ('0),
      .slv_ports_req_i      (axil_slave_port_req),
      .slv_ports_resp_o     (axil_slave_port_resp),
      .mst_ports_req_o      (axil_master_port_req),
      .mst_ports_resp_i     (axil_master_port_resp),
      .addr_map_i           (addr_map),
      .en_default_mst_port_i('1),
      .default_mst_port_i   ('0)
  );

  axi4l_mem #(
      .axi4l_req_t (axil_req_t),
      .axi4l_resp_t(axil_resp_t),
      .ADDR_WIDTH  (ADDR_WIDTH),
      .DATA_WIDTH  (DATA_WIDTH)
  ) u_ram (
      .arst_ni     (system_arst_ni),
      .clk_i       (system_clk_i),
      .axi4l_req_i (axil_master_port_req[0]),
      .axi4l_resp_o(axil_master_port_resp[0])
  );

  s1_apb_2_axil #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .apb_req_t (apb_req_t),
      .apb_resp_t(apb_resp_t),
      .aw_chan_t (axil_aw_chan_t),
      .w_chan_t  (axil_w_chan_t),
      .b_chan_t  (axil_b_chan_t),
      .ar_chan_t (axil_ar_chan_t),
      .r_chan_t  (axil_r_chan_t),
      .axi_req_t (axil_req_t),
      .axi_resp_t(axil_resp_t)
  ) u_apb (
      .apb_clk_i  (apb_clk_i),
      .apb_arst_ni(apb_arst_ni),
      .apb_req_i  (apb_req_i),
      .apb_resp_o (apb_resp_o),
      .axi_clk_i  (system_clk_i),
      .axi_arst_ni(system_arst_ni),
      .axi_req_o  (axil_slave_port_req[2]),
      .axi_resp_i (axil_slave_port_resp[2])
  );

  axil_addr_shifter #(
      .slv_port_req_t (axil_req_t),
      .slv_port_resp_t(axil_resp_t),
      .mst_port_req_t (uart_pkg::uart_axil_req_t),
      .mst_port_resp_t(uart_pkg::uart_axil_resp_t),
      .SHIFT          (-UART_BASE)
  ) aas_uart (
      .slv_port_req_i (axil_master_port_req[1]),
      .slv_port_resp_o(axil_master_port_resp[1]),
      .mst_port_req_o (uart_req),
      .mst_port_resp_i(uart_resp)
  );

  uart_subsystem u_uart (
      .clk_i   (system_clk_i),
      .arst_ni (system_arst_ni),
      .req_i   (uart_req),
      .resp_o  (uart_resp),
      .rx_i    (uart_rx_i),
      .tx_o    (uart_tx_o),
      .int_en_o()                 // TODO
  );

endmodule
