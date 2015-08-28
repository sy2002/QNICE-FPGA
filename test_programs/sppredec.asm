                .ORG    0x0000

#include "../monitor/sysdef.asm"

                MOVE    0x8400, SP          ; setup stack pointer
                MOVE    IO$TIL_BASE, R12    ; use R12 to output values on TIL
                MOVE    0xFFAA, @R12        ; display something on TIL

                MOVE    0x8010, R0
                MOVE    0xAA, @R0
                MOVE    R0, R2

                MOVE    @R2, @--SP
                MOVE    SP, @R12

                HALT
                