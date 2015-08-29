; very basic UART test which echos all input chars back to the terminal
; plus it displays the ASCII code of the character on the TIL
; by sy2002 in August 2015

                .ORG 0x8000

#define FPGA
#include "../monitor/sysdef.asm"


                MOVE    IO$TIL_BASE, R12
                MOVE    0xFFAA, @R12

                MOVE    IO$UART0_BASE, R0 
                MOVE    R0, R1
                MOVE    R0, R2 
                ADD     IO$UART_SRA, R0     ; R0: address of status register
                ADD     IO$UART_RHRA, R1    ; R1: address of receiver register
                ADD     IO$UART_THRA, R2    ; R2: address of transmit register

_IO$GETC_LOOP   MOVE    @R0, R3             ; read status register
                AND     0x0001, R3          ; character waiting in read latch?
                RBRA    _IO$GETC_LOOP, Z    ; loop until a char. is received

                MOVE    @R1, R8             ; store received character ...
                MOVE    R8, @R12            ; ... and write it to TIL
                --MOVE    0, @R0              ; clear read latch

_IO$SETC_WAIT   MOVE    @R0, R3             ; read status register
                AND     0x0002, R3          ; ready to transmit?
                RBRA    _IO$SETC_WAIT, Z    ; loop until ready

                MOVE    R8, @R2             ; echo character back to terminal

                RBRA    _IO$GETC_LOOP, 1    ; next char

                ABRA    0, 1