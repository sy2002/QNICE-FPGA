; Very simple USB keyboard test which echos all input chars back to 
; the currently active terminal (UART or VGA). Additionally, the ASCII and
; special key value is is being output to the TIL display.
; done by sy2002 in January 2016

                .ORG 0xA000

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                MOVE    IO$TIL_DISPLAY, R0

MAIN_LOOP       RSUB    READ_KEYBOARD, 1    ; no syscall to ensure that we read USB
                CMP     KBD$CTRL_E, R8      ; exit?
                RBRA    END, Z              ; yes
                MOVE    R8, @R0             ; display special key + ascii on TIL
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