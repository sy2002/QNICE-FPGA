; TileEd is a simple "text mode sprite" (aka "tile") editor
; it was originally developed as a tool to develop "qtris.asm"
;
; Uses VGA to display all 256 characters of the font (based on font.asm) on
; the left side of the screen. On the right side of the screen, there is a
; box of the size TILE_DX_INIT and TILE_DY_INIT (size can be changed during
; runtime using F3 on the PS2/USB keyboard).
;
; Using F1 on the USB keyboard, you can jump between the character palette
; and the tile and using SPACE on the USB keyboard, you can "paint" characters
; into the tile box. As soon as you press F12, the program outputs .DW
; statements via UART that can be copy/pasted into QNICE assmebler code.
;
; You can also work in multicolor and edit the font itself using F7 and change
; the palette using F9.
;
; TileEd ignores STDIN and STDOUT settings of the monitor: the .DW statements
; always go to the UART and the other input/ouput is done via keyboard/VGA.
;
; done by sy2002 in January 2016
; enhanced by sy2002 to support font graphics and color in September 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                ; "external" interface, i.e. change TILE_DX and TILE_DY to
                ; your needs, recompile and run: TileEd                
TILE_DX_INIT    .EQU 10
TILE_DY_INIT    .EQU 10

                ; "internal" .EQUs, i.e. these are not meant to be changed
START_X         .EQU 2
START_Y         .EQU 5
TILE_CENTER_X   .EQU 57
TILE_CENTER_Y   .EQU 20
TILE_DX_MAX     .EQU 44                         ; if this is changed, then ...
TILE_DY_MAX     .EQU 36                         ; change STR_CHG_SIZE_*, too
SELECTED_X      .EQU 10
SELECTED_Y      .EQU 37

CHR_DRAW_1      .EQU 0x0010                     ; font editing char
CHR_DRAW_0      .EQU 0x0020
CHAR_ED_X       .EQU 12                         ; start coords. char ed. win.
CHAR_ED_Y       .EQU 2

CHR_PAL_F       .EQU 0x0011                     ; foregr. col. pal. disp. char
CHR_PAL_B       .EQU 0x0020                     ; backgr. col. pal. disp. char
CHR_PAL_SEL_F   .EQU 'a'                        ; foreground col selector
CHR_PAL_SEL_B   .EQU 'A'                        ; background col selector
PAL_ED_X        .EQU 2
PAL_ED_Y        .EQU 17

                .ORG 0x8000

                ; check external interface "variables" TILE_DX_INIT and
                ; TILE_DY_INIT to fit into the boundaries
                MOVE    TILE_DX_MAX, R0
                CMP     TILE_DX_INIT, R0
                RBRA    TILE_ED_HALT, N
                MOVE    TILE_DY_MAX, R0
                CMP     TILE_DY_INIT, R0
                RBRA    TILE_ED_HALT, N
                RBRA    TILE_ED_START, 1
TILE_ED_HALT    MOVE    STR_NOSTART, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

                ; move initial tile size to the global variables storing them
TILE_ED_START   MOVE    TILE_DX, R0
                MOVE    TILE_DX_INIT, @R0
                MOVE    TILE_DY, R0
                MOVE    TILE_DY_INIT, @R0

                ; copy font to custom font and switch to custom font
                MOVE    VGA$FONT_OFFS, R0
                MOVE    VGA$FONT_ADDR, R1
                MOVE    VGA$FONT_DATA, R2
                MOVE    VGA$FONT_OFFS_DEFAULT, @R0
                XOR     R3, R3                  ; source pattern
                MOVE    VGA$FONT_OFFS_USER, R4  ; destination pattern
COPY_FONT_LOOP  MOVE    R3, @R1                 ; read source pattern
                MOVE    @R2, R5                 ; R5: bit pattern                
                MOVE    R4, @R1                 ; copy source to destination
                MOVE    R5, @R2
                ADD     1, R3                   ; next char bit pattern
                ADD     1, R4
                CMP     3072, R3                ; 256 chars x 12 lines
                RBRA    COPY_FONT_LOOP, !Z      ; done?
                MOVE    VGA$FONT_OFFS_USER, @R0

                ; copy palette to custom palette and switch to custom pal.
                MOVE    VGA$PALETTE_OFFS, R0
                MOVE    VGA$PALETTE_ADDR, R1
                MOVE    VGA$PALETTE_DATA, R2
                MOVE    VGA$PALETTE_OFFS_DEFAULT, @R0
                XOR     R3, R3
                MOVE    VGA$PALETTE_OFFS_USER, R4
COPY_PAL_LOOP   MOVE    R3, @R1
                MOVE    @R2, R5
                MOVE    R4, @R1
                MOVE    R5, @R2
                ADD     1, R3
                ADD     1, R4
                CMP     32, R3
                RBRA    COPY_PAL_LOOP, !Z
                MOVE    VGA$PALETTE_OFFS_USER, @R0

                ; clear the foreground/background color LRU buffer
                MOVE    LRU_FGBG, R0
                MOVE    256, R1
LRU_INIT_LOOP   MOVE    0, @R0++
                SUB     1, R1
                RBRA    LRU_INIT_LOOP, !Z

                ; set up the screen and calculate the *_WS_* variables
TILE_ED_RESET   SYSCALL(vga_cls, 1)             ; clear screen
                RSUB    DRAW_PALETTE, 1         ; character palette
                MOVE    0, R8                   ; R8=0: default workspace
                RSUB    DRAW_WORKSPACE, 1       ; the rest of the workspace

                ; global registers
