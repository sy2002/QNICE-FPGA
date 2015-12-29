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
;
; VGA-registers:
;
VGA$STATE       .EQU 0xFF00 ; VGA status register
    ; Bit 8: Scroll one line up
    ; Bit 7: VGA enable
    ; Bit 6: Hardware cursor enable
    ; Bit 5: Hardware cursor blink enable
    ; Bit 4: Hardware cursor mode: 1 - small
    ;                              0 - large
    ; Bit 2-0: Output color
VGA$CR_X        .EQU 0xFF01 ; VGA cursor X position
VGA$CR_Y        .EQU 0xFF02 ; VGA cursor Y position
VGA$CHAR        .EQU 0xFF03 ; VGA character to be displayed
;
; Registers for TIL-display:
;
IO$TIL_DISPLAY  .EQU 0xFF10 ; Address of TIL-display
IO$TIL_MASK     .EQU 0xFF11 ; Mask register of TIL display
;
; Switch-register:
;
IO$SWITCH_REG   .EQU 0xFF12 ; 16 binary keys
;
; USB-keyboard-registers:
;
IO$KBD_STATE    .EQU 0xFF13 ; Status register of USB keyboard
    ; Bit 0: 1 - Character present
    ;        0 - No character present
IO$KBD_DATA     .EQU 0xFF14 ; Data register of USB keyboard
    ; The lower eight bits contain the last ASCII character typed in
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
