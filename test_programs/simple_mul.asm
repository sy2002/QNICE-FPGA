; Development testbed for the very simple and ignorant MUL routine
; that is used by q-tris.asm. Uses the routines from decimal.asm for being
; able to print the results.
;
; done by sy2002 in February 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                RBRA    START, 1

AMOUNT          .EQU    22

Factors         .DW     0, 0
                .DW     0, 1
                .DW     1, 0
                .DW     0, 60000
                .DW     60000, 0                
                .DW     1, 1
                .DW     2, 2
                .DW     10, 10                
                .DW     20, 20
                .DW     5, 100
                .DW     75, 75                  ; 5625
                .DW     10000, 1
                .DW     1, 10000
                .DW     125, 200                ; 25000
                .DW     35000, 1
                .DW     20, 1900                ; 38000
                .DW     1, 39000
                .DW     2, 20000
                .DW     200, 250                ; 50000
                .DW     55000, 1
                .DW     1, 58000
                .DW     13107, 5                ; 65535

Result_Buffer   .BLOCK 5
New_Line        .ASCII_W "\n"

START           MOVE    AMOUNT, R0
                MOVE    Factors, R1             
                MOVE    New_Line, R2
                MOVE    0x30, R3                ; R3 = 0x30 = ASCII "0"
                MOVE    5, R4                   ; R4 = hardcoded 5 digits
                MOVE    1, R5                   ; R5 = 1 (for looping)                

NEXT_NUM        MOVE    @R1++, R8               ; retrieve first factor
                MOVE    @R1++, R9               ; retrieve second factor
                RSUB    MUL, 1                  ; unsigned multiply (low only)
                MOVE    R10, R8
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
; MUL
;   16-bit integer multiplication, that only calculates the low-word of the
;   multiplication, i.e. (factor 1 x factor 2) needs to be smaller than
;   65535, otherwise the result wraps around. The factors as well as the
;   result are treated as unsigned.
;   Input:
;      R8: factor 1
;      R9: factor 2
;   Output:
;      R10: low word of (factor 1 x factor 2)
; ****************************************************************************

MUL             INCRB

                XOR     R10, R10                ; result = 0
                CMP     R10, R8                 ; if factor 1 = 0 ...
                RBRA    _MUL_RET, Z             ; ... then the result is 0

                MOVE    R8, R0                  ; counter for repeated adding
                MOVE    1, R1                   ; R1 = 1
                XOR     R2, R2                  ; R2 = 0

_MUL_LOOP       ADD     R9, R10                 ; multiply by rep. additions
                SUB     R1, R0                  ; are we done?
                RBRA    _MUL_COR_OFS, V         ; yes due to overflow: return
                CMP     R2, R0                  ; are we done?
                RBRA    _MUL_RET, Z             ; yes due to counter = 0
                RBRA    _MUL_LOOP, 1

_MUL_COR_OFS    SUB     R9, R10                 ; we added one time too often

_MUL_RET        DECRB
                RET

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
