;; VGA interrupt test
;; done by MJoergen in September 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

LINE_START          .EQU    300
LINE_END            .EQU    312
LINE_NEXT           .EQU    324

                    .ORG    0x8000

                    ; Clear screen
                    SYSCALL(vga_cls, 1)

                    ; Disable hardware cursor
                    MOVE    VGA$STATE, R0
                    MOVE    VGA$EN_HW_CURSOR, R1
                    NOT     R1, R1
                    AND     R1, @R0

                    ; Enable scan line interrupt
                    MOVE    VGA$SCAN_INT, R0
                    MOVE    LINE_START, @R0++
                    MOVE    ISR, @R0++

                    ; Wait for the user to press a key
                    SYSCALL(getc, 1)

                    ; Switch off interrupt
                    MOVE    VGA$SCAN_ISR, R0
                    MOVE    0, @R0

                    ; end of this program => back to monitor
                    SYSCALL(exit, 1)

_VAR_COUNTER        .DW     0
_VAR_DX             .DW     0
_VAR_POS            .DW     0
_VAR_TEXT           .ASCII_W "This short program demonstrates the use of "
                    .ASCII_W "interrupts to generate a smooth scrolling text "
                    .ASCII_W "that just goes on and on and on ...   "
                    .ASCII_W "Add some spaces at the end of the text, before it repeats."
                    .ASCII_W "                                    "
_VAR_TEXT_END

ISR                 INCRB
                    MOVE    VGA$SCAN_INT, R0
                    CMP     LINE_START, @R0
                    RBRA    _ISR_START, Z
                    CMP     LINE_END, @R0
                    RBRA    _ISR_END, Z
                    CMP     LINE_NEXT, @R0
                    RBRA    _ISR_NEXT, Z
_ISR_RET            DECRB
                    RTI

_ISR_START          ; Prepare for next interrupt
                    MOVE    LINE_END, @R0

                    ; Set background colour
                    MOVE    VGA$COLOR_RED, R1
                    RSUB    _ISR_SET_BG, 1

                    ; Set adjust X
                    MOVE    _VAR_DX, R1
                    MOVE    @R1, R1
                    RSUB    _ISR_SET_ADJUST_X, 1

                    RBRA    _ISR_RET, 1

_ISR_END            ; Prepare for next interrupt
                    MOVE    LINE_NEXT, @R0

                    ; Set backgroud colour
                    MOVE    VGA$COLOR_DARK_GRAY, R1
                    RSUB    _ISR_SET_BG, 1

                    ; Set adjust X
                    MOVE    8, R1
                    RSUB    _ISR_SET_ADJUST_X, 1

                    RBRA    _ISR_RET, 1

_ISR_NEXT           ; Prepare for next interrupt
                    MOVE    LINE_START, @R0

                    ; Set adjust X
                    MOVE    0, R1
                    RSUB    _ISR_SET_ADJUST_X, 1

                    ; Increment counter and check value mod 2.
                    MOVE    _VAR_COUNTER, R0
                    ADD     1, @R0
                    MOVE    @R0, R1
                    AND     1, R1
                    RBRA    _ISR_RET, !Z

                    ; Increment DX, and check if shifting a complete character
                    MOVE    _VAR_DX, R0
                    ADD     1, @R0
                    CMP     8, @R0
                    RBRA    _ISR_RET, !Z
                    MOVE    0, @R0

                    ; Get next character to display in R6
                    MOVE    _VAR_POS, R7
                    MOVE    @R7, R6
                    ADD     _VAR_TEXT, R6
                    MOVE    @R6, R6

                    ; Store values of Cursor X and Y
                    MOVE    VGA$CR_X, R0
                    MOVE    VGA$CR_Y, R1
                    MOVE    @R0, R4
                    MOVE    @R1, R5

                    ; Move line one character
                    MOVE    80, @R0
                    MOVE    25, @R1
                    MOVE    VGA$CHAR, R2
_ISR_1              MOVE    @R2, R3
                    MOVE    R6, @R2
                    MOVE    R3, R6
                    SUB     1, @R0
                    RBRA    _ISR_1, !X

                    ; Restore old values of Cursor X and Y
                    MOVE    R4, @R0
                    MOVE    R5, @R1

                    ; Move to next character
                    MOVE    _VAR_POS, R7
_ISR_2              ADD     1, @R7
                    MOVE    @R7, R6
                    ADD     _VAR_TEXT, R6
                    CMP     0, @R6
                    RBRA    _ISR_2, Z           ; Skip past the trailing zero.

                    CMP     _VAR_TEXT_END, R6
                    RBRA    _ISR_3, !Z
                    MOVE    0, @R7
_ISR_3
                    ; Finally, we are done!
                    RBRA    _ISR_RET, 1


; Set Adjust_X to R1
_ISR_SET_ADJUST_X   MOVE    VGA$ADJUST_X, R7
                    MOVE    R1, @R7
                    RET

; Set background palette colour to R1
_ISR_SET_BG
                    MOVE    VGA$PALETTE_ADDR, R6
                    MOVE    VGA$PALETTE_DATA, R7
                    MOVE    @R6, R5             ; Store address
                    MOVE    16, @R6             ; Set address (background)
                    MOVE    R1, @R7             ; Set background colour
                    MOVE    R5, @R6             ; Restore old address
                    RET

