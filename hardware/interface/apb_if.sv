`ifndef __GUARD_APB_IF_SV__
`define __GUARD_APB_IF_SV__

`include "package/sc_soc_pkg.sv"

interface apb_if #(
    parameter  ADDR_WIDTH = sc_soc_pkg::ADDR_WIDTH,
    parameter  DATA_WIDTH = sc_soc_pkg::DATA_WIDTH

)
(

    input logic arst_ni,
    input logic clk_i

);
    import sc_soc_pkg::*;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
    /////////////////////////////////////////////////////////////////////////////////////////////////
   // SIGNALS
  /////////////////////////////////////////////////////////////////////////////////////////////////

  apb_req_t req;
  apb_resp_t resp;


    //////////////////////////////////////////////////////////////////////////////////////////////////
   // METHODS
  /////////////////////////////////////////////////////////////////////////////////////////////////

task automatic apb_read(
    input logic [ADDR_WIDTH-1:0] paddr,
    output logic [DATA_WIDTH-1:0] pdata
    //output logic ready
    );
    req.paddr <= paddr; 
    

    req.pwrite <= 1'b0;                                  // First, set pwrite_i to 0 for a read operation
    req.psel <= 1'b1;                                   // Then assert psel_i to select the slave
    req.penable <= 1'b0;                               // Ensure penable_i is low at the start of the read operation
    @(posedge clk_i);                                 // wait for one clock cycle
    req.penable <= 1'b1;                             //Then assert penable_i

    do begin
        @(posedge clk_i);                         // wait for the next clock cycle
    end while (resp.pready == 1'b0);             // wait until pready_o is asserted
    
    pdata = resp.prdata;                       // Connect the output data to the response structure 
    req.pwrite <= 1'b0;                       // Deassert pwrite_i after the read operation is complete
    req.psel <= 1'b0;                        // Deassert psel_i to deselect the slave
    req.penable <= 1'b0;                    // Deassert penable_i to complete the read operation


endtask

task automatic apb_write(
    input logic [ADDR_WIDTH-1:0] paddr,
    input logic [DATA_WIDTH-1:0] pdata,
    input logic [DATA_WIDTH/8-1:0] pwstrb
    //output logic ready
    );

    req.paddr <= paddr;
    req.pwdata <= pdata;                                  // Connect the input data to the request structure
    req.pstrb <= pwstrb;                                 // Connect the write strobe to the request structure
   
    req.pwrite <= 1'b1;                                // First, set pwrite_i to 1 for a write operation
    req.psel <= 1'b1;
    req.penable <= 1'b0;                             // Ensure penable_i is low at the start of the write operation
    @(posedge clk_i);                               // wait for one clock cycle
    req.penable <= 1'b1;                           //Then assert penable_i
    do begin
        @(posedge clk_i);                        // wait for the next clock cycle
    end while (resp.pready == 1'b0);            // wait until pready_o is asserted
    
    req.pwrite <= 1'b0;                       // Deassert pwrite_i after the write operation is complete
    req.psel <= 1'b0;                        // Deassert psel_i to deselect the slave
    req.penable <= 1'b0;                    // Deassert penable_i to complete the write operation
    
endtask

endinterface
