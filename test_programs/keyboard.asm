; Very basic USB keyboard test which echos all input chars back to 
; the terminal. It also displays the ASCII code of the character on 
; the TIL by vaxman in December 2015.

                .ORG 0x8000

#include "../monitor/sysdef.asm"

                MOVE    IO$TIL_DISPLAY, R12
                MOVE    0xFFAA, @R12

                MOVE    IO$UART_SRA, R0     ; R0: address of UART status register
                MOVE    IO$UART_THRA, R1    ; R1: address of transmit register

                MOVE    IO$KBD_STATE, R4    ; Status register of USB keyboard
                MOVE    IO$KBD_DATA, R5     ; Data from USB keyboard

_IO$GETC_LOOP   MOVE    @R4, R3             ; read status register
                AND     0x0001, R3          ; character waiting in read latch?
                RBRA    _IO$GETC_LOOP, Z    ; loop until a char. is received

                MOVE    @R5, R8             ; store received character ...
                MOVE    R8, @R12            ; ... and write it to TIL
                
_IO$SETC_WAIT   MOVE    @R0, R3             ; read status register
                AND     0x0002, R3          ; ready to transmit?
                RBRA    _IO$SETC_WAIT, Z    ; loop until ready

                MOVE    R8, @R1             ; echo character back to terminal

                RBRA    _IO$GETC_LOOP, 1    ; next char

                ABRA    0, 1
