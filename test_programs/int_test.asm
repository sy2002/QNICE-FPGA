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

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0x8000
        MOVE    ITEST_1, R8
        SYSCALL(puts, 1)

        MOVE    0x89AB, R8      ; Preload registers with specific values
        MOVE    0x9ABC, R9
        MOVE    0xABCD, R10
        MOVE    0xBCDE, R11
        MOVE    0xCDEF, R12
        INT     ISR_ABS         ; Test direct ISR address (this basically is @R15++)
        CMP         0x89AB, R8  ; Verify registers are not changed
        RBRA        ISR_ERR1, !Z
        CMP         0x9ABC, R9
        RBRA        ISR_ERR1, !Z
        CMP         0xABCD, R10
        RBRA        ISR_ERR1, !Z
        CMP         0xBCDE, R11
        RBRA        ISR_ERR1, !Z
        CMP         0xCDEF, R12
        RBRA        ISR_ERR1, !Z

        MOVE    ISR_REG, R8     ; Test ISR address in register
        INT     R8

        MOVE    INDIRECT, R8    ; Test indirect ISR address
        INT     @R8

        MOVE    PREDECIND_1, R8 ; Test indirect ISR address with predecrement
        INT     @--R8

        INT     @R8++           ; test postincrement during INT
        INT     @R8

        MOVE    ITEST_3, R8
        SYSCALL(puts, 1)
        SYSCALL(exit, 1)
ISR_ERR1 HALT
ISR_ERR2 HALT
        
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
ISR_REG MOVE        ITEST_2_1, R8
        SYSCALL(puts, 1)
        RTI
        HALT
ISR_IND MOVE        ITEST_2_2, R8
        SYSCALL(puts, 1)
        RTI
        HALT
ISR_PRE MOVE        R8, @--SP
        MOVE        ITEST_2_3, R8
        SYSCALL(puts, 1)
        MOVE        @SP++, R8        
        RTI
        HALT
ISR_PST MOVE        ITEST_2_4, R8
        SYSCALL(puts, 1)
        RTI
        HALT

INDIRECT    .DW         ISR_IND
PREDECIND   .DW         ISR_PRE
PREDECIND_1 .DW         ISR_PST

ITEST_1     .ASCII_W    "Start\n"
ITEST_2     .ASCII_W    "ISR_ABS\n"
ITEST_2_1   .ASCII_W    "ISR_REG\n"
ITEST_2_2   .ASCII_W    "ISR_IND\n"
ITEST_2_3   .ASCII_W    "ISR_PRE\n"
ITEST_2_4   .ASCII_W    "ISR_POST\n"
ITEST_3     .ASCII_W    "End\n"

