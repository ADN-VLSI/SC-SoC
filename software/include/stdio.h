#ifndef __GUARD_STDIO_H__
#define __GUARD_STDIO_H__ 0

#include "stdarg.h"
#include "stddef.h"
#include "stdint.h"
#include "stdbool.h"

// Define constants and types
typedef int FILE;
#define stdout ((FILE *)2)
#define STDOUT_PUTC_OFFSET 0x00000000
#define MAXFP1 0xFFFFFFFF
#define HIGHBIT64 (1ull << 63)

typedef struct flags
{
    int plus;
    int space;
    int hash;
} flags_t;

typedef struct printHandler
{
    char c;
    int (*f)(va_list ap, flags_t *f);
} ph;

// Function declarations
void *memcpy(void *dest, const void *src, size_t n);
void pos_libc_putc_stdout(char c);
int fputc(int c, FILE *stream);
int puts(const char *s);
int putchar(int c);
int get_flag(char s, flags_t *f);
char *convert(unsigned long int num, int base, int lowercase);
int print_string(va_list l, flags_t *f);
int print_hex(va_list l, flags_t *f);
int print_hex_big(va_list l, flags_t *f);
int (*get_print(char s))(va_list, flags_t *);
int pos_libc_fputc_locked(int c, void *stream);
char *strchr(const char *s, int c);
void *memmove(void *d, const void *s, size_t n);
int pos_libc_prf(int (*func)(int, void *), void *dest, char *format, va_list vargs);
int pos_libc_prf_locked(int (*func)(int, void *), void *dest, char *format, va_list vargs);
int printf(char *format, ...);
double __extendsfdf2(float a);

#include "stdio.c"

#endif
