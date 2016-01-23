; Q-TRIS is a Tetris clone and the first game ever developed for QNICE-FPGA
; it uses the PS2/USB keyboard and VGA, no matter how STDIN/STDOUT are routed
; done by sy2002 in January 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                ; clear screen, switch of hw cursor
                RSUB    CLRSCR, 1
                MOVE    VGA$STATE, R0
                NOT     VGA$EN_HW_CURSOR, R1
                AND     @R0, R1
                MOVE    R1, @R0

                ; initialize global variables
                MOVE    RenderedNumber, R0
                MOVE    0xFFFF, @R0

                RSUB    PAINT_PLAYFIELD, 1      ; playfield + logo

                MOVE    0, R10
                MOVE    4, R11

NEXT_TETROMINO  RSUB    CLRSCR, 1
                MOVE    R10, R8
                MOVE    0, R9
                CMP     4, R11
                RBRA    _RENDER, Z
                MOVE    2, R9

_RENDER         RSUB    RENDER_TTR, 1

                MOVE    0, R8
                MOVE    0, R9
                RSUB    PAINT_TTR, 1

                SYSCALL(getc, 1)

                SUB     1, R11
                RSUB    NEXT_TETROMINO, !Z
                MOVE    4, R11

                ADD     1, R10
                CMP     7, R10
                RBRA    NEXT_TETROMINO, !Z

                ; end Q-TRIS
                SYSCALL(reset, 1)
  

QTRIS_X     .EQU 25     ; x-pos on screen
QTRIS_Y     .EQU 1      ; y-pos on screen
QTRIS_H     .EQU 6      ; height of the pattern in lines
QTRIS_W     .EQU 53     ; width of the pattern in chars (without zero term.)
QTRIS       .ASCII_W "  ____             _______   _____    _____    _____ "
            .ASCII_W " / __ \           |__   __| |  __ \  |_   _|  / ____|"
            .ASCII_W "| |  | |  ______     | |    | |__) |   | |   | (___  "
            .ASCII_W "| |  | | |______|    | |    |  _  /    | |    \___ \ "
            .ASCII_W "| |__| |             | |    | | \ \   _| |_   ____) |"
            .ASCII_W " \___\_\             |_|    |_|  \_\ |_____| |_____/ "

; characters for painting the left and the right wall
WALL_L      .EQU 0x09
WALL_R      .EQU 0x08

; specifications of the playfield
PLAYFIELD_X .EQU 2      ; x-pos on screen
PLAYFIELD_Y .EQU 0      ; y-pos on screen
PLAYFIELD_H .EQU 40     ; width
PLAYFIELD_W .EQU 20     ; height

; Tetromino patterns
TTR_AMOUNT  .EQU 7
TETROMINOS  .DW 0x20, 0x20, 0x20, 0x20     ; Tetromino "I"
            .DW 0x00, 0x00, 0x00, 0x00
            .DW 0x20, 0x0E, 0x0E, 0x20     ; Tetromino "O"
            .DW 0x20, 0x0E, 0x0E, 0x20
            .DW 0x20, 0x10, 0x20, 0x20     ; Tetromino "T"
            .DW 0x10, 0x10, 0x10, 0x20
            .DW 0x20, 0xAE, 0xAE, 0x20     ; Tetromino "S"
            .DW 0xAE, 0xAE, 0x20, 0x20
            .DW 0xA9, 0xA9, 0x20, 0x20     ; Tetromino "Z"
            .DW 0x20, 0xA9, 0xA9, 0x20
            .DW 0x20, 0x20, 0x23, 0x20     ; Tetromino "L"
            .DW 0x23, 0x23, 0x23, 0x20
            .DW 0x4F, 0x20, 0x20, 0x20     ; Tetromino "J"
            .DW 0x4F, 0x4F, 0x4F, 0x20

