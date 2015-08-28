; unit test to provoke some BRAM borderline cases
; done by sy2002 on August, 22nd 2015
;
; the unit test executes correctly, if the TIL display is showing the
; following sequence of numbers having about 1 sec delay in between
; ABAB, CDCD, EFEF, ACDC, CCCC, ACDC, EFEF, CDCD, FFFF, .... (repeat)

                .ORG 0x8000

#include "../monitor/sysdef.asm"                

RAMEXE          .EQU 0x8000
VARIABLE1       .EQU 0x80E0
STACK           .EQU 0x80FF

                MOVE STACK, SP
                MOVE IO$TIL_BASE, R12

                ; copy part of the logic to RAM
                MOVE TORAM_END, R8
                SUB TORAM_START, R8
                MOVE TORAM_START, R9
                MOVE RAMEXE, R10
                ASUB COPY_CODE, 1

                ; create the first two numbers of the seq: ABAB and CDCD
                MOVE VARIABLE1, R0
                MOVE 0xABAB, @R0
                MOVE @R0++, R1
                MOVE 0xCDCD, @R0
                MOVE @R0++, R2

                ; create EFEF, ACDC, ACDC, EFEF, CDCD, FFFF
                ; note that the "CCCC" is inserted in the display routine
                ASUB RAMEXE, 1

CONT_IN_ROM     MOVE R1, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R2, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R3, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R4, @R12
                ASUB WAIT_A_SEC, 1
                MOVE 0xCCCC, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R5, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R6, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R7, @R12
                ASUB WAIT_A_SEC, 1
                MOVE R11, @R12
                ASUB WAIT_A_SEC, 1
                ABRA CONT_IN_ROM, 1

TORAM_START     MOVE 0xEFEF, @R0
                MOVE @R0++, R3
                MOVE 0xACDC, @R0
                MOVE @R0, R4

                MOVE R4, R5
                MOVE @--R0, R6
                MOVE @--R0, R7

                ; intentionally strange to trigger some bram async reset
                MOVE @--R0, R11
                MOVE R0, R10
                MOVE R11, @R0++
                MOVE 0x5454, @R0
                MOVE @R0, @R0
                ADD @R10, @R0
                MOVE @R0, R11
                RET
TORAM_END       .BLOCK 1

#include "debug_tools.asm"