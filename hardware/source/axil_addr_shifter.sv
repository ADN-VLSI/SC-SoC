module axil_addr_shifter #(
    parameter type    slv_port_req_t  = logic,
    parameter type    slv_port_resp_t = logic,
    parameter type    mst_port_req_t  = logic,
    parameter type    mst_port_resp_t = logic,
    parameter longint SHIFT           = 0
) (
    input  slv_port_req_t  slv_port_req_i,
    output slv_port_resp_t slv_port_resp_o,
    output mst_port_req_t  mst_port_req_o,
    input  mst_port_resp_t mst_port_resp_i
);

  assign mst_port_req_o.aw.addr   = slv_port_req_i.aw.addr + SHIFT;
  assign mst_port_req_o.aw.prot   = slv_port_req_i.aw.prot;
  assign mst_port_req_o.aw_valid  = slv_port_req_i.aw_valid;
  assign slv_port_resp_o.aw_ready = mst_port_resp_i.aw_ready;

  assign mst_port_req_o.w.data    = slv_port_req_i.w.data;
  assign mst_port_req_o.w.strb    = slv_port_req_i.w.strb;
  assign mst_port_req_o.w_valid   = slv_port_req_i.w_valid;
  assign slv_port_resp_o.w_ready  = mst_port_resp_i.w_ready;

  assign slv_port_resp_o.b.resp   = mst_port_resp_i.b.resp;
  assign slv_port_resp_o.b_valid  = mst_port_resp_i.b_valid;
  assign mst_port_req_o.b_ready   = slv_port_req_i.b_ready;

  assign mst_port_req_o.ar.addr   = slv_port_req_i.ar.addr + SHIFT;
  assign mst_port_req_o.ar.prot   = slv_port_req_i.ar.prot;
  assign mst_port_req_o.ar_valid  = slv_port_req_i.ar_valid;
  assign slv_port_resp_o.ar_ready = mst_port_resp_i.ar_ready;

  assign slv_port_resp_o.r.data   = mst_port_resp_i.r.data;
  assign slv_port_resp_o.r.resp   = mst_port_resp_i.r.resp;
  assign slv_port_resp_o.r_valid  = mst_port_resp_i.r_valid;
  assign mst_port_req_o.r_ready   = slv_port_req_i.r_ready;

endmodule
