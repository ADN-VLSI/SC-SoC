#include "stdio.h"

int main () {
    pinMode(0, OUTPUT);
    digitalWrite(0, HIGH);
    printf("Pin 0 set to HIGH\n");
    printf("Pin 0 Reads %d\n", digitalRead(0));
    return 0;
}
