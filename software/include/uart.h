#ifndef __GUARD_UART_H__
#define __GUARD_UART_H__ 0

#include "stdint.h"

#define UART_BASE                       0x00011000

#define REG_UART_CTRL  *(volatile uint32_t*)(UART_BASE+0x000)
#define REG_UART_CFG   *(volatile uint32_t*)(UART_BASE+0x004)
#define REG_UART_STAT  *(volatile uint32_t*)(UART_BASE+0x008)
#define REG_UART_TXR   *(volatile uint32_t*)(UART_BASE+0x010)
#define REG_UART_TXGP  *(volatile uint32_t*)(UART_BASE+0x014)
#define REG_UART_TXG   *(volatile uint32_t*)(UART_BASE+0x018)
#define REG_UART_TXD   *(volatile uint32_t*)(UART_BASE+0x01C)
#define REG_UART_RXR   *(volatile uint32_t*)(UART_BASE+0x020)
#define REG_UART_RXGP  *(volatile uint32_t*)(UART_BASE+0x024)
#define REG_UART_RXG   *(volatile uint32_t*)(UART_BASE+0x028)
#define REG_UART_RXD   *(volatile uint32_t*)(UART_BASE+0x02C)
#define REG_UART_INT   *(volatile uint32_t*)(UART_BASE+0x030)

void uart_init(void);

#endif
