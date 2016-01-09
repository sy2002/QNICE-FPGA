; Very simple USB keyboard test which echos all input chars back to 
; the currently active terminal (UART or VGA). Additionally, the ASCII and
; special key value is is being output to the TIL display.
; done by sy2002 in January 2016

                .ORG 0x8000

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                MOVE    IO$TIL_DISPLAY, R0

MAIN_LOOP       RSUB    READ_KEYBOARD, 1
                MOVE    R8, @R0
                SYSCALL(putc, 1)
                RBRA MAIN_LOOP, 1


READ_KEYBOARD   INCRB
                MOVE    IO$KBD_STATE, R0    ; R0 contains the address of the status register
                MOVE    IO$KBD_DATA, R1     ; R1 contains the address of the receiver reg.
_KBD$GETC_LOOP  MOVE    @R0, R2             ; Read status register
                AND     0x0011, R2          ; Only bit 0 is of interest
                RBRA    _KBD$GETC_LOOP, Z   ; Loop until a character has been received
                MOVE    @R1, R8             ; Get the character from the receiver register
                DECRB
                RET