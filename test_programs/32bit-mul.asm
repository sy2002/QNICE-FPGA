; 32bit unsigned multiplication development testbed
; multiplies two 32bit numbers using the 16bit multiplication of the monitor
;
; contains a reusable function
; originally developed for the FAT32 implementation
;
; done by sy2002 in June 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                RBRA    START, 1

TEST_COUNT      .EQU 9

                ; multiplicant 1 HI, mult. 1 LO, mult. 2 HI, mult. 2 LO 
TEST_NUMBERS    .DW 0x1234, 0x5678, 0xABCD, 0xEFFF
                .DW 0x0000, 0x1A1B, 0x0000, 0xF040
                .DW 0x0000, 0x0023, 0x0000, 0x0009
                .DW 0x2309, 0x1976, 0xFFFF, 0xEEEE
                .DW 0xAAAA, 0x3038, 0xBABA, 0x4352
                .DW 0xFEDC, 0xBA98, 0x7654, 0x3210
                .DW 0x1010, 0x2020, 0x3030, 0x4040
                .DW 0x0000, 0x0000, 0x0000, 0x0000
                .DW 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF

                ; contains the 64bit results for each row above
                ; big endian
RESULTS         .DW 0x0C37, 0x9ABC, 0x64F4, 0x2988
                .DW 0x0000, 0x0000, 0x187F, 0xD6C0
                .DW 0x0000, 0x0000, 0x0000, 0x013B
                .DW 0x2309, 0x171F, 0xEEAB, 0x5FB4
                .DW 0x7C7B, 0xD390, 0xEDD2, 0x19F0
                .DW 0x75CD, 0x9046, 0x541D, 0x5980
                .DW 0x0306, 0x0D14, 0x1210, 0x0800
                .DW 0x0000, 0x0000, 0x0000, 0x0000
                .DW 0xFFFF, 0xFFFE, 0x0000, 0x0001

START           MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    TEST_COUNT, R0
                MOVE    TEST_NUMBERS, R1
                MOVE    RESULTS, R2
                    
TEST_LOOP       MOVE    @R1++, R9               ; read multiplicant 1
                MOVE    @R1++, R8
                MOVE    @R1++, R11              ; read multiplicant 2
                MOVE    @R1++, R10
                MOVE    @R2++, R7               ; read correct result
                MOVE    @R2++, R6
                MOVE    @R2++, R5
                MOVE    @R2++, R4
                RSUB    TEST_MUL, 1             ; perform the test
                SYSCALL(crlf, 1)
                SUB     1, R0
                RBRA    TEST_LOOP, !Z

                SYSCALL(exit, 1)

; prints the multiplicants (R8/R9 and R10/R11), tests the multiplication
; and prints the result. Afterwards, it checks, if the result is correct
; by utilizing the given result data in R7/R6/R5/R4 (HI .. LO)
TEST_MUL        MOVE    R4, @--SP               ; save result data
                MOVE    R5, @--SP
                MOVE    R6, @--SP
                MOVE    R7, @--SP

                INCRB

                MOVE    SP, R7                  ; save original SP so that we
                ADD     4, R7                   ; have the right return addr.
                
                MOVE    R8, R0

                MOVE    R9, R8                  ; print "x * y ="
                SYSCALL(puthex, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_MUL, R8
                SYSCALL(puts, 1)
                MOVE    R11, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                MOVE    STR_EQU,R8
                SYSCALL(puts, 1)

                MOVE    R0, R8
                RSUB    MULU32, 1               ; 32bit * 32bit = 64bit mult.

                MOVE    R8, R0                  ; print 64bit result
                MOVE    R11, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_COLON, R8
                SYSCALL(puts, 1)

                CMP     R11, @SP++              ; check result
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R10, @SP++
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R9, @SP++
                RBRA    _TEST_MUL_EWR, !Z
                CMP     R0, @SP++
                RBRA    _TEST_MUL_EWR, !Z

                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                RBRA    _TEST_MUL_END, 1

_TEST_MUL_EWR   MOVE    STR_WRONG, R8
                SYSCALL(puts, 1)
                MOVE    R7, SP                 ; restore correct SP

_TEST_MUL_END   DECRB
                RET


STR_TITLE       .ASCII_P "32bit multiplication development testbed, "
                .ASCII_P "done by sy2002 in June 2016\n"
                .ASCII_P "32bit unsigned x 32bit unsigned = 64bit unsigned\n"
                .ASCII_W "All numbers are displayed in hex\n\n"
STR_MUL         .ASCII_W " * "
STR_EQU         .ASCII_W " = "
STR_COLON       .ASCII_W " : "
STR_OK          .ASCII_W "OK"
STR_WRONG       .ASCII_W "*** WRONG ***"

;=============================================================================
; REUSABLE CODE STARTS HERE
;=============================================================================
;
;*****************************************************************************
;* MULU32 multiplies two 32bit unsigned values and returns a 64bit unsigned
;*
;* Input:  R8/R9   = LO/HI of unsigned multiplicant 1
;*         R10/R11 = LO/HI of unsigned multiplicant 2
;* Output: R11/R10/R9/R8 = HI .. LO of 64bit result
;*****************************************************************************
;
MULU32          INCRB                           ; registers R3..R0 = result ..
                INCRB                           ; .. therefore two INCRBs

                ; save arguments as in R1|R0 * R3|R2
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                ; algorithm:
                ;       R1R0
                ; x     R3R2
                ; ----------
                ;       R2R0
                ; +   R2R1
                ; +   R3R0
                ; + R3R1
                ; ----------

                MOVE    R0, R8                  ; R2 * R0
                MOVE    R2, R9
                SYSCALL(mulu, 1)                ; result in R11|R10
                DECRB
                MOVE    R10, R0
                MOVE    R11, R1
                XOR     R2, R2
                XOR     R3, R3
                INCRB

                MOVE    R1, R8                  ; R2 * R1
                MOVE    R2, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R0, R8                  ; R3 * R0
                MOVE    R3, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R1, R8                  ; R3 * R1
                MOVE    R3, R9
                SYSCALL(mulu, 1)
                DECRB
                ADD     R10, R2
                ADDC    R11, R3

                MOVE    R3, R11                 ; store result (return values)
                MOVE    R2, R10
                MOVE    R1, R9
                MOVE    R0, R8

                DECRB
                RET
