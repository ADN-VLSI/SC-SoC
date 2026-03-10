class axi4l_driver #(
    parameter type req_t     = defaults_pkg::axi4l_req_t,
    parameter type rsp_t     = defaults_pkg::axi4l_rsp_t,
    parameter bit  IS_MASTER = 1
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  req_t dummy;

  localparam int ADDR_WIDTH = $bits(dummy.aw.addr);
  localparam int DATA_WIDTH = $bits(dummy.w.data);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(r, ADDR_WIDTH, DATA_WIDTH)
  // r_aw_chan_t r_w_chan_t r_b_chan_t r_ar_chan_t r_r_chan_t
  // r_req_t r_rsp_t

  mailbox #(axi4l_seq_item) mbx = new(1);

  virtual axi4l_if #(
      .req_t(req_t),
      .rsp_t(rsp_t)
  ) vif;

  function automatic void connect_interface(
  virtual axi4l_if #(
  .req_t(req_t),
  .rsp_t(rsp_t)
  ) vif);
    this.vif = vif;
  endfunction

  function automatic void connect_mailbox(mailbox#(axi4l_seq_item) mbx);
    this.mbx = mbx;
  endfunction

  task automatic run();
    axi4l_seq_item item;
    fork
      if (IS_MASTER) begin
        forever begin
          mbx.peek(item);
          init_tx(item);
          mbx.get(item);
        end
      end
    join_none
  endtask

  task automatic reset();
    if (IS_MASTER) begin
      vif.req_reset();
    end else begin
      vif.rsp_reset();
    end
  endtask

  task automatic init_tx(axi4l_seq_item item);
    if (item.is_write) begin
      r_aw_chan_t aw;
      r_w_chan_t  w;
      r_b_chan_t  b;
      aw.addr = item.addr;
      aw.prot = 0;
      w.data  = item.data;
      w.strb  = item.strb;
      fork
        vif.send_aw(aw);
        vif.send_w(w);
        vif.recv_b(b);
      join
    end else begin
      r_ar_chan_t ar;
      r_r_chan_t  r;
      ar.addr = item.addr;
      ar.prot = 0;
      fork
        vif.send_ar(ar);
        vif.recv_r(r);
      join
    end
  endtask

endclass
