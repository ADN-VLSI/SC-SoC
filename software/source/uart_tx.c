// TODO: REMOVE. DEPRECATED BY UART.C

#include "stdio.h"

int main () {

    // Flush TX RX REGISTERS AND APPLY SOFTWARE RESET
    REG_UART_CTRL = 0x00000007;

    // DEASSERT FLUSH AND RESET
    REG_UART_CTRL = 0x00000000;

    // CONFIGURE UART (BAUDRATE 1MHz, 8N1)
    REG_UART_CFG  = 0x00031064;

    // ENABLE TX AND RX
    REG_UART_CTRL = 0x00000018;

    // REQUEST TX ACCESS
    REG_UART_TXR  = 0x00000055;

    while ((REG_UART_TXGP & 0x000000FF) != 0x55) { // WAIT FOR GRANT
        for (volatile int i = 0; i < 32; i++); // BUSY WAIT. VOLATILE TO PREVENT OPTIMIZATION
    }

    REG_UART_TXD = 'H';
    REG_UART_TXD = 'e';
    REG_UART_TXD = 'l';
    REG_UART_TXD = 'l';
    REG_UART_TXD = 'o';
    REG_UART_TXD = ' ';
    REG_UART_TXD = 'W';
    REG_UART_TXD = 'o';
    REG_UART_TXD = 'r';
    REG_UART_TXD = 'l';
    REG_UART_TXD = 'd';
    REG_UART_TXD = '.';
    REG_UART_TXD = '.';
    REG_UART_TXD = '.';
    REG_UART_TXD = '!';
    REG_UART_TXD = '\n';

    while ((REG_UART_STAT & 0x00100000) == 0x00000000) { // WAIT FOR TX FIFO TO BE EMPTY
        for (volatile int i = 0; i < 32; i++); // BUSY WAIT. VOLATILE TO PREVENT OPTIMIZATION
    }

    REG_UART_TXG; // COMPLETE GRANT

    return 0;
}
