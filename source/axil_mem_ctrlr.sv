module axil_mem_ctrlr #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (

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
    input  logic                  r_ready_i,

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // MEMORY SIGNALS
    ////////////////////////////////////////////////////////////////////////////////////////////////

    // Write interface
    output logic [  ADDR_WIDTH-1:0] waddr_o,
    output logic [  DATA_WIDTH-1:0] wdata_o,
    output logic [DATA_WIDTH/8-1:0] wstrb_o,
    output logic                    wenable_o,

    // Read interface
    output logic [ADDR_WIDTH-1:0] raddr_o,
    input  logic [DATA_WIDTH-1:0] rdata_i
);

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERNAL SIGNALS
  ////////////////////////////////////////////////////////////////////////////////////////////////

  logic do_write;

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // COMBINATIONAL LOGIC
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // Write
  always_comb do_write = aw_valid_i & w_valid_i & b_ready_i;
  always_comb aw_ready_o = do_write;
  always_comb w_ready_o = do_write;
  always_comb b_valid_o = do_write;
  always_comb begin
    b_resp_o = 2'b11;
    if (aw_prot_i[1:0] == 2'b00) begin
      b_resp_o = 2'b00;
    end
  end
  always_comb waddr_o = aw_addr_i;
  always_comb wdata_o = w_data_i;
  always_comb wstrb_o = w_strb_i;
  always_comb wenable_o = do_write && (b_resp_o == 2'b00);

  // Read 
  always_comb ar_ready_o = r_ready_i;
  always_comb raddr_o = ar_addr_i;
  always_comb begin
    r_resp_o = 2'b11;
    r_data_o = '0;
    if (ar_prot_i[1:0] == 2'b00) begin
      r_resp_o = 2'b00;
      r_data_o = rdata_i;
    end
  end
  always_comb r_valid_o = ar_valid_i;

endmodule
