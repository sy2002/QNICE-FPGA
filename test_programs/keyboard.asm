; Test program used during keyboard development
; Reads an ascii or special key via PS/2 (USB), mirrors it to STDOUT and
; additionally displays the ascii or special code on the TIL display:
; digit 0..1 : ascii or special code
; digit 2: modifiers
; digit 3: 0 if ascii, 1 if special
; (digits counting from right to left)
; press CTRL+E to exit back to the monitor
; done by sy2002 in January 2016

                .ORG 0x8000

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                MOVE    IO$TIL_DISPLAY, R0
                MOVE    IO$KBD_STATE, R2

MAIN_LOOP       RSUB    READ_KEYBOARD, 1    ; no syscall to ensure that we read USB
                CMP     KBD$CTRL_E, R8      ; exit?
                RBRA    END, Z              ; yes

                MOVE    @R2, R1              
                AND     KBD$MODIFIERS, R1   ; extract modifiers
                AND     0xFFFD, SR          ; clear X (shift in '0')                
                SHL     3, R1               ; shift them to TIL digit 2
                MOVE    R1, R7              ; R7 will be the display variable

                ; special keys
                MOVE    R8, R1              
                AND     KBD$SPECIAL, R1
                RBRA    _NO_SPECIAL, Z
                SHR     8, R1               ; shift them to TIL digits 0..1
                OR      R1, R7
                OR      0x1000, R7          ; show flag in digit 3
                RBRA    _DISPLAY, 1   

                ; normal keys
_NO_SPECIAL     MOVE    R8, R1
                AND     KBD$ASCII, R1
                OR      R1, R7

_DISPLAY        MOVE    R7, @R0             ; display special key + ascii on TIL

                SYSCALL(putc, 1)            ; print character
                RBRA MAIN_LOOP, 1

END             SYSCALL(exit,1)


READ_KEYBOARD   INCRB
                MOVE    IO$KBD_STATE, R0    ; R0 contains the address of the status register
                MOVE    IO$KBD_DATA, R1     ; R1 contains the address of the receiver reg.
_KBD$GETC_LOOP  MOVE    @R0, R2             ; Read status register
                AND     KBD$NEW_ANY, R2     ; bit 1 = special key, bit 0 = standard ascii
                RBRA    _KBD$GETC_LOOP, Z   ; Loop until a character has been received
                MOVE    @R1, R8             ; Get the character from the receiver register
                DECRB
                RET