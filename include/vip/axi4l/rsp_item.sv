`ifndef __GUARD_VIP_AXI4L_RSP_ITEM_SV__
`define __GUARD_VIP_AXI4L_RSP_ITEM_SV__ 0

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
    foreach (data[i]) $sformat(data_str, "%s\n  data[%0d]:0x%02x", data_str, i, data[i]);
    return $sformatf(
        "AXI4-LITE Response Item:\n  addr   : 0x%0h\n  resp   : 0x%0h%s", addr, resp, data_str
    );
  endfunction

  virtual function automatic void print();
    axi4l_vip_pkg::print(to_string(), 0, 6);
  endfunction

endclass

`endif
