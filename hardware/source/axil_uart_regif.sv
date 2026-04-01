////////////////////////////////////////////////////////////////////////////////////////////////////
//
//    Module      : AXI-Lite UART Register Interface
//
//    Description : This module provides a register interface for controlling and monitoring the UART
//                  peripheral over the AXI-Lite bus.
//                  See details at document/axil_uart_regif.md
//
//    Author      : Shuparna Haque(sheikhshuparna3108@gmail.com) & Adnan Sami Anirban(adnananirban259@gmail.com)
//
//    Date        : April 1, 2026
//
////////////////////////////////////////////////////////////////////////////////////////////////////
module axil_uart_regif #(
    parameter ADDR_WIDTH = 6,   // 64 bytes = 16 registers
    parameter DATA_WIDTH = 32
)(
    // Clock and Reset
    input  logic clk_i,     // Clock input
    input  logic rst_ni,    // Active-low reset

    // AXI-Lite Write Address Channel
    input  logic [ADDR_WIDTH-1:0] awaddr_i,   // Write address
    input  logic                  awvalid_i,  // Write address valid
    output logic                  awready_o,  // Write address ready

    // AXI-Lite Write Data Channel
    input  logic [DATA_WIDTH-1:0] wdata_i,    // Write data
    input  logic [3:0]            wstrb_i,    // Write strobes
    input  logic                  wvalid_i,   // Write data valid
    output logic                  wready_o,   // Write data ready

    // AXI-Lite Write Response Channel
    output logic [1:0]            bresp_o,    // Write response
    output logic                  bvalid_o,   // Write response valid
    input  logic                  bready_i,   // Write response ready

    // AXI-Lite Read Address Channel
    input  logic [ADDR_WIDTH-1:0] araddr_i,   // Read address
    input  logic                  arvalid_i,  // Read address valid
    output logic                  arready_o,  // Read address ready

    // AXI-Lite Read Data Channel
    output logic [DATA_WIDTH-1:0] rdata_o,    // Read data
    output logic [1:0]            rresp_o,    // Read response
    output logic                  rvalid_o,   // Read data valid
    input  logic                  rready_i,   // Read data ready

    // UART Core Control Outputs
    output logic                  uart_tx_en_o,   // TX enable
    output logic                  uart_rx_en_o,   // RX enable
    output logic [11:0]           uart_clk_div_o, // Clock divider
    output logic [3:0]            uart_psclr_o,   // Prescaler
    output logic [1:0]            uart_db_o,      // Data bits
    output logic                  uart_pen_o,     // Parity enable
    output logic                  uart_ptp_o,     // Parity type
    output logic                  uart_sb_o,      // Stop bits

    // TX Path
    output logic [7:0]            tx_data_o,       // TX data byte
    output logic                  tx_data_valid_o, // TX data valid

    // RX Path
    input  logic [7:0]            rx_data_i,       // RX data byte
    input  logic                  rx_data_valid_i, // RX data valid
    output logic                  rx_pop_o,        // Pop pulse when UART_RXD is read

    // Interrupts
    output logic [3:0]            uart_int_en_o    // Interrupt enable bits
);

    // Internal registers
    logic [31:0] uart_ctrl_reg;   // Control register (0x000)
    logic [31:0] uart_cfg_reg;    // Configuration register (0x004)
    logic [31:0] uart_stat_reg;   // Status register (0x008)
    logic [31:0] uart_int_reg;    // Interrupt enable register (0x030)

    // Arbitration FIFOs (IDs stored here)
    logic [7:0] tx_req_fifo [$];  // TX request queue
    logic [7:0] rx_req_fifo [$];  // RX request queue

    // Reset behavior
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            uart_ctrl_reg <= 32'h00000000;
            uart_cfg_reg  <= 32'h0003405B;
            uart_stat_reg <= 32'h00500000;
            uart_int_reg  <= 32'h00000000;
            tx_data_o     <= 8'h00;
            tx_data_valid_o <= 1'b0;
            tx_req_fifo   <= {};
            rx_req_fifo   <= {};
        end else begin
            if (awvalid_i && wvalid_i) begin
                case (awaddr_i[ADDR_WIDTH-1:2])
                    6'h00: uart_ctrl_reg <= wdata_i;
                    6'h01: uart_cfg_reg  <= wdata_i;
                    6'h0C: uart_int_reg  <= wdata_i;
                    6'h07: begin
                        tx_data_o       <= wdata_i[7:0]; // UART_TXD
                        tx_data_valid_o <= 1'b1;
                    end
                    6'h04: tx_req_fifo.push_back(wdata_i[7:0]); // UART_TXR
                    6'h08: rx_req_fifo.push_back(wdata_i[7:0]); // UART_RXR
                    default: ;
                endcase
            end else begin
                tx_data_valid_o <= 1'b0;
            end
        end
    end

    // RX pop pulse when UART_RXD is read
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_pop_o <= 1'b0;
        end else begin
            rx_pop_o <= (arvalid_i && arready_o && araddr_i[ADDR_WIDTH-1:2] == 6'h0B);
        end
    end

    // Outputs from registers
    always_comb begin
        uart_tx_en_o   = uart_ctrl_reg[3];
        uart_rx_en_o   = uart_ctrl_reg[4];

        uart_clk_div_o = uart_cfg_reg[11:0];
        uart_psclr_o   = uart_cfg_reg[15:12];
        uart_db_o      = uart_cfg_reg[17:16];
        uart_pen_o     = uart_cfg_reg[18];
        uart_ptp_o     = uart_cfg_reg[19];
        uart_sb_o      = uart_cfg_reg[20];

        uart_int_en_o  = uart_int_reg[3:0];
    end

    // AXI read logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 1'b0;
            rresp_o  <= 2'b00;
            rdata_o  <= '0;
        end else begin
            if (arvalid_i && !rvalid_o) begin
                case (araddr_i[ADDR_WIDTH-1:2])
                    6'h00: rdata_o <= uart_ctrl_reg;
                    6'h01: rdata_o <= uart_cfg_reg;
                    6'h02: rdata_o <= uart_stat_reg;
                    6'h07: rdata_o <= {24'h0, tx_data_o}; // UART_TXD
                    6'h0B: rdata_o <= {24'h0, rx_data_i}; // UART_RXD
                    6'h0C: rdata_o <= uart_int_reg;
                    6'h05: rdata_o <= {24'h0, tx_req_fifo.size() ? tx_req_fifo[0] : 8'h00}; // UART_TXGP
                    6'h06: begin
                        rdata_o <= {24'h0, tx_req_fifo.size() ? tx_req_fifo[0] : 8'h00}; // UART_TXG
                        if (tx_req_fifo.size()) tx_req_fifo.pop_front();
                    end
                    6'h09: rdata_o <= {24'h0, rx_req_fifo.size() ? rx_req_fifo[0] : 8'h00}; // UART_RXGP
                    6'h0A: begin
                        rdata_o <= {24'h0, rx_req_fifo.size() ? rx_req_fifo[0] : 8'h00}; // UART_RXG
                        if (rx_req_fifo.size()) rx_req_fifo.pop_front();
                    end
                    default: rdata_o <= 32'h0;
                endcase
                rvalid_o <= 1'b1;
                rresp_o  <= 2'b00; // OKAY
            end else if (rvalid_o && rready_i) begin
                rvalid_o <= 1'b0;
            end
        end
    end

endmodule
