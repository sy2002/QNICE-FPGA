;
;  Test the basic mathematical routines in mathlibrary.asm.
;
; As of now (12.09.2020) this is only a stub. 
;
#include "../dist_kit/sysdef.asm"

        .ORG    0x8000
; Test MTH$IN_RANGE_U: R9 and R10 define the limits against which R8 is tested:
; R9 <= R8 < R10
        MOVE    0x1000, R8
        MOVE    0x1000, R9
        MOVE    0x1000, R10
        RSUB    MTH$IN_RANGE_U, 1   ; This should leave C cleared as R8 == R10
        RBRA    IRU_1, !C
        HALT
IRU_1   MOVE    0x1000, R8
        MOVE    0x1000, R9
        MOVE    0x1001, R10
        RSUB    MTH$IN_RANGE_U, 1   ; This should set C as R8 >= R9 and R8 < R10
        RBRA    IRU_2, C
        HALT
IRU_2   MOVE    0x1000, R8
        MOVE    0x1001, R9
        MOVE    0x1010, R10
        RSUB    MTH$IN_RANGE_U, 1   ; This should clear C
        RBRA    IRU_3, !C
        HALT
IRU_3   HALT
        
#include "../monitor/math_library.asm"
