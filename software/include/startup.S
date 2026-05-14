.section .data

.align 3
.globl tohost
tohost: .dword 0

.align 3
.globl fromhost
fromhost: .dword 0

.section .text
.globl _start
_start:
    la sp, __stack_top
    csrc 0x320, 1
    call uart_init
    call main

_exit:
    la  t0, tohost
    li  a1, 0x80000000
    or  a0, a0, a1
    sw  a0, 0(t0)

_forever_loop:
    j _forever_loop

.section .data
.align 4

TEST_DATA_START:
.zero 1024
TEST_DATA_END:
