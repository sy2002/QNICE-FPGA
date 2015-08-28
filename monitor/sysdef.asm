;
;  This file contains the necessary definitions for the simple QNICE-monitor.
;

;
;  Some assembler macros which make life much easier:
;
#define RET	    MOVE 	@R13++, R15
#define INCRB	ADD 	0x0100, R14
#define DECRB	SUB	    0x0100, R14
#define NOP     MOVE    R0,     R0  ; Be careful this will change the SR bits!

;
;  Some register short names:
;
#define PC	R15
#define SR	R14
#define SP	R13

;
;  IO-page addresses:
;
#ifdef FPGA
IO$BASE         .EQU 0xFF00
IO$UART0_BASE   .EQU 0xFF20

IO$TIL_BASE     .EQU 0xFF10 ; Address of TIL-display
IO$TIL_MASK     .EQU 0xFF11 ; Mask register of TIL display
#else
IO$BASE         .EQU 0xFC00
IO$UART0_BASE   .EQU 0xFC00
#endif

;
;  UART-registers:
;
IO$UART_SRA     .EQU 0x0001 ; Status register (relative to base address)
#ifdef FPGA
IO$UART_RHRA    .EQU 0x0002 ; Receiving register (relative to base address)
#else
IO$UART_RHRA    .EQU 0x003
#endif
IO$UART_THRA    .EQU 0x0003 ; Transmitting register (relative to base address)

;
;  Some useful constants:
;
CHR$BELL        .EQU 0x0007 ; ASCII-BELL character
CHR$TAB         .EQU 0x0009 ; ASCII-TAB character