TILE_ED_KEEP    MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos
                XOR     R3, R3                  ; R3: mode: 0=palette 1=tile
                MOVE    PAL_WS_X, R8
                MOVE    @R8, R4                 ; R4: palette x pos
                MOVE    PAL_WS_Y, R8
                MOVE    @R8, R5                 ; R5: palette y pos
                MOVE    TILE_WS_X, R8
                MOVE    @R8, R6                 ; R6: tile x pos
                MOVE    TILE_WS_Y, R8
                MOVE    @R8, R7                 ; R7: tile y pos

               ; print currently selected char
MAIN_LOOP       MOVE    R4, @R0
                MOVE    R5, @R1
                MOVE    @R2, R8
                MOVE    SELECTED_X, @R0
                MOVE    SELECTED_Y, @R1
                MOVE    R8, @R2
                MOVE    SELECTED_CHR, R12
                MOVE    R8, @R12

                ; set cursor depending on mode
                CMP     0, R3                   
                RBRA    CRS_MODE_0, Z
                MOVE    R6, @R0
                MOVE    R7, @R1
                RBRA    WAIT_FOR_KEY, 1
CRS_MODE_0      MOVE    R4, @R0
                MOVE    R5, @R1

                ; keyboard handler
WAIT_FOR_KEY    RSUB    KBD_GETCHAR, 1
                CMP     KBD$F1, R8              ; F1 = toggle sprite mode
                RBRA    SWITCH_MODE, Z
                CMP     KBD$F3, R8              ; F3 = change size (and clear)
                RBRA    CHANGE_SIZE, Z
                CMP     KBD$F5, R8              ; F5 = clear
                RBRA    CLEAR, Z
                CMP     KBD$F7, R8              ; F7 = toggle font mode
                RSUB    FONT_ED, Z
                CMP     KBD$F12, R8             ; F12 = quit
                RBRA    SAVE_DATA, Z
                CMP     KBD$SPACE, R8           ; SPACE = draw character
                RBRA    DRAW_CHAR, Z
                CMP     0, R3                   ; mode = palette?
                RBRA    NAV_PAL, Z              ; yes: navigate palette
                CMP     KBD$CUR_UP, R8          ; no: tile: up
                RBRA    NAV_TILE_U, Z
                CMP     KBD$CUR_DOWN, R8        ; tile: cursor down
                RBRA    NAV_TILE_D, Z
                CMP     KBD$CUR_LEFT, R8        ; tile: cursor left
                RBRA    NAV_TILE_L, Z
                CMP     KBD$CUR_RIGHT, R8       ; tile: cursor right
                RBRA    NAV_TILE_R, Z
                CMP     KBD$HOME, R8            ; tile: home = top left
                RBRA    NAV_TILE_H, Z
                CMP     KBD$END, R8             ; tile: end = bottom right
                RBRA    NAV_TILE_E, Z                
                RBRA    WAIT_FOR_KEY, 1
NAV_PAL         CMP     KBD$CUR_UP, R8          ; palette: cursor up
                RBRA    NAV_PAL_U, Z
                CMP     KBD$CUR_DOWN, R8        ; palette: cursor down
                RBRA    NAV_PAL_D, Z
                CMP     KBD$CUR_LEFT, R8        ; palette: cursor left
                RBRA    NAV_PAL_L, Z
                CMP     KBD$CUR_RIGHT, R8       ; palette: cursor right
                RBRA    NAV_PAL_R, Z
                CMP     KBD$HOME, R8            ; palette: home = top left
                RBRA    NAV_PAL_H, Z
                CMP     KBD$END, R8             ; palette: end = bottom right
                RBRA    NAV_PAL_E, Z
                RBRA    WAIT_FOR_KEY, 1

                ; palette navigation: up
NAV_PAL_U       MOVE    PAL_WS_Y, R8
                CMP     R5, @R8                 ; y-pos already at minimum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore keypress
                SUB     2, R5                   ; no: one step up
                RBRA    MAIN_LOOP, 1

                ; palette navigation: down
NAV_PAL_D       MOVE    PAL_WS_Y_MAX, R8
                CMP     R5, @R8                 ; y-pos already at maximum?        
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore keypress
                ADD     2, R5                   ; no: one step down
                RBRA    MAIN_LOOP, 1

                ; palette navigation: left
NAV_PAL_L       MOVE    PAL_WS_X, R8
                CMP     R4, @R8                 ; x-pos already at minimum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore keypress
                SUB     2, R4                   ; no: one step to the left    
                RBRA    MAIN_LOOP, 1

                ; palette navigation: right
NAV_PAL_R       MOVE    PAL_WS_X_MAX, R8        
                CMP     R4, @R8                 ; x-pos already at maximum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore keypress
                ADD     2, R4                   ; no: one step to the right
                RBRA    MAIN_LOOP, 1

                ; palette navigation: home
NAV_PAL_H       MOVE    PAL_WS_X, R8            ; top left position
                MOVE    @R8, R4
                MOVE    PAL_WS_Y, R8
                MOVE    @R8, R5
                RBRA    MAIN_LOOP, 1

                ; palette navigation: end            
NAV_PAL_E       MOVE    PAL_WS_X_MAX, R8        ; bottom right position
                MOVE    @R8, R4
                MOVE    PAL_WS_Y_MAX, R8
                MOVE    @R8, R5
                RBRA    MAIN_LOOP, 1

                ; tile navigation: up
NAV_TILE_U      MOVE    TILE_WS_Y, R8
                CMP     @R8, R7                 ; y-pos already at minimum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore keypress
                SUB     1, R7                   ; no: one line up
                RBRA    MAIN_LOOP, 1

                ; tile navigation: down
NAV_TILE_D      MOVE    TILE_WS_Y_MAX, R8
                CMP     @R8, R7                 ; y-pos already at maximum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore the keypress
                ADD     1, R7                   ; no: one line down
                RBRA    MAIN_LOOP, 1

                ; tile navigation: left
NAV_TILE_L      MOVE    TILE_WS_X, R8
                CMP     @R8, R6                 ; x-pos already at minimum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore the keypress
                SUB     1, R6                   ; no: one column left                
                RBRA    MAIN_LOOP, 1

                ; tile navigation: right
NAV_TILE_R      MOVE    TILE_WS_X_MAX, R8
                CMP     @R8, R6                 ; x-pos already at maximum?
                RBRA    WAIT_FOR_KEY, Z         ; yes: ignore the keypress
                ADD     1, R6                   ; no: one column right
                RBRA    MAIN_LOOP, 1

                ; tile navigation: home
NAV_TILE_H      MOVE    TILE_WS_X, R8           ; top left position
                MOVE    @R8, R6
                MOVE    TILE_WS_Y, R8
                MOVE    @R8, R7
                RBRA    MAIN_LOOP, 1

                ; tile navigation: end
NAV_TILE_E      MOVE    TILE_WS_X_MAX, R8       ; bottom right position
                MOVE    @R8, R6
                MOVE    TILE_WS_Y_MAX, R8
                MOVE    @R8, R7
                RBRA    MAIN_LOOP, 1

                ; switch mode between palette and tile
SWITCH_MODE     XOR     1, R3
                RBRA    MAIN_LOOP, 1

                ; draw the currently active character of the palette
                ; (aka "SELECTED") to the current cursor position within
                ; the tile window
DRAW_CHAR       MOVE    R4, @R0
                MOVE    R5, @R1
                MOVE    @R2, R8                 ; retrieve the character
                MOVE    R6, @R0
                MOVE    R7, @R1
                MOVE    R8, @R2                 ; print the character
                RBRA    MAIN_LOOP, 1

                ; clear tile
CLEAR           MOVE    TILE_WS_X_MAX, R9
                MOVE    TILE_WS_Y_MAX, R10
                MOVE    TILE_WS_Y, R8
                MOVE    @R8, @R1
_CLEAR_NEXT_Y   MOVE    TILE_WS_X, R8
                MOVE    @R8, @R0
_CLEAR_NEXT_X   MOVE    KBD$SPACE, @R2
                ADD     1, @R0
                CMP     @R0, @R9
                RBRA    _CLEAR_NEXT_X, !N
                ADD     1, @R1
                CMP     @R1, @R10
                RBRA    _CLEAR_NEXT_Y, !N
                RBRA    MAIN_LOOP, 1

                ; output .dw XX, YY, ZZ, ... statements containing the
                ; data painted in the tile window to the UART
SAVE_DATA       MOVE    TILE_WS_X_MAX, R9
                MOVE    TILE_WS_Y_MAX, R10
                MOVE    TILE_WS_Y, R8
                MOVE    @R8, @R1

_SAVE_NEXT_Y    MOVE    0x000D, R8              ; print CR
                RSUB    UART_PUTCHAR, 1
                MOVE    0x000A, R8              ; print LF
                RSUB    UART_PUTCHAR, 1
                MOVE    0x002E, R8              ; print "."
                RSUB    UART_PUTCHAR, 1
                MOVE    0x0044, R8              ; print "D"
                RSUB    UART_PUTCHAR, 1
                MOVE    0x0057, R8              ; print "W"
                RSUB    UART_PUTCHAR, 1
                MOVE    0x0020, R8              ; print " "
                RSUB    UART_PUTCHAR, 1
                MOVE    TILE_WS_X, R8           ; reset column (hw x cursor)
                MOVE    @R8, @R0

_SAVE_NEXT_X    MOVE    0x30, R8                ; print "0"
                RSUB    UART_PUTCHAR, 1
                MOVE    0x78, R8                ; print "x"
                RSUB    UART_PUTCHAR, 1
                MOVE    @R2, R8                 ; read tile data from VRAM
                AND     0x00F0, R8              ; extract high nibble ...
                SHR     4, R8
                MOVE    HEX_DIGITS, R11         ; ... convert it to hex ...
                ADD     R8, R11
                MOVE    @R11, R8                
                RSUB    UART_PUTCHAR, 1         ; ... and output it to UART
                MOVE    @R2, R8
                AND     0x000F, R8              ; extract low nibble and ditto
                MOVE    HEX_DIGITS, R11
                ADD     R8, R11
                MOVE    @R11, R8
                RSUB    UART_PUTCHAR, 1
                ADD     1, @R0
                CMP     @R0, @R9                ; reached maximum x position?
                RBRA    _SAVE_NEXT_XC, !N       ; no: print a ", " and go on
                ADD     1, @R1                  ; yes: increase y position
                CMP     @R1, @R10               ; reached maximum y position?
                RBRA    _SAVE_NEXT_Y, !N        ; no: next line
                RBRA    END, 1                  ; yes: end TileEd

_SAVE_NEXT_XC   MOVE    0x002C, R8              ; print ","
                RSUB    UART_PUTCHAR, 1
                MOVE    0x0020, R8              ; print " "
                RSUB    UART_PUTCHAR, 1
                RBRA    _SAVE_NEXT_X, 1

                ; change the size of the tile editor
                ; the user can enter two new values or press ESC to stick
                ; to the old values (in the latter case: no reset is
                ; performed and the work is preserved)
CHANGE_SIZE     MOVE    39, R10                 ; y-pos = last line of screen              
                MOVE    0, R9                   ; x-pos = first column
                MOVE    STR_CLR_LINE, R8        ; clear last line
                RSUB    PRINT_STR_AT, 1
                MOVE    STR_CHG_SIZE_X, R8      ; print change dx message
                RSUB    PRINT_STR_AT, 1
                MOVE    R11, R9                 ; x-pos = behind the message
                MOVE    TILE_DX, R12            ; default val. for ESC...
                MOVE    @R12, R8                ; ...is set to to TILE_DX
                RSUB    KBD_GET2DGN, 1          ; 2-digit number from keyboard

                MOVE    TILE_DX_MAX, R0
                CMP     R8, R0                  ; R8 <= TILE_DX_MAX?
                RBRA    _CS_CHECK_DX, !N        ; yes: continue checking
                RBRA    CHANGE_SIZE, 1          ; no: enter a new number
_CS_CHECK_DX    CMP     1, R8                   ; R8 >= 1
                RBRA    CHANGE_SIZE, N          ; no: enter a new number
                MOVE    R8, R1                  ; R1: remember new TILE_DX

_CS_ENTER_DY    MOVE    39, R10                 ; mult did destroy R10
                MOVE    0, R9
                MOVE    STR_CLR_LINE, R8        ; clear last screen line
                RSUB    PRINT_STR_AT, 1
                MOVE    STR_CHG_SIZE_Y, R8      ; print change dy message
                RSUB    PRINT_STR_AT, 1
                MOVE    R11, R9
                MOVE    TILE_DY, R12            ; default val. for ESC...
                MOVE    @R12, R8                ; ...is set to TILE_DY
                RSUB    KBD_GET2DGN, 1          ; 2-digit number from keyboard

                MOVE    TILE_DY_MAX, R0         
                CMP     R8, R0                  ; R8 <= TILE_DY_MAX?
                RBRA    _CS_CHECK_DY, !N        ; yes: continue checking
                RBRA    _CS_ENTER_DY, 1         ; no: enter a new number
_CS_CHECK_DY    CMP     1, R8                   ; R8 >= 1
                RBRA    _CS_ENTER_DY, N         ; no: enter a new number
                MOVE    R8, R2                  ; R2: remember new TILE_DY

                MOVE    TILE_DX, R12
                CMP     @R12, R1                ; old TILE_DX = new TILE_DX?
                RBRA    _CS_ODX_NDX, Z          ; yes: continue checking
                RBRA    _CS_STORE_NEW, 1        ; no: store new values&reset
_CS_ODX_NDX     MOVE    TILE_DY, R12
                CMP     @R12, R2                ; old TILE_DY = new TILE_DY?
                RBRA    _CS_STORE_NEW, !Z       ; no: store new values&reset

                MOVE    0, R9                   ; yes: show help line...
                MOVE    39, R10
                MOVE    STR_CLR_LINE, R8
                RSUB    PRINT_STR_AT, 1
                MOVE    STR_HELP, R8
                RSUB    PRINT_STR_AT, 1
                RBRA    TILE_ED_KEEP, 1         ; ...and preserve the work

_CS_STORE_NEW   MOVE    TILE_DX, R12
                MOVE    R1, @R12
                MOVE    TILE_DY, R12
                MOVE    R2, @R12                
                RBRA    TILE_ED_RESET, 1        ; reset TileEd with new DX, DY

                ; return to the system by clearing the screen and resetting
END             SYSCALL(vga_init, 1)            ; also activates default font
                SYSCALL(vga_cls, 1)                
                SYSCALL(exit, 1)

; ****************************************************************************
; Various string constants
; ****************************************************************************

HEX_DIGITS      .ASCII_P "0123456789ABCDEF"

STR_HELLO       .ASCII_W "TileEd - Textmode Sprite Editor  V2.0  by sy2002 in September 2020"
STR_NOSTART     .ASCII_W "Either TILE_DX or TILE_DY is larger than the allowed maximum. TileEd halted.\n"
STR_HELP        .ASCII_W "F1: Sprite F3: Size F5: Clr F7: Font F9: Pal F12: Output SPACE: Paint CRSR: Nav"
STR_CLR_LEFT    .ASCII_W "                                 "
STR_CLR_LINE    .ASCII_W "                                                                                "
STR_CHG_SIZE_X  .ASCII_W "Enter new width (1..44): "
STR_CHG_SIZE_Y  .ASCII_W "Enter new height (1..36): "
STR_CURCHAR     .ASCII_W "SELECTED:"
STR_FOREGROUND  .ASCII_W "Foreground color:"
STR_BACKGROUND  .ASCII_W "Background color:"

; ****************************************************************************
; FONT_ED
;    Main routine for color selection and font editing
; ****************************************************************************

FONT_ED         INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4                

                ; save the dimensions of the sprite, because we are reusing
                ; the workspace drawing routine here
                INCRB
                MOVE    TILE_DX, R0
                MOVE    @R0, R0
                MOVE    TILE_DY, R1
                MOVE    @R1, R1
                INCRB

                ; draw the font ed workspace by clearing the character
                ; selection palette and showing the font editing window
                ; and the color selection palette instead
_FONTED_START   MOVE    STR_CLR_LEFT, R8        ; string contains spaces
                XOR     R9, R9                  ; R9:  column
                MOVE    3, R10                  ; R10: line
_FONTED_CLR     RSUB    PRINT_STR_AT, 1
                ADD     1, R10
                CMP     37, R10                 ; clear until line 36
                RBRA    _FONTED_CLR, !Z             
                MOVE    TILE_DX, R0             ; font size is 8x12
                MOVE    8, @R0
                MOVE    TILE_DY, R0
                MOVE    12, @R0
                MOVE    1, R8                   ; R8=1: font ed workspace
                RSUB    DRAW_WORKSPACE, 1

                ; draw the character that is being edited
                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos                
                MOVE    SELECTED_CHR, R3
                MOVE    @R3, R3                 ; R3: char being edited
                MOVE    LRU_FGBG, R12           ; R12: fg/bg color combination
                ADD     R3, R12
                MOVE    @R12, R12

                MOVE    SELECTED_X, @R0         ; print the small char at ..
                MOVE    SELECTED_Y, @R1         ; .. the bottom of the screen
                MOVE    R3, R10                 ; ASCII selected char
                ADD     R12, R10                ; apply fg/bg color
                MOVE    R10, @R2                ; print

                MOVE    CHAR_ED_X, @R0
                ADD     1, @R0                  ; cursor to x start pos
                MOVE    @R0, R4                 ; R4: X pos of each line
                MOVE    CHAR_ED_Y, @R1
                ADD     1, @R1                  ; cursor to y start pos

                MOVE    R3, R8                  ; calculate address of char .. 
                MOVE    12, R9                  ; .. pattern in font ram
                SYSCALL(mulu, 1)
                ADD     VGA$FONT_OFFS_USER, R10
                MOVE    VGA$FONT_ADDR, R6
                MOVE    R10, R5
                MOVE    R5, @R6
                MOVE    VGA$FONT_DATA, R9

                MOVE    12, R8                  ; 12 words per char
_FONTED_PLM     MOVE    @R9, R5
                MOVE    9, R7                   ; we are subtracting pre-loop
                AND     0xFFFD, SR              ; clear X before SHL
                SHL     8, R5
_FONTED_PL      SUB     1, R7                   ; one less bit to go
                RBRA    _FONTED_PNEXT, Z
                AND     0xFFFD, SR              ; clear X before SHL
                SHL     1, R5                   ; probe bitmask
                RBRA    _FONTED_PSPACE, !C      ; zero?
                MOVE    CHR_DRAW_1, R11         ; one!
                ADD     R12, R11                ; apply color
                MOVE    R11, @R2                ; print on screen
                ADD     1, @R0                  ; x-coord on screen + 1
                RBRA    _FONTED_PL, 1           ; next bit
_FONTED_PSPACE  MOVE    CHR_DRAW_0, R11         ; zero!
                ADD     R12, R11                ; apply color
                MOVE    R11, @R2                ; print on screen
                ADD     1, @R0                  ; x-coord on screen + 1
                RBRA    _FONTED_PL, !Z          ; next bit
_FONTED_PNEXT   MOVE    R4, @R0                 ; x-coord: back to 1st column
                ADD     1, @R1                  ; y-coord + 1
                ADD     1, @R6                  ; font ram address + 1
                SUB     1, R8                   ; one less pattern word to go
                RBRA    _FONTED_PLM, !Z

                ; draw the color palette choosers
                MOVE    STR_FOREGROUND, R8      ; print foreground col. string
                MOVE    PAL_ED_X, R9
                MOVE    PAL_ED_Y, R10
                RSUB    PRINT_STR_AT, 1

                MOVE    PAL_ED_X, @R0           ; put cursor to correct pos
                MOVE    PAL_ED_Y, @R1
                ADD     2, @R1

                XOR     R3, R3                  ; print foreground pal
                MOVE    16, R4
                MOVE    CHR_PAL_F, R11
                MOVE    CHR_PAL_SEL_F, R12
                RSUB    _FONTED_PALL, 1

                ADD     3, @R1                  ; print background col. string
                MOVE    STR_BACKGROUND, R8
                MOVE    PAL_ED_X, R9
                MOVE    @R1, R10
                RSUB    PRINT_STR_AT, 1

                MOVE    PAL_ED_X, @R0           ; print background pal
                ADD     2, @R1
                XOR     R3, R3
                MOVE    16, R4
                MOVE    CHR_PAL_B, R11
                MOVE    CHR_PAL_SEL_B, R12
                RSUB    _FONTED_PALL, 1

                ; font ed main loop
                MOVE    CHAR_ED_X, @R0
                ADD     1, @R0
                MOVE    CHAR_ED_Y, @R1
                ADD     1, @R1

_FONTED_MAIN    RSUB    KBD_GETCHAR, 1

                ; check for foreground color selected: >= `a` and < `q`
                MOVE    CHR_PAL_SEL_F, R9
                CMP     R8, R9
                RBRA    _FONTED_CSEL_F, N       ; greater than `a`
                RBRA    _FONTED_CSEL_F, Z       ; equal to `a`
                RBRA    _FONTED_CHKB, 1         ; not >= `a`
_FONTED_CSEL_F  ADD     16, R9                  ; less then `q`
                CMP     R8, R9
                RBRA    _FONTED_CHKB, Z         ; equals `q`
                RBRA    _FONTED_CHKB, N         ; greater than  `q` 

                ; modify fg/bg col. LRU buffer to paint in the right color
_FONTED_SEL_F   SUB     CHR_PAL_SEL_F, R8       ; foreground color selected
                AND     0xFFFD, SR              ; clear X before SHL   
                SHL     8, R8                   ; foreground color bit pos.
                MOVE    LRU_FGBG, R9            ; index the LRU buffer with ..
                MOVE    SELECTED_CHR, R10       ; .. the character
                ADD     @R10, R9
                AND     0xF000, @R9             ; clear old foreground color 
                ADD     R8, @R9                 ; set new foreground color
                RBRA    _FONTED_START, 1        ; redraw everything

_FONTED_CHKB    SYSCALL(puthex, 1)
                SYSCALL(exit, 1)
                
                ; restore registers and sprite size
                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12
                DECRB
                MOVE    TILE_DX, R2
                MOVE    R0, @R2
                MOVE    TILE_DY, R2
                MOVE    R1, @R2
                DECRB
                RET

                ; prints the color palette
                ; (deliberately does not save the lower register bank)
                ;
                ; the hardware cursor needs to be set
                ; R3 is a predefined color counter
                ; R4 is the amount
                ; R11 is the color palette display character
                ; R12 is a predefined ASCII code to count up from for
                ; displaying the color selector
_FONTED_PALL    MOVE    R12, R5                 ; print selector char
                MOVE    R5, @R2                
                MOVE    R11, R5                 ; char used to print the pal
                AND     0xFFFD, SR              ; clear X before SHL
                MOVE    R3, R7                  
                CMP     CHR_PAL_F, R11          ; foreground or background?
                RBRA    _FONTED_PALL_F, Z
                SHL     12, R7                  ; background color
                RBRA    _FONTED_PALL_B, 1
_FONTED_PALL_F  SHL     8, R7                   ; foreground color     
_FONTED_PALL_B  ADD     R7, R5
                ADD     1, @R1                  ; print color one line below
                MOVE    R5, @R2
                SUB     1, @R1
                ADD     1, R12                  ; next selector char
                ADD     2, @R0                  ; x-coord + 2
                ADD     1, R3                   ; next color
                SUB     1, R4                   ; one less color to go
                RBRA    _FONTED_PALL, !Z
                RET                

; ****************************************************************************
; KBD_GETCHAR
;    Read a key from the PS2/USB keyboard, no matter where STDIN points to.
;    R8: character read (lower 8 bits) or special key (higher 8 bits)
; ****************************************************************************

KBD_GETCHAR     INCRB
                MOVE    IO$KBD_STATE, R0        ; R0: addr of status register
                MOVE    IO$KBD_DATA, R1         ; R1: addr of receiver reg.
_KBD_GETC_LOOP  MOVE    @R0, R2                 ; Read status register
                AND     KBD$NEW_ANY, R2         ; Bit 1: special, Bit 0: ASCII
                RBRA    _KBD_GETC_LOOP, Z       ; Loop until character recvd
                MOVE    @R1, R8                 ; Get the character
                DECRB
                RET

; ****************************************************************************
; KBD_GET2DGN
;    Read a two digit number from the PS2/USB keyboard
;    R8: (write) default in case ESC is pressed; (read): number entered
;    R9: start x for cursor and outputs
;    R10: start y for cursor and output
;    (currently hardcoded to 2 digits, but can be easily extended to up to
;    4 digits by adjusting the "CMP 2, R3" command and the BASE10 constants)
; ****************************************************************************

BASE10          .DW     10, 1

KBD_GET2DGN     INCRB

                MOVE    R8, R6                  ; R6: remember default

                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos
                MOVE    R9, @R0                 
                MOVE    R10, @R1

                XOR     R3, R3                  ; R3: loop and base10 counter
                XOR     R4, R4                  ; R4: number that is entered

_KG2DGN_NEXT    RSUB    KBD_GETCHAR, 1

                CMP     KBD$ENTER, R8           ; enter pressed?
                RBRA    _KG2DGN_CHECK1, !Z      ; no: continue processing
                MOVE    R7, R4                  ; yes: use preserved digit
                RBRA    _KG2DGN_END, 1
  
_KG2DGN_CHECK1  CMP     KBD$ESC, R8             ; ESC pressed?
                RBRA    _KG2DGN_CHECK2, !Z      ; no: continue processing
                MOVE    R6, R4                  ; return default value
                RBRA    _KG2DGN_END, 1
                
_KG2DGN_CHECK2  CMP     47, R8                  ; ASCII value > 47?
                RBRA    _KG2DGN_NEXT, N         ; no: ignore key
                CMP     47, R8                  ; ASCII value = 47?
                RBRA    _KG2DGN_NEXT, Z         ; yes: ignore key
                CMP     58, R8                  ; ASCII value < 58?
                RBRA    _KG2DGN_NEXT, !N        ; no: ignore key

                ; print digit and move cursor to the right
                MOVE    R8, @R2
                ADD     1, @R0

                ; calculate decimal number
                MOVE    BASE10, R5              ; base10 multipliers
                ADD     R3, R5                  ; address right base
                SUB     48, R8                  ; convert ASCII to number
                MOVE    R8, R7                  ; preserve R8 in case of ENTER
                MOVE    @R5, R9                 ; retrieve base
                SYSCALL(mulu, 1)                ; R11|R10 = R8 x R9
                ADD     R10, R4                 ; R10 enough, 2 digits < 100

                ADD     1, R3                   ; next digit
                CMP     2, R3                   ; two digits entered
                RBRA    _KG2DGN_NEXT, !Z

