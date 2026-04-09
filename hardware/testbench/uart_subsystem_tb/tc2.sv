// -----------------------------------------------------------------------------
// TC2: AXI Basic Read/Write Test
// -----------------------------------------------------------------------------

import uart_pkg::*;
import uart_subsystem_pkg::*;

task automatic tc2();
    logic [31:0] read_data;
    logic [1:0]  resp;

    $display("\n[tc2] AXI Basic Read/Write Test");

    
    axi_write(UART_CTRL_OFFSET, 32'h0);
    repeat(10) @(posedge clk_i);

    // Test CTRL register (bits 4:3 are sticky: rx_en, tx_en)
    cpu_write_32(UART_CTRL_OFFSET, 32'h18, resp);
    check((resp == 2'b00), "CTRL write response OK");
    cpu_read_32(UART_CTRL_OFFSET, read_data, resp);
    check((read_data == 32'h18), "CTRL readback OK");

    // Test CFG register
    cpu_write_32(UART_CFG_OFFSET, 32'h0010_0271, resp);
    check((resp == 2'b00), "CFG write response OK");
    cpu_read_32(UART_CFG_OFFSET, read_data, resp);
    check((read_data == 32'h0010_0271), "CFG readback OK");

    // Test INT_EN register
    cpu_write_32(UART_INT_EN_OFFSET, 32'h0F, resp);
    check((resp == 2'b00), "INT_EN write response OK");
    cpu_read_32(UART_INT_EN_OFFSET, read_data, resp);
    check((read_data == 32'h0F), "INT_EN readback OK");

    // Test STAT is read-only
    cpu_read_32(UART_STAT_OFFSET, read_data, resp);
    check((resp == 2'b00), "STAT read OK");

    // Clear registers
    cpu_write_32(UART_CTRL_OFFSET, 32'h0, resp);
    cpu_write_32(UART_INT_EN_OFFSET, 32'h0, resp);
    
    $display("[tc2] Completed");
endtask