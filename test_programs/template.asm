; ****************************************************************************
; Template QNICE assembler programs
;
; This template is referenced by doc/best-practices.md. It is meant to be
; copied and modified when you write new QNICE assembler programs.
;
; done by sy2002 in August 2020
; ****************************************************************************

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000                  ; start at 0x8000

                MOVE    R0, R1                  ; some assembler code
                RSUB    SAMPLE_SUB, 1           ; some sample sub routine

                MOVE    TEST_STR, R8            ; some string output ...
                SYSCALL(puts, 1)                ; ... using a system call

                SYSCALL(exit, 1)                ; back to monitor

ANOTHER_LABEL   HALT                            ; execution never reaches this

A_VALUE         .EQU 0x0023
A_VARIABLE      .DW 0x0000, 0x0001, 0x0002      ; 3-word pre-initialized var.

TEST_STR        .ASCII_W "This is a zero terminated string in template.asm"

TEST_STR_ML1    .ASCII_P "And this is a string, that spans over many lines "
                .ASCII_P "and that is therefore not zero terminated until "
                .ASCII_W "another ASCII_W comes up."

; ----------------------------------------------------------------------------
; Sample Sub-Routine
; Returns: Always the value 3 in R8
; ----------------------------------------------------------------------------

SAMPLE_SUB      INCRB                           ; switch register bank

                MOVE    1, R0                   ; messing around with R0 and
                MOVE    2, R1                   ; R1 does not matter due to
                                                ; the DECRB that comes at the
                                                ; end of this sub routine

                MOVE    3, R8                   ; return value

                DECRB                           ; restore register bank
                RET                             ; end sub routine
