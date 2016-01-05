;;
;;  sysdef.asm: This file contains the necessary definitions for the simple QNICE-monitor.
;;

;
;***************************************************************************************
;*  Some assembler macros which make life much easier:
;***************************************************************************************
;
#define RET     MOVE    @R13++, R15
#define INCRB   ADD     0x0100, R14
#define DECRB   SUB     0x0100, R14
#define NOP     ABRA    R15, 1

;
;  Some register short names:
;
#define PC  R15
#define SR  R14
#define SP  R13

;
;***************************************************************************************
;* Some constant definitions
;***************************************************************************************
;
VGA$MAX_X               .EQU    79                      ; Max. X-coordinate in decimal!
VGA$MAX_Y               .EQU    39                      ; Max. Y-coordinate in decimal!
VGA$MAX_CHARS           .EQU    3200                    ; VGA$MAX_X * VGA$MAX_Y
VGA$CHARS_PER_LINE      .EQU    80  

VGA$EN_HW_SCRL          .EQU    0x0C00                  ; Hardware scrolling enable

;
VGA$COLOR_RED           .EQU    0x0004
VGA$COLOR_GREEN         .EQU    0x0002
VGA$COLOR_BLUE          .EQU    0x0001
VGA$COLOR_WHITE         .EQU    0x0007

;
;***************************************************************************************
;*  IO-page addresses:
;***************************************************************************************
;
IO$BASE             .EQU 0xFF00
;
; VGA-registers:
;
VGA$STATE           .EQU 0xFF00 ; VGA status register
    ; Bits 11-10: Hardware scrolling / offset enable: Bit #10 enables the use
    ;             of the offset register #4 (display offset) and bit #11
    ;             enables the use of register #5 (read/write offset).
    ; Bit      9: Busy: VGA is currently busy, e.g. clearing the screen,
    ;             printing, etc. While busy, commands will be ignored, but
    ;             they can still be written into the registers, though
    ; Bit      8: Set bit to clear screen. Read bit to find out, if clear
    ;             screen is still active
    ; Bit      7: VGA enable (1 = on; 0: no VGA signal is generated)
    ; Bit      6: Hardware cursor enable
    ; Bit      5: Hardware cursor blink enable
    ; Bit      4: Hardware cursor mode: 1 - small
    ;                              0 - large
    ; Bits   2-0: Output color for the whole screen, bits (2, 1, 0) = RGB
VGA$CR_X            .EQU 0xFF01 ; VGA cursor X position
VGA$CR_Y            .EQU 0xFF02 ; VGA cursor Y position
VGA$CHAR            .EQU 0xFF03 ; write: VGA character to be displayed
                                ; read: character "under" the cursor
VGA$OFFS_DISPLAY    .EQU 0xFF04 ; Offset in bytes that is used when displaying
                                ; the video RAM. Scrolling forward one line
                                ; means adding 0x50 to this register.
                                ; Only works, if bit #10 in VGA$STATE is set.
VGA$OFFS_RW         .EQU 0xFF05 ; Offset in bytes that is used, when you read
                                ; or write to the video RAM using VGA$CHAR.
                                ; Works independently from VGA$OFFS_DISPLAY.
                                ; Active, when bit #11 in VGA$STATE is set.

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
