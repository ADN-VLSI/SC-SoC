module axil_mem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // GLOBAL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    input logic arst_ni,
    input logic clk_i,

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // AXIL SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // Write address channel
    input  logic [ADDR_WIDTH-1:0] aw_addr_i,
    input  logic [           2:0] aw_prot_i,
    input  logic                  aw_valid_i,
    output logic                  aw_ready_o,

    // Write data channel
    input  logic [  DATA_WIDTH-1:0] w_data_i,
    input  logic [DATA_WIDTH/8-1:0] w_strb_i,
    input  logic                    w_valid_i,
    output logic                    w_ready_o,

    // Write response channel
    output logic [1:0] b_resp_o,
    output logic       b_valid_o,
    input  logic       b_ready_i,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0] ar_addr_i,
    input  logic [           2:0] ar_prot_i,
    input  logic                  ar_valid_i,
    output logic                  ar_ready_o,

    // Read data channel
    output logic [DATA_WIDTH-1:0] r_data_o,
    output logic [           1:0] r_resp_o,
    output logic                  r_valid_o,
    input  logic                  r_ready_i

);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // Write address channel
  logic [  ADDR_WIDTH-1:0] aw_addr;
  logic [             2:0] aw_prot;
  logic                    aw_valid;
  logic                    aw_ready;

  // Write data channel
  logic [  DATA_WIDTH-1:0] w_data;
  logic [DATA_WIDTH/8-1:0] w_strb;
  logic                    w_valid;
  logic                    w_ready;

  // Write response channel
  logic [             1:0] b_resp;
  logic                    b_valid;
  logic                    b_ready;

  // Read address channel
  logic [  ADDR_WIDTH-1:0] ar_addr;
  logic [             2:0] ar_prot;
  logic                    ar_valid;
  logic                    ar_ready;

  // Read data channel
  logic [  DATA_WIDTH-1:0] r_data;
  logic [             1:0] r_resp;
  logic                    r_valid;
  logic                    r_ready;

  // Write interface
  logic [  ADDR_WIDTH-1:0] mem_waddr;
  logic [  DATA_WIDTH-1:0] mem_wdata;
  logic [DATA_WIDTH/8-1:0] mem_wstrb;
  logic                    mem_wenable;

  // Read interface
  logic [  ADDR_WIDTH-1:0] mem_raddr;
  logic [  DATA_WIDTH-1:0] mem_rdata;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // SUBMODULE INSTANTIATIONS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (ADDR_WIDTH + 3),
      .ALLOW_FALLTHROUGH(0)
  ) aw_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({aw_addr_i, aw_prot_i}),
      .data_in_valid_i (aw_valid_i),
      .data_in_ready_o (aw_ready_o),
      .data_out_o      ({aw_addr, aw_prot}),
      .data_out_valid_o(aw_valid),
      .data_out_ready_i(aw_ready),
      .count_o         ()
  );

  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (DATA_WIDTH + DATA_WIDTH / 8),
      .ALLOW_FALLTHROUGH(0)
  ) w_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({w_data_i, w_strb_i}),
      .data_in_valid_i (w_valid_i),
      .data_in_ready_o (w_ready_o),
      .data_out_o      ({w_data, w_strb}),
      .data_out_valid_o(w_valid),
      .data_out_ready_i(w_ready),
      .count_o         ()
  );



  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (2),
      .ALLOW_FALLTHROUGH(0)
  ) b_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       (b_resp),
      .data_in_valid_i (b_valid),
      .data_in_ready_o (b_ready),
      .data_out_o      (b_resp_o),
      .data_out_valid_o(b_valid_o),
      .data_out_ready_i(b_ready_i),
      .count_o         ()
  );



  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (ADDR_WIDTH + 3),
      .ALLOW_FALLTHROUGH(0)
  ) ar_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({ar_addr_i, ar_prot_i}),
      .data_in_valid_i (ar_valid_i),
      .data_in_ready_o (ar_ready_o),
      .data_out_o      ({ar_addr, ar_prot}),
      .data_out_valid_o(ar_valid),
      .data_out_ready_i(ar_ready),
      .count_o         ()
  );


  fifo #(
      .FIFO_SIZE        (2),
      .DATA_WIDTH       (DATA_WIDTH + 2),
      .ALLOW_FALLTHROUGH(0)
  ) r_fifo (
      .arst_ni         (arst_ni),
      .clk_i           (clk_i),
      .data_in_i       ({r_data, r_resp}),
      .data_in_valid_i (r_valid),
      .data_in_ready_o (r_ready),
      .data_out_o      ({r_data_o, r_resp_o}),
      .data_out_valid_o(r_valid_o),
      .data_out_ready_i(r_ready_i),
      .count_o         ()
  );


  axil_mem_ctrlr #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) ctrlr_inst (
      // AXIL signals
      .aw_addr_i (aw_addr),
      .aw_prot_i (aw_prot),
      .aw_valid_i(aw_valid),
      .aw_ready_o(aw_ready),
      .w_data_i  (w_data),
      .w_strb_i  (w_strb),
      .w_valid_i (w_valid),
      .w_ready_o (w_ready),
      .b_resp_o  (b_resp),
      .b_valid_o (b_valid),
      .b_ready_i (b_ready),
      .ar_addr_i (ar_addr),
      .ar_prot_i (ar_prot),
      .ar_valid_i(ar_valid),
      .ar_ready_o(ar_ready),
      .r_data_o  (r_data),
      .r_resp_o  (r_resp),
      .r_valid_o (r_valid),
      .r_ready_i (r_ready),
      .waddr_o   (mem_waddr),
      .wdata_o   (mem_wdata),
      .wstrb_o   (mem_wstrb),
      .wenable_o (mem_wenable),
      .raddr_o   (mem_raddr),
      .rdata_i   (mem_rdata)
  );

  dual_port_mem #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) mem_inst (
      .clk_i  (clk_i),
      .waddr_i(mem_waddr),
      .we_i   (mem_wenable),
      .wdata_i(mem_wdata),
      .wstrb_i(mem_wstrb),
      .raddr_i(mem_raddr),
      .rdata_o(mem_rdata)
  );



endmodule
