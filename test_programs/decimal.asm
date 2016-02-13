; Development testbed for a decimal conversion routine
;
; * Outputs "NUM_AMOUNT" decimal numbers stored in "Numbers" as ASCII
;   encoded digits to STDOUT.
; * As it is hardcoded 16-bit: Always five digits and trailing zeros are shown
; * Uses a straightforward "divide and modulo" approach and can handle numbers
;   between 0 and 65535, i.e. the fact that the QNICE CPU works with signed
;   numbers is ignored for the sake of having the full 16-bit range.
; * Originally developed for being used in demos/q-tris.asm for displaying
;   current level, completed lines and score.
;
; Two subroutines can be extracted from this testbed:
;    DIV_AND_MODULO: 16-bit integer division with modulo
;    MAKE_DECIMAL: the actual decimal conversion routine
;
; done by sy2002 in February 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                RBRA    START, 1

NUM_AMOUNT      .EQU    20
Numbers         .DW     0, 1, 2, 3, 4, 5, 6, 7, 8, 9
                .DW     10, 100, 1000, 10000
                .DW     32768, 32767, 32769
                .DW     65534, 65535
                .DW     23976

Result_Buffer   .BLOCK 5
New_Line        .ASCII_W "\n"


START           MOVE    NUM_AMOUNT, R0
                MOVE    Numbers, R1             
                MOVE    New_Line, R2
                MOVE    0x30, R3                ; R3 = 0x30 = ASCII "0"
                MOVE    5, R4                   ; R4 = hardcoded 5 digits
                MOVE    1, R5                   ; R5 = 1 (for looping)                

NEXT_NUM        MOVE    @R1++, R8               ; retrieve current number
                MOVE    Result_Buffer, R9       ; store resulting digits in R9
                RSUB    MAKE_DECIMAL, 1         ; perform decimal conversion

                MOVE    R4, R6                  ; R6 = 5 digits overall
NEXT_DIGIT      MOVE    @R9++, R8               ; retrieve digit
                ADD     R3, R8                  ; ASCII conversion
                SYSCALL(putc, 1)                ; print one digit
                SUB     R5, R6                  ; R6 - 1: all digits done?
                RBRA    NEXT_DIGIT, !Z          ; no: next digit

                MOVE    R2, R8                  ; newline on STDOUT
                SYSCALL(puts, 1)

                SUB     R5, R0                  ; R0 - 1: all numbers done?
                RBRA    NEXT_NUM, !Z

                SYSCALL(exit, 1)

; ****************************************************************************
; MAKE_DECIMAL
;   16-bit decimal converter: Input a 16-bit number and receive a 5-element
;   list of digits between 0 and 9. Highest decimal at the lowest
;   memory address, unused leading decimals are filled with zero.
;   No overflow or sanity checks are performed.
;   performed.
;   R8: 16-bit number
;   R9: pointer to the 5-word list that will contain the decimal digits
; ****************************************************************************

MAKE_DECIMAL    INCRB

                MOVE    R8, R6                  ; preserve R8 & R9
                MOVE    R9, R7

                MOVE    10, R4                  ; R4 = 10
                XOR     R5, R5                  ; R5 = 0                

                MOVE    R9, R0                  ; R0: points to result list
                ADD     5, R0                   ; lowest digit at end of list

_MD_LOOP        MOVE    R4, R9                  ; divide by 10
                RSUB    DIV_AND_MODULO, 1       ; R8 = "shrinked" dividend
                MOVE    R9, @--R0               ; extract current digit place
                CMP     R5, R8                  ; done?
                RBRA    _MD_LOOP, !Z            ; no: next iteration

_MD_LEADING_0   CMP     R7, R0                  ; enough leading "0" there?
                RBRA    _MD_RET, Z              ; yes: return
                MOVE    0, @--R0                ; no: add a "0" digit
                RBRA    _MD_LEADING_0, 1

_MD_RET         MOVE    R6, R8                  ; restore R8 & R9
                MOVE    R7, R9
                DECRB
                RET

; ****************************************************************************
; DIV_AND_MODULO
;   16-bit integer division including modulo.
;   Ignores the sign of the dividend and the divisor.
;   Division by zero yields to an endless loop.
;   Input:
;      R8: Dividend
;      R9: Divisor
;   Output:
;      R8: Integer quotient
;      R9: Modulo
; ****************************************************************************

DIV_AND_MODULO  INCRB

                XOR     R0, R0                  ; R0 = 0

                CMP     R0, R8                  ; 0 divided by x = 0 ...
                RBRA    _DAM_START, !Z
                MOVE    R0, R9                  ; ... and the modulo is 0, too
                RBRA    _DAM_RET, 1

_DAM_START      MOVE    R9, R1                  ; R1: divisor
                MOVE    R8, R9                  ; R9: modulo
                MOVE    1, R2                   ; R2 is 1 for speeding up
                XOR     R8, R8                  ; R8: resulting int quotient

_DAM_LOOP       ADD     R2, R8                  ; calculate quotient
                SUB     R1, R9                  ; division by repeated sub.
                RBRA    _DAM_COR_OFS, V         ; wrap around: correct offset
                CMP     R0, R9
                RBRA    _DAM_RET, Z             ; zero: done and return
                RBRA    _DAM_LOOP, 1

                ; correct the values, as we did add 1 one time too much to the
                ; quotient and subtracted the divisor one time too much from
                ; the modulo for the sake of having a maxium tight inner loop
_DAM_COR_OFS    SUB     R2, R8
                ADD     R1, R9

_DAM_RET        DECRB
                RET
