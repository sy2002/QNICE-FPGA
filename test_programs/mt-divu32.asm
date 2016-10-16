; Test the divu32 routine of the Monitor
; derived from the original code from 32bit-div.asm
;
; done by sy2002 in Octiber 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                RBRA    START, 1

TEST_COUNT      .EQU 22

                ; dividend high low, divisor high low
TEST_NUMBERS    .DW 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF
                .DW 0xFFFF, 0xFFFF, 0x0FFF, 0xFFFF
                .DW 0xFFFF, 0xFFFF, 0x00FF, 0xFFFF
                .DW 0xFFFF, 0xFFFF, 0x000F, 0xFFFF
                .DW 0xFFFF, 0xFFFF, 0x0000, 0xFFFF
                .DW 0xFFFF, 0xFFFF, 0x0000, 0x0FFF
                .DW 0x0FFF, 0xFEAB, 0x0000, 0x0023
                .DW 0xFFFF, 0xFFFF, 0x0000, 0x000A
                .DW 0xE912, 0x0000, 0x1001, 0x1010
                .DW 0xFEDC, 0xBA98, 0x1234, 0x5678
                .DW 0x1234, 0x5678, 0x0000, 0x0001
                .DW 0x9876, 0x1234, 0x0000, 0x1234
                .DW 0xBA98, 0xABCD, 0x1234, 0x0000
                .DW 0xEEEE, 0xBABA, 0xEEEE, 0xBABA
                .DW 0xFFFF, 0xFFFF, 0xF000, 0x0000
                .DW 0xFFFF, 0xE3C3, 0xE000, 0x0001
                .DW 0xFFFF, 0xFFFF, 0x1B00, 0x1000
                .DW 0x1B3C, 0xA985, 0x1B00, 0x1000
                .DW 0x0000, 0x1000, 0x0000, 0x1000
                .DW 0x0010, 0x0000, 0x1000, 0x0000
                .DW 0x0000, 0x0001, 0x0000, 0x0001
                .DW 0xABAB, 0xCDCD, 0x0000, 0x0000

                ; result high low, modulo high low                
RESULTS         .DW 0x0000, 0x0001, 0x0000, 0x0000
                .DW 0x0000, 0x0010, 0x0000, 0x000F
                .DW 0x0000, 0x0100, 0x0000, 0x00FF
                .DW 0x0000, 0x1000, 0x0000, 0x0FFF
                .DW 0x0001, 0x0001, 0x0000, 0x0000
                .DW 0x0010, 0x0100, 0x0000, 0x00FF
                .DW 0x0075, 0x0746, 0x0000, 0x0019
                .DW 0x1999, 0x9999, 0x0000, 0x0005
                .DW 0x0000, 0x000E, 0x0903, 0x1F20
                .DW 0x0000, 0x000E, 0x0000, 0x0008
                .DW 0x1234, 0x5678, 0x0000, 0x0000
                .DW 0x0008, 0x6024, 0x0000, 0x02E4
                .DW 0x0000, 0x000A, 0x0490, 0xABCD
                .DW 0x0000, 0x0001, 0x0000, 0x0000
                .DW 0x0000, 0x0001, 0x0FFF, 0xFFFF
                .DW 0x0000, 0x0001, 0x1FFF, 0xE3C2
                .DW 0x0000, 0x0009, 0x0CFF, 0x6FFF
                .DW 0x0000, 0x0001, 0x003C, 0x9985
                .DW 0x0000, 0x0001, 0x0000, 0x0000
                .DW 0x0000, 0x0000, 0x0010, 0x0000
                .DW 0x0000, 0x0001, 0x0000, 0x0000
                .DW 0x0000, 0x0000, 0x0000, 0x0000


START           MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    TEST_COUNT, R0
                MOVE    TEST_NUMBERS, R1
                MOVE    RESULTS, R2
                    
TEST_LOOP       MOVE    @R1++, R9               ; read dividend
                MOVE    @R1++, R8
                MOVE    @R1++, R11              ; divisor
                MOVE    @R1++, R10
                MOVE    @R2++, R7               ; read correct result
                MOVE    @R2++, R6
                MOVE    @R2++, R5               ; read correct modulo
                MOVE    @R2++, R4
                RSUB    TEST_DIV, 1             ; perform the test
                SYSCALL(crlf, 1)
                SUB     1, R0
                RBRA    TEST_LOOP, !Z

                SYSCALL(exit, 1)

; prints the dividend and divisor (R8/R9 and R10/R11), tests the division
; and prints the result. Afterwards, it checks, if the result is correct
; by utilizing the given result data in R7/R6 and modulo in R5/R4 (HI .. LO)
TEST_DIV        MOVE    R4, @--SP               ; save result data
                MOVE    R5, @--SP
                MOVE    R6, @--SP
                MOVE    R7, @--SP

                INCRB

                MOVE    SP, R7                  ; save original SP so that we
                ADD     4, R7                   ; have the right return addr.
                
                MOVE    R8, R0

                MOVE    R9, R8                  ; print "x / y ="
                SYSCALL(puthex, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_DIV, R8
                SYSCALL(puts, 1)
                MOVE    R11, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                MOVE    STR_EQU, R8
                SYSCALL(puts, 1)

                MOVE    R0, R8
                SYSCALL(divu32, 1)              ; perform div and mod

                MOVE    R8, R0                  ; print 32bit result and mod
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_MOD, R8
                SYSCALL(puts, 1)
                MOVE    R11, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                MOVE    STR_COLON, R8
                SYSCALL(puts, 1)

                CMP     R9, @SP++              ; check result
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R0, @SP++
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R11, @SP++
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R10, @SP++
                RBRA    _TEST_MUL_EWR, !Z

                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                RBRA    _TEST_MUL_END, 1

_TEST_MUL_EWR   MOVE    STR_WRONG, R8
                SYSCALL(puts, 1)
                MOVE    R7, SP                 ; restore correct SP

_TEST_MUL_END   DECRB
                RET


STR_TITLE       .ASCII_P "divu32 - Monitor math library test\n"
                .ASCII_P "done by sy2002 in July 2016\n"
                .ASCII_P "32bit unsigned / 32bit unsigned = 32bit unsigned "
                .ASCII_P "and 32bit modulo\n"
                .ASCII_W "All numbers are displayed in hex. No division by zero error.\n\n"
STR_DIV         .ASCII_W " / "
STR_EQU         .ASCII_W " = "
STR_COLON       .ASCII_W " : "
STR_MOD         .ASCII_W " mod "
STR_OK          .ASCII_W "OK"
STR_WRONG       .ASCII_W "*** WRONG ***"
