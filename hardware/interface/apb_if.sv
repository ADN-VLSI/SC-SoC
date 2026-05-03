`include "package/sc_soc_pkg.sv"
import sc_soc_pkg::*;


interface apb_if #(
    parameter type ADDR_WIDTH = sc_soc_pkg::ADDR_WIDTH,
    parameter type DATA_WIDTH = sc_soc_pkg::DATA_WIDTH

);
(

    input logic arst_ni,
    input logic clk_i
    /*input [ADDR_WIDTH-1:0] addr_i;
    input [DATA_WIDTH-1:0] wdata_i;
    input [(DATA_WIDTH/8)-1:0] wstrb_i= sc_soc_pkg::DATA_WIDTH/8{1'b1};
    output logic [DATA_WIDTH-1:0] rdata_o;
    output logic pready_o; */
);


  //////////////////////////////////////////////////////////////////////////////////////////////////
  // TYPEDEFS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  //`APB_TYPEDEF_ALL(apb, logic[ADDR_WIDTH-1:0], logic[DATA_WIDTH-1:0], logic[DATA_WIDTH/8-1:0])

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // SIGNALS
  //////////////////////////////////////////////////////////////////////////////////////////////////

  apb_req_t req;
  apb_resp_t resp;


/*logic psel_i;
  logic penable_i;
  logic pwrite_i;
  logic pready_o;
  logic [DATA_WIDTH-1:0] prdata_o; */

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // METHODS
  //////////////////////////////////////////////////////////////////////////////////////////////////

task automatic apb_read(
    input logic [ADDR_WIDTH-1:0] req.paddr,
    output logic [DATA_WIDTH-1:0] req.rdata,
    output logic resp.pready
    );

    req.pwrite <= 1'b0; // First, set pwrite_i to 0 for a read operation
    req.psel <= 1'b1; // Then assert psel_i to select the slave
    @(posedge clk_i); // wait for one clock cycle
    req.penable <= 1'b1; //Then assert penable_i

    do begin
        @(posedge clk_i); // wait for the next clock cycle
    end while (resp.pready == 1'b0); // wait until pready_o is asserted
    
endtask

task automatic apb_write(
    input logic [ADDR_WIDTH-1:0] req.paddr,
    input logic [DATA_WIDTH-1:0] req.pwdata,
    input logic [DATA_WIDTH/8-1:0] req.pwstrb,
    output logic resp.pready
    );
    req.pwrite <= 1'b1;
    req.psel <= 1'b1;
    @(posedge clk_i); // wait for one clock cycle
    req.penable <= 1'b1; //Then assert penable_i
    do begin
        @(posedge clk_i); // wait for the next clock cycle
    end while (resp.pready == 1'b0); // wait until pready_o is asserted
    
    
endtask









endinterface