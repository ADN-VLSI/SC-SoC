#ifndef __GUARD_GPIO_H__
#define __GUARD_GPIO_H__ 0

#include "stdint.h"

#define LOW  (0)
#define HIGH (1)

#define INPUT  (0)
#define OUTPUT (1)

#define INPUT_PULLDOWN (2)
#define INPUT_PULLUP   (3)

#define GPIO_BASE                       0x00010000

#define REG_GPIO_IN    *(volatile uint32_t*)(GPIO_BASE+0x0A0)
#define REG_GPIO_OUT   *(volatile uint32_t*)(GPIO_BASE+0x0A4)
#define REG_GPIO_DIR   *(volatile uint32_t*)(GPIO_BASE+0x0A8)
#define REG_GPIO_PULL  *(volatile uint32_t*)(GPIO_BASE+0x0AC)

void gpio_init(void);
void pinMode(int pin, int mode);
void digitalWrite(int pin, int value);
int digitalRead(int pin);

#endif
