`include "package/sc_soc_pkg.sv"

interface apb_if (
    input logic arst_ni,
    input logic clk_i
);

    import sc_soc_pkg::*;
    localparam logic [31:0] UART_STAT_ADDR = UART_BASE + 32'h08;

    apb_req_t req;
    apb_resp_t resp;

    task automatic req_reset();
        req <= '0;
    endtask

    task automatic apb_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb = 4'hF
    );
            req.paddr <= addr;
            req.pprot <= 3'b000; // Normal, secure, data access
            req.psel <= '1;
            req.pwrite <= '1;
            req.pwdata <= data;
            req.pstrb <= strb;
            req.penable <= '0;
            @(posedge clk_i);
            req.penable <= '1;
            do @(posedge clk_i);
            while (!resp.pready);
            req.psel <= '0; // Deselect the slave after the transaction is complete
            req.penable <= '0;
    endtask

    task automatic apb_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
            req.paddr <= addr;
            req.pprot <= 3'b000; // Normal, secure, data access
            req.psel <= '1;
            req.pwrite <= '0;
            req.penable <= '0;
            @(posedge clk_i);
            req.penable <= '1;
            do @(posedge clk_i);
            while (!resp.pready);
            data = resp.prdata; // Capture the read data
            req.psel <= '0; // Deselect the slave after the transaction is complete
            req.penable <= '0;
    endtask

   task automatic wait_tx_empty();
        logic [31:0] stat;    // ← এখানে capture হবে
        int timeout = 0;
    
    forever begin
        apb_read(UART_STAT_ADDR, stat);  // ← stat এ prdata আসবে
        if (stat[20]) break;             // ← tx_empty bit check
        timeout++;
        if (timeout > 10000) begin
            $error("TIMEOUT: tx_empty never set");
            break;
        end
    end
    endtask

    task automatic wait_rx_data();
    logic [31:0] stat;
    int timeout = 0;
    forever begin
        apb_read(UART_STAT_ADDR, stat);
        if (!stat[22]) break;  // rx_empty=0 মানে data আছে
        timeout++;
        if (timeout > 100000) begin
            $error("TIMEOUT: rx data never arrived");
            break;
        end
    end
endtask


endinterface