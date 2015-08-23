;
;  This file contains the necessary definitions for the simple QNICE-monitor.
;

;
;  Some assembler macros which make life much easier:
;
#define RET	MOVE 	@R13++, R15
#define INCRB	ADD 	0x0100, R14
#define DECRB	SUB	0x0100, R14

;
;  Some register short names:
;
#define PC	R15
#define SR	R14
#define SP	R13

;
;  IO-page addresses:
;
IO$BASE          .EQU 0xFF00
IO$UART0_BASE    .EQU 0xFF20

IO$TIL_BASE      .EQU 0xFF10 ; Address of TIL-display
IO$TIL_MASK      .EQU 0xFF11 ; Mask register of TIL display


;
;  UART-registers:
;
IO$UART_SRA      .EQU 0x0001 ; Status register (relative to base address)
IO$UART_RHRA     .EQU 0x0002 ; Receiving register (relative to base address)
IO$UART_THRA     .EQU 0x0003 ; Transmitting register (relative to base address)

