#ifndef __GUARD_UART_C__
#define __GUARD_UART_C__ 0

#include "uart.h"

void uart_init(void)
{
    REG_UART_CTRL = 0x00000006;
    REG_UART_CTRL = 0x00000000;
    REG_UART_CFG  = 0x0003405B;
    REG_UART_CTRL = 0x00000018;
}

#endif
