; ****************************************************************************
; Adaptation of MJoergens vga_lines.c which is meant to run in the
; background while other applications are active
;
; done by sy2002 in September 2020
; ****************************************************************************

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0xE500                  ; start E500 to install

                ; install the scanline ISR
                MOVE    VGA$SCAN_INT, R0
                MOVE    100, @R0++
                MOVE    S_ISR, @R0                

                MOVE    TITLE_STR, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)                ; back to monitor

TITLE_STR       .ASCII_W "Fancy background installed. Call F000 to uninstall."

; ----------------------------------------------------------------------------
; Scanline ISR
; Constantly changes the background color on each scanline
; ----------------------------------------------------------------------------

S_ISR_LINE      .DW 0x0000
S_ISR_J         .DW 0x0000

S_ISR           INCRB                           ; make sure, R8..R11 are not
                MOVE    R8, R0                  ; changed in this ISR
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                INCRB

                MOVE    S_ISR_LINE, R0
                MOVE    VGA$PALETTE_ADDR, R1
                MOVE    VGA$PALETTE_DATA, R2
                MOVE    S_ISR_J, R3

                ;MOVE    @R3, R8
                ;ADD     @R0, R8
                ;MOVE    62, R9
                ;SYSCALL(mulu, 1)
                MOVE    16, @R1                 ; background color
                MOVE    0x2222, @R2
                RBRA    gone, 1

                ADD     1, @R3
                
                ; make sure the next ISR happens at the next line
                ADD     1, @R0
                MOVE    @R0, R2
                CMP     480, R2
                RBRA    S_ISR_SETSL, !Z
                XOR     R2, R2                  ; 480 reached? then back to 0
                MOVE    R2, @R0
S_ISR_SETSL     MOVE    VGA$SCAN_INT, R1
                MOVE    R2, @R1                 ; next interrupt in next line

gone            DECRB                           ; restore R8..R11
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                DECRB
                RTI
