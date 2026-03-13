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
    call main

_exit:
    la t0, tohost
    sw a0, 0(t0)

_forever_loop:
    j _forever_loop

.section .data
.align 4

TEST_DATA_START:
.zero 1024
TEST_DATA_END:
