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

#define SYSCALL(x,y)    ASUB    x, y

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

; ========== VGA ==========
VGA$MAX_X               .EQU    79                      ; Max. X-coordinate in decimal!
VGA$MAX_Y               .EQU    39                      ; Max. Y-coordinate in decimal!
VGA$MAX_CHARS           .EQU    3200                    ; VGA$MAX_X * VGA$MAX_Y
VGA$CHARS_PER_LINE      .EQU    80  

VGA$EN_HW_SCRL          .EQU    0x0C00                  ; Hardware scrolling enable
VGA$CLR_SCRN            .EQU    0x0100                  ; Clear screen

VGA$COLOR_RED           .EQU    0x0004
VGA$COLOR_GREEN         .EQU    0x0002
VGA$COLOR_BLUE          .EQU    0x0001
VGA$COLOR_WHITE         .EQU    0x0007

; ========== KEYBOARD ==========

KBD$NEW_ASCII           .EQU    0x0001                  ; new ascii character available
KBD$NEW_SPECIAL         .EQU    0x0002                  ; new special char. available

KBD$LOCALES             .EQU    0x001C                  ; bit mask for checking locales
KBD$LOCALE_US           .EQU    0x0000                  ; default: US keyboard layout
KBD$LOCALE_DE           .EQU    0x0004                  ; DE: German keyboard layout
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
;    Bit  0 (read only): New ASCII character avaiable for reading
;                        (bits 7 downto 0 of Read register)
;    Bit  1 (read only): New special key available for reading
;                        (bits 15 downto 8 of Read register)
;    Bits 2..4 (read/write): Locales: 000 = US English keyboard layout,
;                            001 = German layout, others: reserved

IO$KBD_DATA     .EQU 0xFF14 ; Data register of USB keyboard
;    Contains the ASCII character in bits 7 downto 0  or the special key code
;    in 15 downto 0. The "or" is meant exclusive, i.e. it cannot happen that
;    one transmission contains an ASCII character PLUS a special character.
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
