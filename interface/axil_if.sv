interface axil_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    // GLOBAL SIGNALS
    input logic arst_ni,
    input logic clk_i
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Write address channel
  logic [  ADDR_WIDTH-1:0] aw_addr_i;
  logic [             2:0] aw_prot_i;
  logic                    aw_valid_i;
  logic                    aw_ready_o;

  // Write data channel
  logic [  DATA_WIDTH-1:0] w_data_i;
  logic [DATA_WIDTH/8-1:0] w_strb_i;
  logic                    w_valid_i;
  logic                    w_ready_o;

  // Write response channel
  logic [             1:0] b_resp_o;
  logic                    b_valid_o;
  logic                    b_ready_i;

  // Read address channel
  logic [  ADDR_WIDTH-1:0] ar_addr_i;
  logic [             2:0] ar_prot_i;
  logic                    ar_valid_i;
  logic                    ar_ready_o;

  // Read data channel
  logic [  DATA_WIDTH-1:0] r_data_o;
  logic [             1:0] r_resp_o;
  logic                    r_valid_o;
  logic                    r_ready_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  semaphore send_aw_sem = new(1);
  task automatic send_aw(input [ADDR_WIDTH-1:0] addr, input [2:0] prot);
    send_aw_sem.get(1);
    // TODO FIX EDGE ALIGN ISSUE
    @(posedge clk_i);
    aw_addr_i  <= addr;
    aw_prot_i  <= prot;
    aw_valid_i <= 1'b1;
    do @(posedge clk_i);
    while (!aw_ready_o);
    aw_valid_i <= 1'b0;
    send_aw_sem.put(1);
  endtask

  semaphore recv_aw_sem = new(1);
  task automatic recv_aw(output [ADDR_WIDTH-1:0] addr, output [2:0] prot);
    recv_aw_sem.get(1);
    // TODO FIX EDGE ALIGN ISSUE
    @(posedge clk_i);
    aw_ready_o <= 1'b1;
    do @(posedge clk_i);
    while (!aw_valid_i);
    addr       = aw_addr_i;
    prot       = aw_prot_i;
    aw_ready_o <= 1'b0;
    send_aw_sem.put(1);
  endtask

  task automatic look_aw(output [ADDR_WIDTH-1:0] addr, output [2:0] prot);
    do @(posedge clk_i);
    while (!(aw_valid_i & aw_ready_o));
    addr       = aw_addr_i;
    prot       = aw_prot_i;
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `define VALID_READY_PROPERTY_CHECK(__VALID__, __READY__,__SIGNAL__)                 \
    assert property (@(posedge clk_i)                                                 \
      disable iff (!arst_ni)                                                          \
      (``__VALID__`` & !``__READY__``)                                                \
      |=> $stable(``__SIGNAL__``))                                                    \
    else                                                                              \
      $error(`"A valid ``__SIGNAL__`` changed while ``__READY__`` was deasserted`");  \
    assert property (@(posedge clk_i)                                                 \
      disable iff (!arst_ni)                                                          \
      ($past(``__VALID__``) && !``__VALID__``)                                        \
      |=> $past(``__READY__``, 2)                                                     \
    else                                                                              \
      $error(`"The ``__VALID__`` deasserted without ``__READY__`` `");                \


  `VALID_READY_PROPERTY_CHECK(aw_valid_i, aw_ready_o, aw_addr_i)
  `VALID_READY_PROPERTY_CHECK(w_valid_i, w_ready_o, w_data_i)
  `VALID_READY_PROPERTY_CHECK(b_valid_o, b_ready_i, b_resp_o)
  `VALID_READY_PROPERTY_CHECK(ar_valid_i, ar_ready_o, ar_addr_i)
  `VALID_READY_PROPERTY_CHECK(r_valid_o, r_ready_i, r_data_o)

  `undef VALID_READY_PROPERTY_CHECK

endinterface
