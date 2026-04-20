module cdc_fifo #(
    parameter  int DATA_WIDTH  = 8,
    parameter  int FIFO_DEPTH  = 16,
    parameter  int SYNC_STAGES = 2,
    localparam int FIFO_SIZE   = $clog2(FIFO_DEPTH),
    localparam int ELEM_WIDTH  = DATA_WIDTH
) (
    input logic arst_ni,

    input  logic                  wr_clk_i,
    input  logic [ELEM_WIDTH-1:0] wr_data_i,
    input  logic                  wr_valid_i,
    output logic                  wr_ready_o,
    output logic [   FIFO_SIZE:0] wr_count_o,

    input  logic                  rd_clk_i,
    output logic [ELEM_WIDTH-1:0] rd_data_o,
    output logic                  rd_valid_o,
    input  logic                  rd_ready_i,
    output logic [   FIFO_SIZE:0] rd_count_o
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [FIFO_SIZE:0] wr_ptr_pass;
  logic [FIFO_SIZE:0] rd_ptr_pass;

  logic hsi;
  logic hso;

  logic [FIFO_SIZE:0] wr_addr;
  logic [FIFO_SIZE:0] rd_addr;

  logic [FIFO_SIZE:0] wr_addr_;
  logic [FIFO_SIZE:0] rd_addr_;

  logic [FIFO_SIZE:0] wr_addr_p1;
  logic [FIFO_SIZE:0] rd_addr_p1;

  logic [FIFO_SIZE:0] wpgi;
  logic [FIFO_SIZE:0] rpgi;

  logic [FIFO_SIZE:0] wpgo;
  logic [FIFO_SIZE:0] rpgo;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-ASSIGNMENTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  assign hsi = wr_valid_i & wr_ready_o;
  assign hso = rd_valid_o & rd_ready_i;

  assign wr_addr_p1 = wr_addr + 1;
  assign rd_addr_p1 = rd_addr + 1;

  if (FIFO_SIZE > 0) begin : g_elem_in_ready_o
    assign wr_ready_o = arst_ni & !(
                                (wr_addr[FIFO_SIZE] != rd_addr_[FIFO_SIZE])
                                &&
                                (wr_addr[FIFO_SIZE-1:0] == rd_addr_[FIFO_SIZE-1:0])
                              );
  end else begin : g_elem_in_ready_o
    assign wr_ready_o = arst_ni & (wr_addr_ == rd_addr);
  end

  assign rd_valid_o = (wr_addr_ != rd_addr);

  assign wr_count_o = wr_addr - rd_addr_;
  assign rd_count_o = wr_addr_ - rd_addr;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  //-RTLS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic logic [FIFO_SIZE:0] bin_to_gray(input logic [FIFO_SIZE:0] bin);
    return (bin >> 1) ^ bin;
  endfunction

  function automatic logic [FIFO_SIZE:0] gray_to_bin(input logic [FIFO_SIZE:0] gray);
    logic [FIFO_SIZE:0] bin;
    bin[FIFO_SIZE] = gray[FIFO_SIZE];
    for (int i = FIFO_SIZE - 1; i >= 0; i--) begin
      bin[i] = bin[i+1] ^ gray[i];
    end
    return bin;
  endfunction


  always_comb wr_addr = gray_to_bin(wr_ptr_pass);
  always_comb rd_addr_ = gray_to_bin(rpgo);
  always_comb wr_addr_ = gray_to_bin(wpgo);
  always_comb rd_addr = gray_to_bin(rd_ptr_pass);

  always_comb wpgi = bin_to_gray(wr_addr_p1);
  always_comb rpgi = bin_to_gray(rd_addr_p1);

  always_ff @(posedge wr_clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      wr_ptr_pass <= '0;
    end else if (hsi) begin
      wr_ptr_pass <= wpgi;
    end
  end

  register_dual_flop #(
      .ELEM_WIDTH(FIFO_SIZE + 1),
      .RESET_VALUE('0),
      .FIRST_FF_EDGE_POSEDGED(0),
      .LAST_FF_EDGE_POSEDGED(1)
  ) rd_ptr_ic (
      .clk_i  (wr_clk_i),
      .arst_ni(arst_ni),
      .en_i   ('1),
      .d_i    (rd_ptr_pass),
      .q_o    (rpgo)
  );

  register_dual_flop #(
      .ELEM_WIDTH(FIFO_SIZE + 1),
      .RESET_VALUE('0),
      .FIRST_FF_EDGE_POSEDGED(0),
      .LAST_FF_EDGE_POSEDGED(1)
  ) wr_ptr_oc (
      .clk_i  (rd_clk_i),
      .arst_ni(arst_ni),
      .en_i   ('1),
      .d_i    (wr_ptr_pass),
      .q_o    (wpgo)
  );

  always_ff @(posedge rd_clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      rd_ptr_pass <= '0;
    end else if (hso) begin
      rd_ptr_pass <= rpgi;
    end
  end

  if (FIFO_SIZE > 0) begin : g_mem

    logic [ELEM_WIDTH-1:0] mem[(2**FIFO_SIZE)];

    always_ff @(posedge wr_clk_i or negedge arst_ni) begin
      if (hsi & arst_ni) begin
        mem[wr_addr[FIFO_SIZE-1:0]] <= wr_data_i;
      end
    end

    always_comb begin
      rd_data_o = mem[rd_addr[FIFO_SIZE-1:0]];
    end

  end else begin : g_mem

    always_ff @(posedge wr_clk_i or negedge arst_ni) begin
      if (~arst_ni) begin
        rd_data_o <= '0;
      end else if (hsi) begin
        rd_data_o <= wr_data_i;
      end
    end

  end

endmodule
