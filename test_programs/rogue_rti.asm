;
;  This test program tests the behaviour of the processor in
; case of a rogue RTI instruction, i.e. an RTI issued while
; not processing an interrupt request. This should result in 
; executing a HALT-instruction.
;
#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

        .ORG    0x8000
        RTI
        SYSCALL(exit, 1)
