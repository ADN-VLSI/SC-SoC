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

    REG_UART_RXR = 0x000000AA; // REQUEST RX ACCESS

    while ((REG_UART_RXGP & 0x000000FF) != 0xAA) { // WAIT FOR GRANT
        for (volatile int i = 0; i < 32; i++); // BUSY WAIT. VOLATILE TO PREVENT OPTIMIZATION
    }
    
    while (((REG_UART_STAT & 0x000FFC00)>>10) != 0x00000010) { // WAIT FOR RX FIFO TO BE NOT EMPTY
        for (volatile int i = 0; i < 32; i++); // BUSY WAIT. VOLATILE TO PREVENT OPTIMIZATION
    }

    int error = 0;
    if (REG_UART_RXD & 0x000000FF != 'H')  error |= 0x00000001;
    if (REG_UART_RXD & 0x000000FF != 'e')  error |= 0x00000002;
    if (REG_UART_RXD & 0x000000FF != 'l')  error |= 0x00000004;
    if (REG_UART_RXD & 0x000000FF != 'l')  error |= 0x00000008;
    if (REG_UART_RXD & 0x000000FF != 'o')  error |= 0x00000010;
    if (REG_UART_RXD & 0x000000FF != ' ')  error |= 0x00000020;
    if (REG_UART_RXD & 0x000000FF != 'W')  error |= 0x00000040;
    if (REG_UART_RXD & 0x000000FF != 'o')  error |= 0x00000080;
    if (REG_UART_RXD & 0x000000FF != 'r')  error |= 0x00000100;
    if (REG_UART_RXD & 0x000000FF != 'l')  error |= 0x00000200;
    if (REG_UART_RXD & 0x000000FF != 'd')  error |= 0x00000400;
    if (REG_UART_RXD & 0x000000FF != '.')  error |= 0x00000800;
    if (REG_UART_RXD & 0x000000FF != '.')  error |= 0x00001000;
    if (REG_UART_RXD & 0x000000FF != '.')  error |= 0x00002000;
    if (REG_UART_RXD & 0x000000FF != '!')  error |= 0x00004000;
    if (REG_UART_RXD & 0x000000FF != '\n') error |= 0x00008000;

    return error;
}
