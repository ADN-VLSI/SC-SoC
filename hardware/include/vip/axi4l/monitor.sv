class axi4l_monitor #(
    parameter type req_t  = defaults_pkg::axi4l_req_t,
    parameter type resp_t = defaults_pkg::axi4l_resp_t
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

  `AXI_LITE_TYPEDEF_ALL(r, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])
  // r_aw_chan_t r_w_chan_t r_b_chan_t r_ar_chan_t r_r_chan_t
  // r_req_t r_resp_t

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // MAILBOXES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  mailbox #(axi4l_rsp_item) mbx = new();

  mailbox #(r_aw_chan_t) aw_mbx = new();
  mailbox #(r_w_chan_t) w_mbx = new();
  mailbox #(r_b_chan_t) b_mbx = new();
  mailbox #(r_ar_chan_t) ar_mbx = new();
  mailbox #(r_r_chan_t) r_mbx = new();

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACE
  //////////////////////////////////////////////////////////////////////////////////////////////////

  virtual axi4l_if #(
      .req_t (req_t),
      .resp_t(resp_t)
  ) vif;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function automatic void connect_interface(
  virtual axi4l_if #(
  .req_t (req_t),
  .resp_t(resp_t)
  ) vif);
    this.vif = vif;
  endfunction

  function automatic void connect_mailbox(mailbox#(axi4l_rsp_item) mbx);
    this.mbx = mbx;
  endfunction

  task automatic run();

    fork

      // COLLECT AW
      forever begin
        r_aw_chan_t aw;
        vif.look_aw(aw);
        aw_mbx.put(aw);
      end

      // COLLECT W
      forever begin
        r_w_chan_t w;
        vif.look_w(w);
        w_mbx.put(w);
      end

      // COLLECT B
      forever begin
        r_b_chan_t b;
        vif.look_b(b);
        b_mbx.put(b);
      end

      // COLLECT AR
      forever begin
        r_ar_chan_t ar;
        vif.look_ar(ar);
        ar_mbx.put(ar);
      end

      // COLLECT R
      forever begin
        r_r_chan_t r;
        vif.look_r(r);
        r_mbx.put(r);
      end

      // Prepare Write response
      forever begin
        axi4l_rsp_item item;
        r_aw_chan_t aw;
        r_w_chan_t w;
        r_b_chan_t b;
        fork
          aw_mbx.get(aw);
          w_mbx.get(w);
          b_mbx.get(b);
        join
        item          = new();
        item.is_write = 1;
        item.addr     = aw.addr;
        item.size     = $clog2(DATA_WIDTH / 8);
        item.data     = w.data;
        item.strb     = w.strb;
        item.resp     = b.resp;
        mbx.put(item);
      end

      // Prepare Read response
      forever begin
        axi4l_rsp_item item;
        r_ar_chan_t ar;
        r_r_chan_t r;
        fork
          ar_mbx.get(ar);
          r_mbx.get(r);
        join
        item          = new();
        item.is_write = 0;
        item.addr     = ar.addr;
        item.size     = $clog2(DATA_WIDTH / 8);
        item.data     = r.data;
        item.strb     = '0;
        item.resp     = r.resp;
        mbx.put(item);
      end

    join_none
  endtask

  task automatic wait_for_idle(int num_cycles = 10);
    int x = 0;
    while (x < num_cycles) begin
      if (aw_mbx.num() == 0 && w_mbx.num() == 0 && b_mbx.num() == 0 &&
          ar_mbx.num() == 0 && r_mbx.num() == 0) begin
        x++;
      end else begin
        x = 0;
      end
      @(posedge vif.clk_i);
    end
  endtask

endclass
