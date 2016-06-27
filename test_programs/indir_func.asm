; Test indirect function calls, i.e. setup pointers to functions that
; are then called using a MOVE operation. Before the function call, the
; return stack is being setup manually.
;
; done by sy2002 in June 2015

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                RBRA    START, 1

INDIR_TABLE     .BLOCK 16                       ; table of function pointers
INDIR_ADD       .EQU 0                          ; rel. address in INDIR_TABLE   
INDIR_PRINT     .EQU 1

STR_BEFORE      .ASCII_W "BEFORE double indir func call\n"
STR_AFTER       .ASCII_W "AFTER double indir func call\n"

START           MOVE    INDIR_TABLE, R10        ; TEST2 expects addr. in R10
                MOVE    R10, R0                 ; work with R0 to fill table
                MOVE    TEST1, @R0++            ; store first function pointer
                MOVE    TEST2, @R0              ; store second func. pointer

                MOVE    STR_BEFORE, R8          ; print "before..." message
                SYSCALL(puts, 1)

                MOVE    _GO_ON, @--SP           ; manual SP handling needed to
                                                ; save the return address
                MOVE    0x0023, R8              ; parameters for sum
                MOVE    0x0009, R9
                MOVE    INDIR_TABLE, R0         ; compute print function
                ADD     INDIR_PRINT, R0                
                MOVE    @R0, PC                 ; jump to function

_GO_ON          MOVE    STR_AFTER, R8
                SYSCALL(puts, 1)

                SYSCALL(exit, 1)                ; back to monitor

; test routine 1, that is called indirectly. It computes the sum of R8 and R9
; and returns the result in R8
TEST1           INCRB

                ADD     R9, R8

                DECRB
                RET

; test routine 2, that is called indirectly. It outputs the message
; "the sum of <R8> and <R9> is <result>" while filling <R8>, <R9> and <result>
; with the correct values. It utilizes the TEST1 routine, but does so using
; the global indirection table that is located at R10
TEST2           INCRB

                MOVE    R8, R0

                MOVE    _TEST2_STR1, R8
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    _TEST2_STR2, R8
                SYSCALL(puts, 1)
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                MOVE    _TEST2_STR3, R8
                SYSCALL(puts, 1)

                MOVE    R10, R1
                ADD     INDIR_ADD, R1           ; compute function address
                MOVE    _TEST2_GO_ON, @--SP     ; save return address
                MOVE    R0, R8                  ; first summand, 2nd is in R9
                MOVE    @R1, PC                 ; call function

_TEST2_GO_ON    SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                DECRB
                RET

_TEST2_STR1     .ASCII_W "The sum of "
_TEST2_STR2     .ASCII_W " and "
_TEST2_STR3     .ASCII_W " is "
