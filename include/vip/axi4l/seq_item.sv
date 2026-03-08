`ifndef __GUARD_VIP_AXI4L_SEQ_ITEM_SV__
`define __GUARD_VIP_AXI4L_SEQ_ITEM_SV__ 0

class axi4l_seq_item;

  //--------------------------------------------
  // FIELDS
  //--------------------------------------------

  rand logic [63:0]      addr;

  logic      [ 7:0][7:0] data;

  constraint addr_c {addr < 2 ** cfg.addr_width;}

  //--------------------------------------------
  // OBJECT
  //--------------------------------------------

  axi4l_cfg cfg;

  //--------------------------------------------
  // METHODS
  //--------------------------------------------

  function new();
    cfg = new();
  endfunction

  function automatic void configure(input axi4l_cfg cfg);
    this.cfg = cfg;  // TODO CHECK. Should it be pass by reference or by value?
  endfunction

  function automatic void post_randomize();
    foreach (data[i]) begin
      if (i < cfg.data_width / 8) data[i] = $urandom;
      else data[i] = 0;
    end
  endfunction

  function automatic string to_string();
    string data_str = "";
    foreach (data[i]) $sformat(data_str, "%s\n  data[%0d]:0x%02x", data_str, i, data[i]);
    return $sformatf("AXI4-LITE Sequence Item:\n  addr   : 0x%0h%s", addr, data_str);
  endfunction

  function automatic void print();
    axi4l_vip_pkg::print(to_string(), 0, 3);
  endfunction

endclass

`endif