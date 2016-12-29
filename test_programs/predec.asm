; Test pre-decrement-indirect-and-then-work-with-it
;
; This test program was used to document and to test, after in Release 1.4
; a CPU bug was discovered, that lead to the strange effect, that in the
; emulator, things like "F" "R" qbin/mandel.out did not work, but in hardware
; it indeed did work. At first, this looked like an emulator bug, but in the
; end it became clear, that the FAT32 implementation relied on a CPU bug to
; work correctly :-)
;
; The original sdcard.asm (and therefore the Monitor's FAT32 implementation)
; contained a statement like this:
;
; ============================================================================
;                ADD     @--R4, R4              ; R4 was incremented to skip..
;                                               ; ..the length information, ..
;                                               ; ..so we need to predecr. ..
;                                               ; ..and then increase the ..
;                                               ; ..pointer to the next segm.                                                
; ============================================================================
;
; It expected from the CPU the following semantics:
;
; ============================================================================
;       int* a = r4;
;       int* b = r4;
;       --a;
;       b += (*a);
;       r4 = b;
; ============================================================================
;
; In other words: It relied on a CPU bug, that had the implication that the
; second operand still had the old value, even when pre-decremented in the
; first part of the command. Obviously, the right semantics need to be:
;
; ============================================================================
;       int* a = r4;
;       --a;
;       a += (*a);
;       r4 = a;
; ============================================================================
;
; This test program therefore checks, if the correct behaviour is shown.
;
; done by sy2002 in December 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    DATA, R4                ; now points to 0x0003 
                ADD     1, R4                   ; now points to 0xAAAA

                ; what this should do, if the CPU works correctly:
                ; 1. decrease R4 by 1, so it now points to 0x0003
                ; 2. add 0x0003 to R4 so it now points to 0xCCCC
                ;
                ; what the buggy CPU did:
                ; 1. remember R4
                ; 2. decrease R4 by 1 so it now points to 0x0003
                ; 3. add 0x0003 to the remembered value, so that it now
                ;    pointed to 0xBBBB
                ADD     @--R4, R4

                CMP     @R4, 0xCCCC
                RBRA    BUG, !Z
                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                SYSCALL(exit, 1)

BUG             MOVE    STR_BUG, R8                
                SYSCALL(puts, 1)
                MOVE    @R4, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                SYSCALL(exit, 1)                

DATA            .DW 0x0003, 0xAAAA, 0xFFFF, 0xCCCC, 0xBBBB, 0x0001, 0x0002

STR_TITLE       .ASCII_P "Test the infamous ADD @--R4, R4 behaviour\n"
                .ASCII_P "done by sy2002 in December 2016\n\n"
                .ASCII_W "CPU condition = "
STR_OK          .ASCII_W "OK"
STR_BUG         .ASCII_W "BUGGY! wrong value = "
