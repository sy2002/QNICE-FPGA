; test and development program for the UART routines in general
; and for the monitor's io_library in particular
; done by sy2002 in August 2015

                .ORG    0x0000

#include "../monitor/sysdef.asm"

                MOVE    0x8400, SP          ; setup stack pointer
                MOVE    IO$TIL_BASE, R12    ; use R12 to output values on TIL
                MOVE    0xFFAA, @R12        ; display something on TIL

                RSUB    IO$GETCHAR, 1
                MOVE    R8, @R12
                RSUB    IO$GETCHAR, 1

                MOVE    QMON$WELCOME, R8
                RSUB    IO$PUTS, 1

NEXT_CHAR       RSUB    IO$GETCHAR, 1       ; read one char from UART to R8
                MOVE    R8, @R12            ; write it to TIL
                RSUB    IO$PUTCHAR, 1       ; echo character to terminal

                ABRA    NEXT_CHAR, 1        ; endless loop

QMON$WELCOME    .ASCII_P    "\n\nSimple QNICE-monitor - Version 0.2 (Bernd Ulmann, August 2015)\n"
                .ASCII_W    "--------------------------------------------------------------\n\n"

#include "../monitor/string_library.asm"
#include "../monitor/io_library.asm"
