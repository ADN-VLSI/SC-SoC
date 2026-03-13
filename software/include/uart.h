#ifndef __GUARD_UART_H__
#define __GUARD_UART_H__ 0

#include "stdint.h"

#define DHS_UART_BASE               0x20001000

#define REG_DHS_UART_CTRL               *(volatile uint32_t*)(DHS_UART_BASE+0x00)
#define REG_DHS_UART_CFG                *(volatile uint32_t*)(DHS_UART_BASE+0x04)
#define REG_DHS_UART_CLK_DIV            *(volatile uint32_t*)(DHS_UART_BASE+0x08)
#define REG_DHS_UART_TX_FIFO_STAT       *(volatile uint32_t*)(DHS_UART_BASE+0x0C)
#define REG_DHS_UART_RX_FIFO_STAT       *(volatile uint32_t*)(DHS_UART_BASE+0x10)
#define REG_DHS_UART_TX_FIFO_DATA       *(volatile uint32_t*)(DHS_UART_BASE+0x14)
#define REG_DHS_UART_RX_FIFO_DATA       *(volatile uint32_t*)(DHS_UART_BASE+0x18)
#define REG_DHS_UART_RX_FIFO_PEEK       *(volatile uint32_t*)(DHS_UART_BASE+0x1C)
#define REG_DHS_UART_ACCESS_ID_REQ      *(volatile uint32_t*)(DHS_UART_BASE+0x20)
#define REG_DHS_UART_ACCESS_ID_GNT      *(volatile uint32_t*)(DHS_UART_BASE+0x24)
#define REG_DHS_UART_ACCESS_ID_GNT_PEEK *(volatile uint32_t*)(DHS_UART_BASE+0x28)

#endif
