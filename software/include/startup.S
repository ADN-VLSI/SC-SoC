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
    li t0, 0x00011000
    li t1, 0x00000006
    li t2, 0x0003405B
    li t3, 0x00000018
    sw t1,   0(t0)
    sw zero, 0(t0)
    sw t2,   4(t0)
    sw t3,   0(t0)
    call main

_exit:
    la   t0, tohost
    slli a0, a0, 1
    ori  a0, a0, 1
    sw   a0, 0(t0)

_forever_loop:
    j _forever_loop

.section .data
.align 4

TEST_DATA_START:
.zero 1024
TEST_DATA_END:
