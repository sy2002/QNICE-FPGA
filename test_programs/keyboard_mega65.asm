; Test program used during MEGA65 keyboard development
;
; Prints the keyboard status register and the data register and additionally
; echos normal keys. "SPECIAL" in the text area, when a special key is pressed.
;
; Press CTRL+E to exit back to the monitor
;
; done by sy2002 in April 2020

                .ORG 0x8000

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                SYSCALL(vga_cls, 1)
                MOVE    STR_HEADER, R8      ; print header and make space in line 0
                SYSCALL(puts, 1)

                XOR     R11, R11            ; R11 = SPECIAL, ASCII

MAIN_LOOP       MOVE    _VGA$X, R0          ; current x, y coordinates
                MOVE    @R0, R1
                MOVE    _VGA$Y, R2
                MOVE    @R2, R3
                XOR     R4, R4
                MOVE    R4, @R0
                MOVE    2, R4
                MOVE    R4, @R2
                MOVE    STR_STATUS, R8      ; print "STATUS = "
                SYSCALL(puts, 1)
                MOVE    IO$KBD_STATE, R8    ; read and print status register
                MOVE    @R8, R8
                SYSCALL(puthex, 1)
                MOVE    STR_ASCII, R8       ; print " SPECIAL, ASCII = "
                SYSCALL(puts, 1)
                MOVE    R11, R8             ; print the SPECIAL and ASCII value
                SYSCALL(puthex, 1)
                MOVE    R1, @R0             ; restore the cursor position
                MOVE    R3, @R2

                MOVE    IO$KBD_STATE, R4    ; read keyboard state
                MOVE    @R4, R4
                AND     KBD$NEW_ASCII, R4   ; new ASCII character?
                RBRA    _NO_NEW_ASCII, Z    ; no, skip

                MOVE    IO$KBD_DATA, R4     ; read char and check if CTRL+E
                MOVE    @R4, R8
                CMP     KBD$CTRL_E, R8
                RBRA    EXIT, Z             ; yes: exit
                SYSCALL(putc, 1)            ; no: print char
                MOVE    R8, R11             ; remember it for printing

_NO_NEW_ASCII   MOVE    IO$KBD_STATE, R4
                MOVE    @R4, R4
                AND     KBD$NEW_SPECIAL, R4 ; new special key?
                RBRA    _NO_NEW_SPECIAL, Z  ; no, skip
                MOVE    IO$KBD_DATA, R4     ; read special char
                MOVE    @R4, R11            ; remember it for printing
                MOVE    STR_SPECIAL, R8
                SYSCALL(puts, 1)

_NO_NEW_SPECIAL RBRA    MAIN_LOOP, 1

EXIT            SYSCALL(exit, 1)

STR_HEADER      .ASCII_W "MEGA65 Keyboard Development Testbed, done by sy2002 in April 2020\n\n\n\n"
STR_STATUS      .ASCII_W "STATUS =  "
STR_ASCII       .ASCII_W "   SPECIAL, ASCII = "
STR_SPECIAL     .ASCII_W "SPECIAL"

_VGA$X          .EQU 0xFEEC
_VGA$Y          .EQU 0xFEED
