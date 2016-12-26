; 32bit unsigned division and modulo development testbed
; divides a 32bit dividend by 32bit divisor
; outputs a 32bit result and a 32bit modulo
;
; contains a reusable function
; originally developed for the FAT32 implementation
;
; done by sy2002 in July 2016

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
                RSUB    DIVU32, 1               ; perform div and mod

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


STR_TITLE       .ASCII_P "32bit division development testbed, "
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

;=============================================================================
; REUSABLE CODE STARTS HERE
;=============================================================================
;
;*****************************************************************************
;* DIVU32 divides 32bit dividend by 32bit divisor and returns
;*        a 32bit quotient and a 32bit modulo
;*        warning: no division by zero warning; instead, the function returns
;*        zero as result and as modulo
;*
;* INPUT:  R8/R9   = LO|HI of unsigned dividend
;*         R10/R11 = LO|HI of unsigned divisor
;* OUTPUT: R8/R9   = LO|HI of unsigned quotient
;*         R10/R11 = LO|HI of unsigned modulo
;*****************************************************************************
;
DIVU32          INCRB

                ; perform the division by using the following algorithm, where
                ; N = dividend = HI|LO = R9|R8
                ; D = divisor  = HI|LO = R11|R10
                ; Q = quotient = HI|LO = R1|R0
                ; R = remainder (modulo) = HI|LO = R3|R2
                ;
                ; Q := 0               quotient and remainder = 0
                ; R := 0                     
                ; for i = n−1...0 do   where n is number of bits in N
                ;   R := R << 1        left-shift R by 1 bit
                ;   R(0) := N(i)       set the least-significant bit
                ;                      of R equal to bit i of the divisor    
                ;   if R >= D then
                ;     R := R − D
                ;     Q(i) := 1
                ;   end
                ; end                

                XOR     R0, R0                  ; HI|LO = R1|R0 = quotient
                XOR     R1, R1                  
                XOR     R2, R2                  ; HI|LO = R3|R2 = reminder
                XOR     R3, R3

                ; division by zero
                ; as we have no interrupts and no additional error flag,
                ; we return zero on a division by zero
                CMP     R11, R0
                RBRA    _DIVU32_START, !Z
                CMP     R10, R0
                RBRA    _DIVU32_START, !Z
                RBRA    _DIVU32_END, 1

_DIVU32_START   MOVE    31, R4                  ; R4 = bit counter: 31 .. 0

                ; R := R << 1: 32bit shift-left of R
_DIVU32_NEXTBIT AND     0xFFFD, SR              ; clear X (shift in '0')
                SHL     1, R2                   ; MSB of lo word shifts to C
                RBRA    _DIVU32_SHL0, !C        ; C=0 => X=0
                OR      0x0002, SR              ; C=1 => X=1
                SHL     1, R3                   ; hi word (shifts in X=1)
                RBRA    _DIVU32_RNI, 1
_DIVU32_SHL0    AND     0xFFFD, SR              ; C=0 => X=0                
                SHL     1, R3                   ; hi word (shifts in X=0)

                ; R(0) := N(i)
_DIVU32_RNI     MOVE    R4, R6
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _DIVU32_RNIL, !N        ; yes: consider low word of R
                MOVE    R9, R5                  ; high word of N
                SUB     16, R6                  ; correct index b/c of hi word
                RBRA    _DIVU32_RNIH, 1
_DIVU32_RNIL    MOVE    R8, R5                  ; low word of N
_DIVU32_RNIH    AND     0xFFFB, SR              ; clear C
                SHR     R6, R5                  ; extract bit by SHR to the ..
                AND     1, R5                   ; ..LSB pos. and and-ing 1
                AND     0xFFFE, R2              ; clear target bit and ...
                OR      R5, R2                  ; ... set it again, if needed

                ; if R >= D then
                ; done by doing 32bit R - D and checking:
                ; if MSB = 1, then R < D, else R >= D
                ; hint: MSB in this case is the 33th bit, i.e. bit #32 = carry
                MOVE    R2, R5                  ; R5 = low word of R
                MOVE    R3, R6                  ; R6 = high word of R
                SUB     R10, R5                 ; R6|R5 = 32bit (R := R - D)
                SUBC    R11, R6
                RBRA    _DIVU32_ITERATE, C      ; bit #32 is "negative"

                ; when reaching this code, R is >= D
                ;   if R >= D then
                ;     R := R − D
                ;     Q(i) := 1
                ;   end
                MOVE    R6, R3                  ; R = R6|R5 = (R := R - D)
                MOVE    R5, R2
                MOVE    1, R7                   ; Q(i) := 1 by shifting a "1"
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _DIVU32_QL, !N          ; yes: consider low word of Q
                MOVE    R4, R6                  ; R6 := i
                SUB     16, R6                  ; adjust for high word
                AND     0xFFFD, SR              ; clear X
                SHL     R6, R7                  ; move "1" to the right place
                OR      R7, R1                  ; R1:= hi Q(i) := 1
                RBRA    _DIVU32_ITERATE, 1

_DIVU32_QL      AND     0xFFFD, SR              ; clear X
                SHL     R4, R7                  ; move "1" to the right place
                OR      R7, R0                  ; R0 := low Q(i) := 1

                ; for i = n−1...0 do (i.e. also one loop for the case i=0)
_DIVU32_ITERATE SUB     1, R4
                RBRA    _DIVU32_NEXTBIT, !N     ; !N includes a round for i=0

                ; return results
_DIVU32_END     MOVE    R1, R9                  ; hi Q
                MOVE    R0, R8                  ; lo Q
                MOVE    R3, R11                 ; hi R
                MOVE    R2, R10                 ; lo R

                DECRB
                RET
