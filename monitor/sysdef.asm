;
;  This file contains the necessary definitions for the simple QNICE-monitor.
;

;
;  Some assembler macros which make life much easier:
;
#define RET	    MOVE 	@R13++, R15
#define INCRB	ADD 	0x0100, R14
#define DECRB	SUB	    0x0100, R14
#define NOP     ABRA    R15, 1

;
;  Some register short names:
;
#define PC	R15
#define SR	R14
#define SP	R13

;
;  IO-page addresses:
;
IO$BASE         .EQU 0xFF00

IO$TIL_DISPLAY  .EQU 0xFF10 ; Address of TIL-display
IO$TIL_MASK     .EQU 0xFF11 ; Mask register of TIL display
IO$SWITCH_REG   .EQU 0xFF12 ; 16 binary keys

IO$KBD_STATE    .EQU 0xFF13 ; Status register of USB keyboard
IO$KBD_DATA     .EQU 0xFF14 ; Data register of USB keyboard

;
;  UART-registers:
;
IO$UART_SRA     .EQU 0xFF21 ; Status register (relative to base address)
IO$UART_RHRA    .EQU 0xFF22 ; Receiving register (relative to base address)
IO$UART_THRA    .EQU 0xFF23 ; Transmitting register (relative to base address)

;
;  Some useful constants:
;
CHR$BELL        .EQU 0x0007 ; ASCII-BELL character
CHR$TAB         .EQU 0x0009 ; ASCII-TAB character
