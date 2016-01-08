; PORE ROM
; Power On & Reset Execution ROM
;
; This code is executed on power on and on each reset of the system,
; even before any standard operating system like the Monitor is being
; executed from ROM address 0.
;
; The code relies on Monitor libraries and therefore directly includes
; them from the monitor subdirectory without using dist_kit.    
;
; done by sy2002 in January 2016

#include "../monitor/sysdef.asm"

                AND     0x00FF, SR              ; make sure we are in rbank 0
                MOVE    VAR$STACK_START, SP     ; initialize stack pointer

                ; Print boot message on UART and into the VRAM
                RSUB    VGA$CLS, 1              ; clear the whole VRAM
                MOVE    PORE$NEWLINE, R9        ; print a newline ...
                MOVE    1, R10                
                RSUB    PRINT_STRING, 1         ; ... but only on UART
                MOVE    PORE$RESETMSG, R9       ; print boot message ...
                MOVE    0, R10
                RSUB    PRINT_STRING, 1         ; ... on both devices

                ; The HALT command triggers the PORE state machine to leave
                ; the PORE ROM, reset the CPU and switch to normal execution
                HALT

                ; Prints a string to both, UART and VGA
                ; (independent, if the VGA signal is generated or not)
                ; expects R9 to point to the zero-terminated string
                ; R10: 1=write only to UART, 0=write to both
                ; R9, R10 are left unmodified
PRINT_STRING    INCRB                           ; save register bank
                MOVE    R9, R0                  ; leave R9 unmodified 
_PRINT_LOOP     MOVE    @R0++, R8               ; actual character to R8
                AND     0x00FF, R8              ; only lower 8bits relevant
                RBRA    _PRINT_DONE, Z          ; zero termination detected
                RSUB    UART$PUTCHAR, 1         ; print to UART
                MOVE    R10, R2                 ; skip VGA ...
                RBRA    _PRINT_LOOP, !Z         ; ... if R10 is not zero
                RSUB    VGA$PUTCHAR, 1          ; print to VRAM
_SKIP_VGA       RBRA    _PRINT_LOOP, 1          ; continue printing
_PRINT_DONE     DECRB                           ; restore register bank
                RET                             ; return to caller

#include "boot_message.asm"

#include "../monitor/uart_library.asm"
#include "../monitor/vga_library.asm"
#include "../monitor/variables.asm"
