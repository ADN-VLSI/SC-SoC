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

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAILBOXES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  mailbox #(axi4l_seq_item) mbx = new(1);

  mailbox #(r_aw_chan_t) aw_mbx = new();
  mailbox #(r_w_chan_t) w_mbx = new();
  mailbox #(r_b_chan_t) b_mbx = new();
  mailbox #(r_ar_chan_t) ar_mbx = new();
  mailbox #(r_r_chan_t) r_mbx = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  virtual axi4l_if #(
      .req_t(req_t),
      .rsp_t(rsp_t)
  ) vif;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

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
    if (IS_MASTER) begin
      fork

        // Define Transfers
        forever begin
          mbx.get(item);
          if (item.is_write) begin
            r_aw_chan_t aw;
            r_w_chan_t  w;
            r_b_chan_t  b;
            aw.addr = item.addr;
            aw.prot = 0;
            w.data  = item.data;
            w.strb  = item.strb;
            aw_mbx.put(aw);
            w_mbx.put(w);
            b_mbx.put(b);
          end else begin
            r_ar_chan_t ar;
            r_r_chan_t  r;
            ar.addr = item.addr;
            ar.prot = 0;
            ar_mbx.put(ar);
            r_mbx.put(r);
          end
        end

        // Handle AW
        forever begin
          r_aw_chan_t aw;
          aw_mbx.get(aw);
          vif.send_aw(aw);
        end

        // Handle W
        forever begin
          r_w_chan_t w;
          w_mbx.get(w);
          vif.send_w(w);
        end

        // Handle B
        forever begin
          r_b_chan_t b;
          b_mbx.get(b);
          vif.recv_b(b);
        end

        // Handle AR
        forever begin
          r_ar_chan_t ar;
          ar_mbx.get(ar);
          vif.send_ar(ar);
        end

        // Handle R
        forever begin
          r_r_chan_t r;
          r_mbx.get(r);
          vif.recv_r(r);
        end

      join_none
    end
  endtask

  task automatic reset();
    if (IS_MASTER) begin
      vif.req_reset();
    end else begin
      vif.rsp_reset();
    end
  endtask

endclass
