`ifndef __GUARD_VIP_AXI4L_CFG_SVH__
`define __GUARD_VIP_AXI4L_CFG_SVH__ 0

  class axi4l_cfg;

    //--------------------------------------------
    // FIELDS
    //--------------------------------------------

    int unsigned addr_width = 32;
    int unsigned data_width = 32;

    //--------------------------------------------
    // METHODS
    //--------------------------------------------

    virtual function automatic string to_string();
      return $sformatf(
        "AXI4-LITE Configuration:\n  addr_width: %0d bits\n  data_width: %0d bits",
        addr_width, data_width);
    endfunction

    virtual function automatic void print();
      axi4l_vip_pkg::print(to_string(), 1, 5);
    endfunction

  endclass

`endif
