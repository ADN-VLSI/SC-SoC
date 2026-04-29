`include "package/sc_soc_pkg.sv"

import sc_soc_pkg::*;
interface apb_if #(
    parameter int ADDR_WIDTH = sc_soc_pkg::ADDR_WIDTH,
    parameter int DATA_WIDTH = sc_soc_pkg::DATA_WIDTH
) (

    input logic arst_ni;
    input logic clk_i;
    input [ADDR_WIDTH-1:0] addr_i;
    input [DATA_WIDTH-1:0] wdata_i;
    input [(DATA_WIDTH/8)-1:0] wstrb_i= sc_soc_pkg::DATA_WIDTH/8{1'b1};
    output logic [DATA_WIDTH-1:0] rdata_o;
    output logic pready_o;
);

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  `APB_TYPEDEF_ALL(apb, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  apb_req_t apb_req;
  apb_resp_t apb_resp;

  logic psel_i;
  logic penable_i;
  logic pwrite_i;
  logic pready_o;
  logic [DATA_WIDTH-1:0] prdata_o;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

task automatic apb_read(addr_i, rdata_o, pready_o);
    pwrite_i <= '0;
    psel_i   <= '1;
    repeat (1) @(posedge clk_i); // wait for one clock cycle
    penable_i <= '1; //Then assert penable_i

    do begin
        @(posedge clk_i); // wait for the next clock cycle
    end while (pready_o == '0); // wait until pready_o is asserted
    
endtask

task automatic apb_write(addr_i, wdata_i, wstrb_i,pready_o);
    pwrite_i <= '1;
    psel_i <= '1;
    repeat (1) @(posedge clk_i); // wait for one clock cycle
    penable_i <= '1; //Then assert penable_i
    do begin
        @(posedge clk_i); // wait for the next clock cycle
    end while (pready_o == '0); // wait until pready_o is asserted
    
    
endtask









endinterface