_KG2DGN_END     MOVE    R4, R8

                DECRB
                RET

; ****************************************************************************
; UART_PUTCHAR
;   Write a character to the UART, no matter where STDOUT points to.
;   R8: character to be sent
; ****************************************************************************

UART_PUTCHAR    INCRB                       ; Get a new register page
                MOVE IO$UART_SRA, R0        ; R0: address of status register                
                MOVE IO$UART_THRA, R1       ; R1: address of transmit register
_UART_PUTC_WAIT MOVE @R0, R2                ; read status register
                AND 0x0002, R2              ; ready to transmit?
                RBRA _UART_PUTC_WAIT, Z     ; loop until ready
                MOVE R8, @R1                ; Print character
                DECRB                       ; Restore the old page
                RET                

; ****************************************************************************
; DRAW_WORKSPACE
;    * Prints the whole workspace (palette, strings, editing window)
;    * Sets up the following variables:
;      TILE_WS_X, TILE_WS_Y, TILE_WS_X_MAX, TILE_WS_Y_MAX
;    R8: 0 = default mode; 1 = font ed mode
; ****************************************************************************

DRAW_WORKSPACE  INCRB

                MOVE    R8, R7                  ; R7: mode selector

                ; print workspace strings
                MOVE    STR_HELLO, R8           ; welcome string: Top line
                XOR     R9, R9
                XOR     R10, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    STR_CURCHAR, R8         ; selected character string
                MOVE    SELECTED_Y, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    STR_HELP, R8            ; help string: Bottom line
                MOVE    39, R10
                RSUB    PRINT_STR_AT, 1

                ; VGA registers
                MOVE    VGA$CR_X, R0          
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2

                CMP     0, R7                   
                RBRA    _DRAW_WS_STD, Z
                MOVE    CHAR_ED_X, @R0
                MOVE    CHAR_ED_Y, @R1
                RBRA    _DRAW_WS_START, 1

                ; center tile editing box on the right side of workspace
                ; by setting the hardware cursor to the correct coordinate
_DRAW_WS_STD    MOVE    TILE_DX, R12
                MOVE    @R12, R3             
                SHR     1, R3                   ; divide TILE_DX by 2 ...
                MOVE    TILE_CENTER_X, R4
                SUB     R3, R4                  ; ... and subtract from center
                MOVE    R4, @R0                 ; store to hw cursor
                MOVE    TILE_WS_X, R5           ; remember this as TILE_WS_X
                MOVE    R4, @R5
                MOVE    TILE_DX, R12
                ADD     @R12, R4                ; calculate TILE_WS_X_MAX
                SUB     1, R4
                MOVE    TILE_WS_X_MAX, R5       
                MOVE    R4, @R5
                SUB     1, @R0                  ; -1 because of border line
                MOVE    TILE_DY, R12
                MOVE    @R12, R3                ; TILE_DY ditto
                SHR     1, R3
                MOVE    TILE_CENTER_Y, R4
                SUB     R3, R4
                MOVE    R4, @R1
                MOVE    TILE_WS_Y, R5
                MOVE    R4, @R5
                MOVE    TILE_DY, R12
                ADD     @R12, R4
                SUB     1, R4
                MOVE    TILE_WS_Y_MAX, R5
                MOVE    R4, @R5
                SUB     1, @R1

_DRAW_WS_START  MOVE    TILE_DY, R12
                MOVE    @R12, R3                ; distance top to bottom
                ADD     1, R3

                ; draw upper and lower left corners
                MOVE    0x0086, @R2             ; draw upper-left corner
                ADD     R3, @R1
                MOVE    0x0083, @R2             ; draw lower-left corner

                ; draw upper and lower lines
                MOVE    TILE_DX, R12
                MOVE    @R12, R5                ; x-width of box
_DRAW_WS_NX_TB  ADD     1, @R0
                SUB     R3, @R1
                MOVE    0x008A, @R2             ; draw upper "-"
                ADD     R3, @R1
                MOVE    0x008A, @R2

                SUB     1, R5
                RBRA    _DRAW_WS_NX_TB, !Z

                ; draw upper and lower right corners
                ADD     1, @R0
                MOVE    0x0089, @R2             ; lower-right corner
                SUB     R3, @R1
                MOVE    0x008C, @R2             ; upper-right corner

                ; draw left and right lines
                MOVE    TILE_DX, R12
                SUB     @R12, @R0
                SUB     1, @R0
                ADD     1, @R1

                MOVE    TILE_DY, R12
                MOVE    @R12, R5
_DRAW_WS_NX_LR  MOVE    0x0085, @R2             ; draw left "|"
                MOVE    TILE_DX, R12
                ADD     @R12, @R0
                ADD     1, @R0
                MOVE    0x0085, @R2             ; draw right "|"
                MOVE    TILE_DX, R12
                SUB     @R12, @R0
                SUB     1, @R0
                ADD     1, @R1
                SUB     1, R5
                RBRA    _DRAW_WS_NX_LR, !Z

                DECRB
                RET

