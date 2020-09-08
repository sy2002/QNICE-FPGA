; ****************************************************************************
; Adaptation of MJoergens vga_lines.c which is meant to run in the
; background while other applications are active
;
; done by sy2002 in September 2020
; ****************************************************************************

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0xE000                  ; start E000 to install

                MOVE    VGA$PALETTE_OFFS, R0    ; switch to user-defined pal.
                MOVE    VGA$PALETTE_OFFS_USER, @R0 

                ; install the scanline ISR
                MOVE    VGA$SCAN_INT, R0
                MOVE    0, @R0++
                MOVE    S_ISR, @R0   

                ; install the timer ISR
                MOVE    IO$TIMER_0_PRE, R0
                MOVE    0x0064, @R0++           ; 1 ms base ...
                MOVE    0x00C8, @R0++           ; 0xC8 = 200ms = 5 Hz
                MOVE    T_ISR, @R0

                MOVE    TITLE_STR, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)                ; back to monitor

                .ORG    0xE020                  ; call E020 to uninstall

                MOVE    VGA$SCAN_ISR, R0        ; uninstall VGA scanline ISR
                MOVE    0, @R0
                MOVE    IO$TIMER_0_INT, R0      ; uninstall timer ISR
                MOVE    0, @R0                
                MOVE    VGA$PALETTE_OFFS, R0    ; back to default palette
                MOVE    VGA$PALETTE_OFFS_DEFAULT, @R0

                SYSCALL(exit, 1)


TITLE_STR       .ASCII_W "Fancy background installed. Call E020 to uninstall."

; ----------------------------------------------------------------------------
; Timer ISR
; Set foreground color for VGA STDOUT to white 5 times per second to make
; sure, that if any program changes it, it is changed back fast enough
; ----------------------------------------------------------------------------

T_ISR           INCRB

                MOVE    VGA$PALETTE_ADDR, R0
                MOVE    32, @R0++
                MOVE    0xFFFF, @R0

                DECRB
                RTI

; ----------------------------------------------------------------------------
; Scanline ISR
; Constantly changes the background color on each scanline
; ----------------------------------------------------------------------------

S_ISR_LINE      .DW 0x0000
S_ISR_J         .DW 0x0000
S_ISR_DELAY     .DW 0x0000
S_ISR_MUL       .DW 0x0062

S_ISR           INCRB                           ; make sure, R8..R11 are not
                MOVE    R8, R0                  ; changed in this ISR
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3                
                INCRB

                MOVE    S_ISR_LINE, R0          ; scanline where ISR happens 
                MOVE    VGA$PALETTE_ADDR, R1    ; palette offset register
                MOVE    S_ISR_J, R3             ; variable "j"
                MOVE    S_ISR_DELAY, R4         ; loop var. for slowing down

                MOVE    @R3, R8                 ; (scanline + j) * 62
                ADD     @R0, R8
                MOVE    S_ISR_MUL, R9
                MOVE    @R9, R9
                SYSCALL(mulu, 1)

                MOVE    48, @R1++               ; pal. addr choose backg. col.
                MOVE    R10, @R1                ; set palette to new color

                ADD     1, @R4                  ; delay the "scrolling effect"
                CMP     600, @R4
                RBRA    S_NEXT, !Z
                MOVE    0, @R4
                ADD     1, @R3                  ; this var. does scrolling
        
                ; make sure the next ISR happens at the next scanline line
S_NEXT          ADD     1, @R0
                MOVE    @R0, R2
                CMP     480, R2
                RBRA    S_ISR_SETSL, !Z
                XOR     R2, R2                  ; 480 reached? then back to 0
                MOVE    R2, @R0
                ;MOVE    S_ISR_MUL, R0          ; comment-in for psychodelics
                ;ADD     1, @R0                 ; ditto
S_ISR_SETSL     MOVE    VGA$SCAN_INT, R1
                MOVE    R2, @R1                 ; next interrupt in next line

                DECRB                           ; restore R8..R11
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                DECRB
                RTI
