#ifndef __GUARD_GPIO_C__
#define __GUARD_GPIO_C__ 0

#include "gpio.h"

void gpio_init(void) {

    REG_GPIO_OUT  = 0x00000000;
    REG_GPIO_DIR  = 0x00000000;
    REG_GPIO_PULL = 0x00000000;

}

void pinMode(int pin, int mode) {
  int _mode = mode & 0x03;
  int val_mask = 1 << pin;
  if (_mode == OUTPUT) {
    REG_GPIO_DIR |= val_mask;
  } else {
    REG_GPIO_DIR &= ~val_mask;
  }

  if (_mode == INPUT_PULLUP) {
    REG_GPIO_PULL |= val_mask;
    REG_GPIO_OUT  |= val_mask;
  } else if (_mode == INPUT_PULLDOWN) {
    REG_GPIO_PULL |= val_mask;
    REG_GPIO_OUT  &= ~val_mask;
  } else {
    REG_GPIO_PULL &= ~val_mask;
  }
}

void digitalWrite(int pin, int value) {
  int val_mask = 1 << pin;
  if (value) {
    REG_GPIO_OUT |= val_mask;
  } else {
    REG_GPIO_OUT &= ~val_mask;
  }
}

int digitalRead(int pin) {
  int val_mask = 1 << pin;
  return (REG_GPIO_IN & val_mask) ? HIGH : LOW;
}

#endif
