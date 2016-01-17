; 32-bit subtraction test
; done by sy2002 in January 2016

                .ORG 0x8000

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                MOVE    IO$TIL_DISPLAY, R10

                MOVE    0, R1
                MOVE    80, R0

                MOVE    0, R3
                MOVE    60000, R2

                SUB     R2, R0
                MOVE    R0, @R10
                SYSCALL(getc, 1)

                MOVE    0xACAC, @R10
                SYSCALL(getc, 1)

                MOVE    0, R1
                MOVE    80, R0

                MOVE    0, R3
                MOVE    60000, R2

                SUB     R2, R0
                SUBC    R3, R1
                MOVE    R0, @R10
                SYSCALL(getc, 1)
                MOVE    R1, @R10
                SYSCALL(getc, 1)

                MOVE    0, @R10
                SYSCALL(exit, 1)
