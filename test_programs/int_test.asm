;
;  This test program tests the basic INT and RTI instructions.
; Entry point is 0x8000 and it prints three messages denoting
; the actual program flow (prior to ISR, within ISR, and 
; after ISR).
;
;  A correct run should yield this result:
;QMON> CONTROL/RUN ADDRESS=8000
;Start
;ISR_ABS
;ISR_REG
;ISR_IND
;ISR_PRE
;ISR_PRE
;ISR_POST
;End
;
;QMON> 
;
; done by vaxman and sy2002 in July/August 2020
; enhanced by MJoergen and sy2002 in October/November 2020 to fit new ISA V1.7

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        ; if being used as a test program in simulation: comment-out all
        ; SYSCALLS, use 0x0000 as start address and comment-in the 0x8000
        ; start address for the variables (below)
;        .ORG    0x0000
;        MOVE    INDIRECT, R0
;        MOVE    ISR_IND, @R0
;        MOVE    PREDECIND, R0
;        MOVE    ISR_PRE, @R0
;        MOVE    PREDECIND_1 , R0
;        MOVE    ISR_PST, @R0

        .ORG    0x8000

        MOVE    HELP_STR, R8
        SYSCALL(puts, 1)
        MOVE    ITEST_1, R8
        SYSCALL(puts, 1)

        MOVE    0x89AB, R8      ; Preload registers with specific values
        MOVE    0x9ABC, R9
        MOVE    0xABCD, R10
        MOVE    0xBCDE, R11
        MOVE    0xCDEF, R12

        ; --------------------------------------------------------------------
        ; Test direct ISR address
        ; --------------------------------------------------------------------

        INT     ISR_ABS         ; Test direct ISR address (this basically is @R15++)

        CMP     0x89AB, R8      ; Verify registers are not changed
        RBRA    ISR_ERR1, !Z
        CMP     0x9ABC, R9
        RBRA    ISR_ERR1, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1, !Z

        ; --------------------------------------------------------------------
        ; Test direct ISR address in register
        ; --------------------------------------------------------------------

        MOVE    ISR_REG, R8     ; Test ISR address in register
        INT     R8

        CMP     ISR_REG, R8     ; Verify registers are not changed
        RBRA    ISR_ERR1_2, !Z
        CMP     0x9ABC, R9
        RBRA    ISR_ERR1_2, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1_2, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1_2, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1_2, !Z

        ; --------------------------------------------------------------------
        ; Test indirect ISR address
        ; --------------------------------------------------------------------

        MOVE    INDIRECT, R8    ; Test indirect ISR address
        INT     @R8

        CMP     INDIRECT, R8    ; Verify registers are not changed
        RBRA    ISR_ERR1_3, !Z
        CMP     0x9ABC, R9
        RBRA    ISR_ERR1_3, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1_3, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1_3, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1_3, !Z

        ; --------------------------------------------------------------------
        ; Test indirect ISR with predecrement
        ; --------------------------------------------------------------------

        MOVE    PREDECIND_1, R8 ; Test indirect ISR address with predecrement
        MOVE    R8, R0
        INT     @--R8
        SUB     1, R0
        CMP     R8, R0
        RBRA    ISR_ERR3, !Z    ; Jump to ISR worked (predec worked), but then
                                ; the register was reverted back

        CMP     0x9ABC, R9      ; Verify registers are not changed
        RBRA    ISR_ERR1_4, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1_4, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1_4, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1_4, !Z

        ; --------------------------------------------------------------------
        ; Test indirect ISR with postincrement
        ; --------------------------------------------------------------------

        MOVE    R8, R0
        ADD     1, R0

        MOVE    0x1234, R9      ; flag for ISR to know that this R8 is OK

        INT     @R8++           ; test postincrement during INT

        CMP     R8, R0
        RBRA    ISR_ERR4, !Z    ; post increment did not work

        CMP     0x1234, R9      ; Verify registers are not changed
        RBRA    ISR_ERR1_5, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1_5, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1_5, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1_5, !Z

        INT     @R8

        CMP     R8, R0          ; Verify registers are not changed
        RBRA    ISR_ERR1_6, !Z
        CMP     0x1234, R9      
        RBRA    ISR_ERR1_6, !Z
        CMP     0xABCD, R10
        RBRA    ISR_ERR1_6, !Z
        CMP     0xBCDE, R11
        RBRA    ISR_ERR1_6, !Z
        CMP     0xCDEF, R12
        RBRA    ISR_ERR1_6, !Z        

        MOVE    ITEST_3, R8
        SYSCALL(puts, 1)        
        SYSCALL(exit, 1)
        HALT
        