; Tetromino painting offsets for centering them in the 8x8 box
TTR_OFFS    .DW 0, 1                       ; Tetromino "I"
            .DW 0, 2                       ; Tetromino "O"
            .DW 1, 2                       ; Tetromino "T"
            .DW 1, 2                       ; Tetromino "S"
            .DW 1, 2                       ; Tetromino "Z"
            .DW 1, 2                       ; Tetromino "L"
            .DW 1, 2                       ; Tetromino "J"


; ****************************************************************************
; PAINT_TTR
;   Draws the tetromino at the specified xy-pos respecting "transparency"
;   which is defined as 0x20 ("space"). Uses RenderedTTR as source.
;   R8: x-pos
;   R9: y-pos
; ****************************************************************************

PAINT_TTR       INCRB

                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos

                MOVE    R8, @R0                 ; set hw x pos
                MOVE    R9, @R1                 ; set hw y pos

                MOVE    RenderedTTR, R3         ; source memory location

                MOVE    8, R5                   ; 8x8 block represents one...
_PAINT_TTR_YL   MOVE    8, R4                   ; ...Tetromino
_PAINT_TTR_XL   CMP     0x20, @R3               ; transparent "pixel"?
                RBRA    _PAINT_TTR_SKIP, Z      ; yes: skip painting
                MOVE    @R3, @R2                ; no: paint
_PAINT_TTR_SKIP ADD     1, R3                   ; next source "pixel"
                ADD     1, @R0                  ; next screen x-pos
                SUB     1, R4                   ; column counter
                RBRA    _PAINT_TTR_XL, !Z       ; column done? no: go on
                MOVE    R8, @R0                 ; yes: reset x-pos
                ADD     1, @R1                  ; next line (inc y-pos)
                SUB     1, R5                   ; line counter
                RBRA    _PAINT_TTR_YL, !Z       ; all lines done? no: go on

                DECRB
                RET

; ****************************************************************************
; CLEAR_RBUF
;   Clears a 8x8 render buffer by filling it with spaces (ASCII 0x20).
;   R8: pointer to render buffer
; ****************************************************************************

CLEAR_RBUF      INCRB
                MOVE    R8, R0                  ; preserve R8s value
                MOVE    64, R1                  ; 8x8 matrix to be cleared
_CLEAR_RBUF_L   MOVE    0x2E, @R0++             ; clear current "pixel"
                SUB     1, R1                   ; next "pixel"
                RBRA    _CLEAR_RBUF_L, !Z       ; done? no: go on
                DECRB
                RET

; ****************************************************************************
; RENDER_TTR
;   Renders the tetromino and rotates it, if specified by R9.
;   Automatically remembers the last tetromino and its position so that
;   subsequent calls can be performed. The 8x8 buffer RenderedTTR contains
;   the resulting pattern. RenderedTemp is used temporarily and RenderedNumber
;   is used to remember, which tetromino has been rendered last time.
;   R8: number of tetromino between 0..TETROMINOS
;   R9: angle: 0 = do not rotate, 1 = rotate left, 2 = rotate right
; ****************************************************************************

RENDER_TTR      INCRB

                ; if no rotation necessary, do not use RenderedTemp
                ; the pointer to the buffer to be used will
                ; be in R4 afterwards
                CMP     0, R9                   ; do not rotate?
                RBRA    _RTTR_ANY_ROT, !Z       ; no, so do rotate
                MOVE    RenderedTTR, R4         ; yes, so do not rotate
                RBRA    _RTTR_CHK_AR, 1
_RTTR_ANY_ROT   MOVE    RenderedTemp, R4        ; do rotate, so use Temp

                ; check, if this tetromino has already been rendered before
                ; and if yes, skip the rendering process and go directly
                ; to the rotation part
_RTTR_CHK_AR    MOVE    RenderedNumber, R0      ; did we already render the...
                CMP     @R0, R8                 ; ...currently requested piece
                RBRA    _RTTR_BCLR, !Z          ; no: render it now
                MOVE    RenderedTTR, R0         ; yes: copy TTR to
                MOVE    RenderedTemp, R1        ; ...Temp because the...
                MOVE    64, R3                  ; ...rotation algorithm...
