;
;  This test program tests the basic INT and RTI instructions.
; Entry point is 0x8000 and it prints three messages denoting
; the actual program flow (prior to ISR, within ISR, and 
; after ISR).
;
#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0x8000
        MOVE    ITEST_1, R8
        SYSCALL(puts, 1)
        INT     ISR
        MOVE    ITEST_3, R8
        SYSCALL(puts, 1)
        SYSCALL(exit, 1)
        
ISR     MOVE        ITEST_2, R8
        SYSCALL(puts, 1)
        RTI

ITEST_1 .ASCII_W    "Prior to INT instruction.\n"
ITEST_2 .ASCII_W    "ISR...\n"
ITEST_3 .ASCII_W    "Back in main program.\n"

