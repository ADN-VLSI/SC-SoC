#include "stdio.h"

int main () {
  char name[100];
  printf("What is your name?\n");
  scanf("%s", name);
  printf("Hello, %s!\n", name);
  printf("Nice to meet you..!\n");
  return 0;
}
