class axi4l_rsp_item extends axi4l_seq_item;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // FIELDS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic [1:0] resp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  virtual function automatic string to_string();
    string data_str = "";
    foreach (data[i]) begin
      $sformat(data_str, "%s\n  data[%0d]: 0x%02x", data_str, i, data[i]);
      if (is_write) begin
        $sformat(data_str, "%s   strb[%0d]: %0d", data_str, i, strb[i]);
      end
    end
    return $sformatf(
        "AXI4-LITE Response Item:\n  type   : %s\n  addr   : 0x%08x\n  size   : %0d\n  resp   : %0d%s",
        (is_write ? "write" : "read "),
        addr,
        size,
        resp,
        data_str
    );
  endfunction

  virtual function automatic void print();
    axi4l_vip_pkg::print(to_string(), 0, 6);
  endfunction

endclass
