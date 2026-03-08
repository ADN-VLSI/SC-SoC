`include "axi4l/typedef.svh"

module axil_mem_tb;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // LOCAL PARAMETERS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ADDR_WIDTH = 16;
  localparam int DATA_WIDTH = 32;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPE DEFINITIONS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `AXI4L_ALL(my, ADDR_WIDTH, DATA_WIDTH)

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic arst_ni;
  logic clk_i;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // INTERFACES
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axi4l_if #(
      .req_t(my_req_t),
      .rsp_t(my_rsp_t)
  ) intf (
      .arst_ni(arst_ni),
      .clk_i  (clk_i)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT
  //////////////////////////////////////////////////////////////////////////////////////////////////

  axil_mem #(
      .axi4l_req_t(my_req_t),
      .axi4l_rsp_t(my_rsp_t),
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH)
  ) u_mem (
      .arst_ni(arst_ni),
      .clk_i(clk_i),
      .axi4l_req_i(intf.req),
      .axi4l_rsp_o(intf.rsp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  task automatic write_32(input bit [15:0] addr, input bit [31:0] data);
    bit [1:0] resp;
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({data, 4'b1111});
      intf.recv_b(resp);
    join
  endtask

  task automatic write_16(input bit [15:0] addr, input bit [15:0] data);
    bit [ 1:0] resp;
    bit [31:0] wdata;
    bit [ 3:0] wstrb;
    wstrb = 4'b11 << (addr % 4);
    wdata = data;
    wdata = wdata << ((addr % 4) * 8);
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({wdata, wstrb});
      intf.recv_b(resp);
    join
  endtask

  task automatic write_8(input bit [15:0] addr, input bit [7:0] data);
    bit [ 1:0] resp;
    bit [31:0] wdata;
    bit [ 3:0] wstrb;
    wstrb = 4'b1 << (addr % 4);
    wdata = data;
    wdata = wdata << ((addr % 4) * 8);
    fork
      intf.send_aw({addr, 3'h0});
      intf.send_w({wdata, wstrb});
      intf.recv_b(resp);
    join
  endtask

  task automatic read_32(input bit [15:0] addr, output bit [31:0] data);
    bit [1:0] resp;
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r({data, resp});
    join
  endtask

  task automatic read_16(input bit [15:0] addr, output bit [15:0] data);
    bit [ 1:0] resp;
    bit [31:0] rdata;
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r({rdata, resp});
    join
    data = rdata >> ((addr % 4) * 8);
  endtask

  task automatic read_8(input bit [15:0] addr, output bit [7:0] data);
    bit [ 1:0] resp;
    bit [31:0] rdata;
    fork
      intf.send_ar({addr, 3'h0});
      intf.recv_r({rdata, resp});
    join
    data = rdata >> ((addr % 4) * 8);
  endtask

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // PROCEDURAL
  //////////////////////////////////////////////////////////////////////////////////////////////////

  initial begin

    automatic bit [31:0] data;

    $timeformat(-9, 1, " ns", 20);
    $dumpfile("axil_mem_tb.vcd");
    $dumpvars(0, axil_mem_tb);

    clk_i   <= '0;
    arst_ni <= '0;
    intf.req_reset();
    #20;
    arst_ni <= '1;
    #20;
    fork
      forever #5 clk_i <= ~clk_i;
    join_none

    @(posedge clk_i);

    write_16(1, 'hABCD);

    repeat (5) @(posedge clk_i);

    read_32(0, data);

    $display("R32 0 DATA:0x%h", data);

    read_16(1, data);

    $display("R16 1 DATA:0x%h", data);

    read_8(2, data);

    $display("R8 2 DATA:0x%h", data);

    repeat (20) @(posedge clk_i);

    $finish;

  end

endmodule