_RTTR_COPYLOOP  MOVE    @R0++, @R1++            ; ...needs it to be there...
                SUB     1, R3
                RBRA    _RTTR_COPYLOOP, !Z
                RBRA    _RTTR_ROTATE, 1         ; ...and then directly rotate

                ; clear old renderings
_RTTR_BCLR      MOVE    R8, @R0                 ; remember # in RenderedNumber
                MOVE    R4, R8                  ; clear the correct buffer ...
                RSUB    CLEAR_RBUF, 1           ; ... as R4 contains the value
                MOVE    @R0, R8                 ; restore R8

                ; calculate start address of Tetromino pattern
                ; R0: contains the source memory location
                MOVE    TETROMINOS, R0          ; start address of patterns
                MOVE    R8, R1                  ; addr = (# x 8) + start
                SHL     3, R1                   ; SHL 3 means x 8
                ADD     R1, R0                  ; R0: source memory location

                ; calculate the start address within the destination memory
                ; location and take the TTR_OFFS table for centering the
                ; Tetrominos within the 8x8 matrix into consideration
                ; R1: contains the destination memory location
                MOVE    R4, R1                  ; R1: destination mem. loc.
                MOVE    R8, R3                  ; TTR_OFFS = # x 2
                SHL     1, R3
                ADD     TTR_OFFS, R3
                MOVE    @R3++, R2               ; fetch x correction...
                ADD     R2, R1                  ; and add it to the dest. mem.
                MOVE    @R3, R2                 ; fetch y correction...
                SHL     3, R2                   ; multiply by 8 because ...
                ADD     R2, R1                  ; ... of 8 chars per ln

                ; double the size of the Tetromino in x and y direction
                ; i.e. "each source pixel times 4"
                ; and render the Tetromino in neutral/up position
                MOVE    2, R3                   ; R3: source line counter

_RTTR_YL        MOVE    4, R2                   ; R2: source column counter
_RTTR_XL        MOVE    @R0, @R1++              ; source => dest x|y
                MOVE    @R0, @R1                ; source => dest x+1|y
                ADD     7, R1               
                MOVE    @R0, @R1++              ; source => dest x|y+1
                MOVE    @R0, @R1                ; source => dest x+1|y+1

                SUB     7, R1                   ; next dest coord = x+2|y
                ADD     1, R0                   ; inc x
                SUB     1, R2                   ; column done?
                RBRA    _RTTR_XL, !Z            ; no: go on
                ADD     8, R1                   ; next dest coord = x|y+1
                SUB     1, R3                   ; row done?
                RBRA    _RTTR_YL, !Z            ; no: go on

_RTTR_ROTATE    CMP     0, R9                   ; do not rotate?
                RBRA    _RTTR_END, Z            ; yes, do not rotate: end

                CMP     2, R9                   ; rotate right?
                RBRA    _RTTR_RR, Z             ; yes

                ; rotate left
                MOVE    RenderedTTR, R2         ; R2: dest.: rotated Tetromino
                MOVE    7, R1                   ; R1: source x                
_RTTR_DYL       MOVE    RenderedTemp, R0        ; R0: source: raw Tetromino
                ADD     R1, R0                  ; select right source column
                XOR     R3, R3                  ; dest column counter
_RTTR_DXL       MOVE    @R0, @R2++              ; copy "pixel"
                ADD     8, R0                   ; next source line
                ADD     1, R3                   ; next dest column
                CMP     8, R3                   ; end of source line?
                RBRA    _RTTR_DXL, !Z
                SUB     1, R1
                RBRA    _RTTR_DYL, !N           ; < 0 means 8 cols are done
                RBRA    _RTTR_END, 1

                ; rotate right
_RTTR_RR        MOVE    RenderedTTR, R2         ; R2: dest.: rotated Tetromino
                XOR     R3, R3                  ; R3: source column counter
_RTTR_RR_DYL    MOVE    RenderedTemp, R0        ; R0: source: raw Tetromino
                ADD     R3, R0
                ADD     56, R0
                MOVE    8, R4
_RTTR_RR_DXL    MOVE    @R0, @R2++
                SUB     8, R0
                SUB     1, R4
                RBRA    _RTTR_RR_DXL, !Z
                ADD     1, R3
                CMP     8, R3
                RBRA    _RTTR_RR_DYL, !Z

_RTTR_END       DECRB
                RET

; ****************************************************************************
; PAINT_PLAYFIELD
;   Paint the actual playfield including the logo.
;   Registers are not preserved!
; ****************************************************************************

PAINT_PLAYFIELD INCRB
                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos
                MOVE    WALL_L, R3              ; R3: left boundary char
                MOVE    WALL_R, R4              ; R4: right boundary char
                MOVE    PLAYFIELD_X, R5         ; R5: right boundary x-coord.
                ADD     PLAYFIELD_W, R5
                ADD     1, R5                   ; R5: right boundary x-coord.
                MOVE    PLAYFIELD_H, R6         ; R6: playfield height
                MOVE    PLAYFIELD_Y, @R1        ; hw cursor y = start y pos
_PPF_NEXT_LINE  MOVE    PLAYFIELD_X, @R0        ; hw cursor x = start x pos
                MOVE    R3, @R2                 ; print left boundary
                MOVE    R5, @R0                 ; hw cursor to right x pos
                MOVE    R4, @R2                 ; print right boundary
                ADD     1, @R1                  ; paint to next line
                SUB     1, R6                   ; one line done
                RBRA    _PPF_NEXT_LINE, !Z      ; loop until all lines done

                ; print Q-TRIS logo
                MOVE    QTRIS, R8               ; pointer to pattern
                MOVE    QTRIS_X, R9             ; start x-pos on screen
                MOVE    QTRIS_Y, R10            ; start y-pos on screen
                MOVE    QTRIS_H, R6             ; R6: height of pattern
_PPF_NEXT_QT    RSUB    PRINT_STR_AT, 1         ; print string at x|y
                ADD     QTRIS_W, R8             ; next line in pattern ...
                ADD     1, R8                   ; ... add 1 due to zero term.
                ADD     1, R10
                SUB     1, R6
                RBRA    _PPF_NEXT_QT, !Z
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
                RSUB    WAIT_FOR_VGA, 1         ; VGA is slower than CPU   
                ADD     1, R4                   ; increase x-pos
                ADD     1, R3                   ; increase character pointer
                CMP     0, @R3                  ; string end?
                RBRA    _PRINT_STR_LOOP, !Z     ; no: continue printing

                MOVE    R4, R11

                DECRB
                RET

; ****************************************************************************
; WAIT_FOR_VGA
;    VGA is much slower than CPU, so for example between
;    drawing multiple characters, CPU needs to wait until
;    the drawing of the old character finished
; ****************************************************************************

WAIT_FOR_VGA    INCRB
                MOVE    VGA$STATE, R0
_WAIT_FOR_VGAL  MOVE    @R0, R1
                AND     VGA$BUSY, R1
                RBRA    _WAIT_FOR_VGAL, !Z
                DECRB
                RET

; ****************************************************************************
; CLRSCR
;   Clear the screen
; ****************************************************************************

CLRSCR          INCRB
                MOVE    VGA$STATE, R0
                OR      VGA$CLR_SCRN, @R0
                RSUB    WAIT_FOR_VGA, 1
                DECRB
                RET

; ****************************************************************************
; VARIABLES
; ****************************************************************************

RenderedNumber  .BLOCK 1
RenderedTTR     .BLOCK 64   ; Tetromino rendered in the correct angle
RenderedTemp    .BLOCK 64   ; Tetromino rendered in neutral position