; ****************************************************************************
; PRINT_STR_AT
;   print a zero terminated string at x/y pos
;   only one-liners are allowed
;   R8: pointer to string
;   R9/R10: x/y pos
;   R11 (output): x-pos of last printed character plus one
; ****************************************************************************

PRINT_STR_AT    INCRB
                MOVE    VGA$CR_Y, R0            ; set hw cursor to y-pos
                MOVE    R10, @R0

                MOVE    VGA$CR_X, R0
                MOVE    VGA$CHAR, R1
                MOVE    R8, R3
                MOVE    R9, R4

_PRINT_STR_LOOP MOVE    R4, @R0                 ; set x-pos
                MOVE    @R3, @R1                ; print character
                ADD     1, R4                   ; increase x-pos
                ADD     1, R3                   ; increase character pointer
                CMP     0, @R3                  ; string end?
                RBRA    _PRINT_STR_LOOP, !Z     ; no: continue printing

                MOVE    R4, R11

                DECRB
                RET

; ****************************************************************************
; DRAW_PALETTE
;   draw the whole character palette
; ****************************************************************************

DRAW_PALETTE    INCRB

                ; draw y axis legend
                MOVE    VGA$CR_Y, R0            
                MOVE    VGA$CR_X, R1
                MOVE    VGA$CHAR, R2
                MOVE    START_Y, R3
                MOVE    START_X, R4             ; one x col. distance between
                SUB     2, R4                   ; legend and content
                RSUB    DRAW_LEGEND, 1

                ; draw x axis legend
                MOVE    VGA$CR_X, R0
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2
                MOVE    START_X, R3
                MOVE    START_Y, R4             ; one y line distance between
                SUB     2, R4                   ; legend and content
                RSUB    DRAW_LEGEND, 1

                ; draw the 256 characters
                XOR     R8, R8                  ; current character: 0..255
                MOVE    START_Y, R4             ; initial y-position on screen

_DRAW_P_LY      MOVE    START_X, R3             ; x-starting pos. of each row
                XOR     R9, R9                  ; current x-counter: 0..15

_DRAW_P_LX      MOVE    R3, @R0                 ; cursor x-pos to hardware
                MOVE    R4, @R1                 ; dito cursor y-pos
                MOVE    R8, @R2                 ; print character on VGA

                ADD     2, R3                   ; skip one column
                ADD     1, R8                   ; next character
                ADD     1, R9                   ; x-counter: 0..15
                CMP     16, R9                  ; already more than 15?
                RBRA    _DRAW_P_LX, !Z          ; no: next column

                ADD     2, R4                   ; yes: next line
                CMP     256, R8                 ; already more than 255 chars?
                RBRA    _DRAW_P_LY, !Z          ; no: go on printing

                ; calculate PAL_WS_* variables
                MOVE    PAL_WS_X, R0
                MOVE    START_X, @R0
                MOVE    PAL_WS_X_MAX, R0
                MOVE    30, R1
                ADD     START_X, R1
                MOVE    R1, @R0
                MOVE    PAL_WS_Y, R0
                MOVE    START_Y, @R0
                MOVE    PAL_WS_Y_MAX, R0
                MOVE    30, R1
                ADD     START_Y, R1
                MOVE    R1, @R0

                DECRB
                RET

                ; draw one legend axis
                ; input registers:
                ; R0: variable dimension hardware register
                ; R1: constant dimension hardware register
                ; R2: VGA character print register
                ; R3: variable axis start position
                ; R4: constant axis start position
DRAW_LEGEND     XOR     R8, R8
_DRAW_LEG_LOOP  RSUB    MAKE_ASCII, 1
                MOVE    R3, @R0                 ; hardware cursor variable
                MOVE    R4, @R1                 ; hardware cursor constant
                MOVE    R9, @R2                 ; draw char
                ADD     1, R8                   ; increase character
                ADD     2, R3                   ; increase variable dimension
                CMP     16, R8                  ; 0 .. F printed?
                RBRA    _DRAW_LEG_LOOP, !Z      ; no: loop
                RET                             ; yes: return

                ; convert a number between 0 and 15 into the ascii value
                ; of the corresponding hex nibble
                ; IN: R8    number 0..15
                ; OUT: R9   ascii of corresponding hex nibble
MAKE_ASCII      CMP     10, R8                  ; R8 < 10?
                RBRA    _MASCII_LESS10, N       ; yes
                MOVE    55, R9
                ADD     R8, R9                  ; no: >= 10: A = ASCII 65
                RET

_MASCII_LESS10  MOVE    48, R9                  ; 0 = ASCII 48
                ADD     R8, R9
                RET

; ****************************************************************************
; VARIABLES
; ****************************************************************************

TILE_DX         .BLOCK 1
TILE_DY         .BLOCK 1

SELECTED_CHR    .BLOCK 1

; workspace boundaries in absolute screen coordinates: palette and tile
PAL_WS_X        .BLOCK 1
PAL_WS_Y        .BLOCK 1
PAL_WS_X_MAX    .BLOCK 1
PAL_WS_Y_MAX    .BLOCK 1
TILE_WS_X       .BLOCK 1
TILE_WS_Y       .BLOCK 1
TILE_WS_X_MAX   .BLOCK 1
TILE_WS_Y_MAX   .BLOCK 1

; table to store the last recently used fg/bg color combination per character
LRU_FGBG        .BLOCK 256