ISR_ERR1        HALT
ISR_ERR1_2      HALT
ISR_ERR1_3      HALT
ISR_ERR1_4      HALT
ISR_ERR1_5      HALT
ISR_ERR1_6      HALT
ISR_ERR2        HALT
ISR_ERR2_2      HALT
ISR_ERR2_3      HALT
ISR_ERR2_4      HALT
ISR_ERR2_4_1    HALT
ISR_ERR2_4_2    HALT
ISR_ERR2_5      HALT
ISR_ERR2_5_1    HALT
ISR_ERR3        HALT
ISR_ERR4        HALT

        ; --------------------------------------------------------------------
        ; ISR: Direct ISR address
        ; --------------------------------------------------------------------

ISR_ABS CMP         0x89AB, R8  ; Verify registers are not changed
        RBRA        ISR_ERR2, !Z
        CMP         0x9ABC, R9
        RBRA        ISR_ERR2, !Z
        CMP         0xABCD, R10
        RBRA        ISR_ERR2, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR2, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR2, !Z

        MOVE        ITEST_2, R8
        MOVE        0x0000, R9  ; Destroy preloaded values
        MOVE        0x0000, R10
        MOVE        0x0000, R11
        MOVE        0x0000, R12
        SYSCALL(puts, 1)
        RTI
        HALT

        ; --------------------------------------------------------------------
        ; ISR: Direct ISR address in register
        ; --------------------------------------------------------------------        

ISR_REG CMP         ISR_REG, R8  ; Verify registers are not changed
        RBRA        ISR_ERR2_2, !Z
        CMP         0x9ABC, R9
        RBRA        ISR_ERR2_2, !Z
        CMP         0xABCD, R10
        RBRA        ISR_ERR2_2, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR2_2, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR2_2, !Z

        MOVE        ITEST_2_1, R8
        SYSCALL(puts, 1)
        RTI
        HALT

        ; --------------------------------------------------------------------
        ; ISR: Indirect ISR address
        ; --------------------------------------------------------------------        

ISR_IND CMP         INDIRECT, R8  ; Verify registers are not changed
        RBRA        ISR_ERR2_3, !Z
        CMP         0x9ABC, R9
        RBRA        ISR_ERR2_3, !Z
        CMP         0xABCD, R10
        RBRA        ISR_ERR2_3, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR2_3, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR2_3, !Z

        MOVE        ITEST_2_2, R8
        SYSCALL(puts, 1)
        RTI
        HALT

        ; --------------------------------------------------------------------
        ; ISR: Indirect ISR address with predecrement
        ; --------------------------------------------------------------------        

ISR_PRE CMP         0x9ABC, R9
        RBRA        ISR_PR1, Z     ; expect PREDECIND in R8

        CMP         0x1234, R9     ; expect PREDECIND_1 in R8
        RBRA        ISR_ERR2_4_1, !Z

        CMP         PREDECIND_1, R8
        RBRA        ISR_ERR2_4_2, !Z
        RBRA        ISR_PR2, 1

ISR_PR1 CMP         PREDECIND, R8  ; Verify registers are not changed
        RBRA        ISR_ERR2_4, !Z
        CMP         0x9ABC, R9
        RBRA        ISR_ERR2_4, !Z
ISR_PR2 CMP         0xABCD, R10
        RBRA        ISR_ERR2_4, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR2_4, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR2_4, !Z

        MOVE        R8, @--SP
        MOVE        ITEST_2_3, R8
        SYSCALL(puts, 1)
        MOVE        @SP++, R8        
        RTI
        HALT

        ; --------------------------------------------------------------------
        ; ISR: Indirect ISR address with postincrement
        ; --------------------------------------------------------------------        

ISR_PST CMP         PREDECIND_1, R8  ; Verify registers are not changed
        RBRA        ISR_ERR2_5_1, !Z
        CMP         0x1234, R9
        RBRA        ISR_ERR2_5, !Z
        CMP         0xABCD, R10
        RBRA        ISR_ERR2_5, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR2_5, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR2_5, !Z

        MOVE        ITEST_2_4, R8
        SYSCALL(puts, 1)
        RTI
        HALT

        ; --------------------------------------------------------------------
        ; Jump table and strings
        ; --------------------------------------------------------------------        

        ;.ORG 0x8000

INDIRECT    .DW         ISR_IND
PREDECIND   .DW         ISR_PRE
PREDECIND_1 .DW         ISR_PST

HELP_STR    .ASCII_P    "Test software interrupts.\n"
            .ASCII_P    "The correct output of this program should look like this:\n\n"
            .ASCII_P    "Start\nISR_ABS\nISR_REG\nISR_IND\nISR_PRE\nISR_PRE\nISR_POST\nEnd\n"
            .ASCII_W    "======================== OUTPUT: ========================\n"

ITEST_1     .ASCII_W    "Start\n"
ITEST_2     .ASCII_W    "ISR_ABS\n"
ITEST_2_1   .ASCII_W    "ISR_REG\n"
ITEST_2_2   .ASCII_W    "ISR_IND\n"
ITEST_2_3   .ASCII_W    "ISR_PRE\n"
ITEST_2_4   .ASCII_W    "ISR_POST\n"
ITEST_3     .ASCII_W    "End\n"

