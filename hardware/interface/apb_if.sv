`include "package/sc_soc_pkg.sv"

interface apb_if (
    input logic arst_ni,
    input logic clk_i
);

  import sc_soc_pkg::*;
  //   localparam logic [31:0] UART_STAT_ADDR = UART_BASE + 32'h08;

  apb_req_t req;
  apb_resp_t resp;

  bit is_edge_aligned;

  always @(posedge clk_i) begin
    is_edge_aligned = '1;
    #1ns;
    is_edge_aligned = '0;
  end

  task automatic req_reset();
    req <= '0;
  endtask

  task automatic apb_write(input logic [31:0] addr, input logic [31:0] data,
                           input logic [3:0] strb = 4'hF);
    wait (is_edge_aligned);  // Ensure the transaction starts on an edge-aligned cycle
    req.paddr <= addr;
    req.pprot <= 3'b000;  // Normal, secure, data access
    req.psel <= '1;
    req.pwrite <= '1;
    req.pwdata <= data;
    req.pstrb <= strb;
    req.penable <= '0;
    @(posedge clk_i);
    req.penable <= '1;
    do @(posedge clk_i); while (!resp.pready);
    req.psel <= '0;  // Deselect the slave after the transaction is complete
  endtask

  task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
    wait (is_edge_aligned);  // Ensure the transaction starts on an edge-aligned cycle
    req.paddr <= addr;
    req.pprot <= 3'b000;  // Normal, secure, data access
    req.psel <= '1;
    req.pwrite <= '0;
    req.penable <= '0;
    @(posedge clk_i);
    req.penable <= '1;
    do @(posedge clk_i); while (!resp.pready);
    data = resp.prdata;  // Capture the read data
    req.psel <= '0;  // Deselect the slave after the transaction is complete
  endtask

  task automatic wait_till_idle(int idle_cycles = 10);
    int i;
    while (i < idle_cycles) begin
      @(posedge clk_i);
      i++;
      if (req.psel != 1) i = 0;
    end
  endtask

endinterface
