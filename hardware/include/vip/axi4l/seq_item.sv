class axi4l_seq_item;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // FIELDS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  rand logic             is_write;  // 1 for write, 0 for read

  rand logic [ 2:0]      size;  // 0 for 1 byte, 1 for 2 bytes, 2 for 4 bytes, etc.

  rand logic [63:0]      addr;

  logic      [ 7:0][7:0] data;

  logic      [ 7:0]      strb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // CONSTRAINTS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  constraint size_c {

    // Only support 4 bytes and 8 bytes for now
    size inside {2, 3};

    // Size should not exceed the data width
    size <= $clog2(cfg.data_width / 8);

  }

  constraint addr_c {

    // Address should be within the range of the configured address width
    addr < 2 ** cfg.addr_width;

    // Address should be aligned to the data width
    addr % (2 ** size) == 0;

  }

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // OBJECT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_cfg cfg;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  function new();
    cfg = new();
  endfunction

  function automatic void configure(input axi4l_cfg cfg);
    this.cfg = cfg;  // TODO CHECK. Should it be pass by reference or by value?
  endfunction

  function automatic void post_randomize();
    if (is_write) begin
      foreach (strb[i]) begin
        if (i < cfg.data_width / 8) begin
          data[i] = $urandom;
          strb[i] = $urandom;
        end else begin
          data[i] = '0;
          strb[i] = '0;
        end
      end
    end
  endfunction

  virtual function automatic string to_string();
    string data_str = "";
    foreach (data[i]) begin
      if (is_write) begin
        $sformat(data_str, "%s\n  data[%0d]: 0x%02x", data_str, i, data[i]);
        $sformat(data_str, "%s   strb[%0d]: %0d", data_str, i, strb[i]);
      end
    end
    return $sformatf(
        "AXI4-LITE Sequence Item:\n  type   : %s\n  addr   : 0x%08x\n  size   : %0d%s",
        (is_write ? "write" : "read "),
        addr,
        size,
        data_str
    );
  endfunction

  virtual function automatic void print();
    axi4l_vip_pkg::print(to_string(), 0, 3);
  endfunction

endclass
