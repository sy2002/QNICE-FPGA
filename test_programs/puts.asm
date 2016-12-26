#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000
                MOVE    TEXT, R8
                RSUB    IO$PUTS, 1
                SYSCALL(exit, 1)

TEXT            .ASCII_W    "Hello world!\n"

;
;***************************************************************************************
;* IO$PUTS prints a null terminated string on UART
;*
;* R8: Pointer to the string to be printed. Of each word only the lower eight bits
;*     will be printed. The terminating word has to be zero.
;*
;* The contents of R8 are being preserved during the run of this function.
;***************************************************************************************
;
IO$PUTS         INCRB                   ; Get a new register page
                MOVE R8, R1             ; Save contents of R8
                MOVE R8, R0             ; Local copy of the string pointer
_IO$PUTS_LOOP   MOVE @R0++, R8          ; Get a character from the string
                AND 0x00FF, R8          ; Only the lower eight bits are relevant
                RBRA _IO$PUTS_END, Z    ; Return when the string end has been reached
                RSUB UART$PUTCHAR, 1    ; Print this character
                RBRA _IO$PUTS_LOOP, 1   ; Continue with the next character
_IO$PUTS_END    MOVE R1, R8             ; Restore contents of R8
                DECRB                   ; Restore correct register page
                RET
;
;***************************************************************************************
;* UART$PUTCHAR writes a single character to the serial line.
;*
;* R8: Contains the character to be printed
;
;* The contents of R8 are being preserved during the run of this function.
;***************************************************************************************
;
UART$PUTCHAR    INCRB                       ; Get a new register page
                MOVE IO$UART_SRA, R0        ; R0: address of status register                
                MOVE IO$UART_THRA, R1       ; R1: address of transmit register
_UART$PUTC_WAIT MOVE @R0, R2                ; read status register
                AND 0x0002, R2              ; ready to transmit?
                RBRA _UART$PUTC_WAIT, Z     ; loop until ready
                MOVE R8, @R1                ; Print character
                DECRB                       ; Restore the old page
                RET
