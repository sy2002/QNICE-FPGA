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

NEXT_TETROMINO  MOVE    R10, R8
                MOVE    1, R9
                RSUB    RENDER_TTR, 1

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
  

QTRIS_X     .EQU 25
QTRIS_Y     .EQU 1
QTRIS_H     .EQU 6
QTRIS_W     .EQU 53
QTRIS_0     .ASCII_W "  ____             _______   _____    _____    _____ "
QTRIS_1     .ASCII_W " / __ \           |__   __| |  __ \  |_   _|  / ____|"
QTRIS_2     .ASCII_W "| |  | |  ______     | |    | |__) |   | |   | (___  "
QTRIS_3     .ASCII_W "| |  | | |______|    | |    |  _  /    | |    \___ \ "
QTRIS_4     .ASCII_W "| |__| |             | |    | | \ \   _| |_   ____) |"
QTRIS_5     .ASCII_W " \___\_\             |_|    |_|  \_\ |_____| |_____/ "

WALL_L      .EQU 0x09
WALL_R      .EQU 0x08

PLAYFIELD_X .EQU 2
PLAYFIELD_Y .EQU 0
PLAYFIELD_H .EQU 40
PLAYFIELD_W .EQU 20

TETROMINOS  .EQU 7
TTR_I_0     .DW 0x20, 0x20, 0x20, 0x20     ; Tetromino "I"
TTR_I_1     .DW 0x00, 0x00, 0x00, 0x00
TTR_O_0     .DW 0x20, 0x0E, 0x0E, 0x20     ; Tetromino "O"
TTR_O_1     .DW 0x20, 0x0E, 0x0E, 0x20
TTR_T_0     .DW 0x20, 0x10, 0x20, 0x20     ; Tetromino "T"
TTR_T_1     .DW 0x10, 0x10, 0x10, 0x20
TTR_S_0     .DW 0x20, 0xAE, 0xAE, 0x20     ; Tetromino "S"
TTR_S_1     .DW 0xAE, 0xAE, 0x20, 0x20
TTR_Z_0     .DW 0xA9, 0xA9, 0x20, 0x20     ; Tetromino "Z"
TTR_Z_1     .DW 0x20, 0xA9, 0xA9, 0x20
TTR_L_0     .DW 0x20, 0x20, 0x23, 0x20     ; Tetromino "L"
TTR_L_1     .DW 0x23, 0x23, 0x23, 0x20
TTR_J_0     .DW 0x4F, 0x20, 0x20, 0x20     ; Tetromino "J"
TTR_J_1     .DW 0x4F, 0x4F, 0x4F, 0x20

; ****************************************************************************
; PAINT_TTR
;   draws the tetromino at the specified xy-pos respecting "transparency"
;   R8: x-pos
;   R9: y-pos
; ****************************************************************************

PAINT_TTR       INCRB

                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos

                MOVE    R8, @R0
                MOVE    R9, @R1

                MOVE    RenderedTTR, R3         ; source memory location

                MOVE    8, R5
_PAINT_TTR_YL   MOVE    8, R4
_PAINT_TTR_XL   MOVE    @R3, @R2
                ADD     1, R3
                ADD     1, @R0
                SUB     1, R4
                RBRA    _PAINT_TTR_XL, !Z
                MOVE    R8, @R0
                ADD     1, @R1
                SUB     1, R5
                RBRA    _PAINT_TTR_YL, !Z

                DECRB
                RET

; ****************************************************************************
; RENDER_TTR
;   renders the tetromino in the specified angle to memory at "RenderedTTR"
;   R8: number of tetromino between 0..TETROMINOS
;   R9: angle: 0 = do not rotate, 1 = rotate left, 2 = rotate right
; ****************************************************************************

RENDER_TTR      INCRB

                ; if no rotation necessary, do not use RenderedTemp
                CMP     0, R9               ; do not rotate?
                RBRA    _RTTR_ANY_ROT, !Z   ; no, so do rotate
                MOVE    RenderedTTR, R4     ; yes, so do not rotate
                RBRA    _RTTR_CHK_AR, 1

_RTTR_ANY_ROT   MOVE    RenderedTemp, R4    ; do rotate, so use Temp

_RTTR_CHK_AR    MOVE    RenderedNumber, R0  ; already rendered this one before
                CMP     @R0, R8  
                RBRA    _RTTR_BCLR, !Z      ; no: render it
                MOVE    RenderedTTR, R0     ; copy TTR to Temp
                MOVE    RenderedTemp, R1
                MOVE    64, R3
_RTTR_COPYLOOP  MOVE    @R0++, @R1++
                SUB     1, R3
                RBRA    _RTTR_COPYLOOP, !Z
                RBRA    _RTTR_ROTATE, 1         

                ; clear old renderings
_RTTR_BCLR      MOVE    R8, @R0             ;  RenderedNumber =  current #
                MOVE    R4, R1
                MOVE    64, R2
_RTTR_CLR       MOVE    0x20, @R1++
                SUB     1, R2
                RBRA    _RTTR_CLR, !Z

                ; calculate start address of Tetromino pattern
                MOVE    TTR_I_0, R0         ; start address of patterns
                MOVE    R8, R1              ; addr = (# x 8) + start
                SHL     3, R1               ; SHL 3 means x 8
                ADD     R1, R0              ; R0: source memory location
                MOVE    R4, R1              ; R1: destination memory location
                ADD     16, R1              ; Center in y direction

                ; double the size of the Tetromino in x and y direction
                ; i.e. "each source pixel times 4"
                ; and render the Tetromino in neutral/up position
                MOVE    2, R3               ; R3: source line counter

_RTTR_YL        MOVE    4, R2               ; R2: source column counter
_RTTR_XL        MOVE    @R0, @R1++          ; source => dest x|y
                MOVE    @R0, @R1            ; source => dest x+1|y
                ADD     7, R1               
                MOVE    @R0, @R1++          ; source => dest x|y+1
                MOVE    @R0, @R1            ; source => dest x+1|y+1

                SUB     7, R1               ; next dest coord = x+2|y
                ADD     1, R0               ; inc x
                SUB     1, R2               ; column done?
                RBRA    _RTTR_XL, !Z        ; no: go on
                ADD     8, R1               ; next dest coord = x|y+1
                SUB     1, R3               ; row done?
                RBRA    _RTTR_YL, !Z        ; no: go on

_RTTR_ROTATE    CMP     0, R9               ; do not rotate?
                RBRA    _RTTR_END, Z        ; yes, do not rotate: end

                CMP     2, R9               ; rotate right?
                RBRA    _RTTR_RR, Z         ; yes

                ; rotate left
                MOVE    RenderedTTR, R2     ; R3: dest.: rotated Tetromino
                MOVE    7, R1               ; R1: source x                
_RTTR_DYL       MOVE    RenderedTemp, R0    ; R0: source: raw Tetromino
                ADD     R1, R0              ; select right source column
                XOR     R3, R3              ; dest column counter
_RTTR_DXL       MOVE    @R0, @R2++          ; copy "pixel"
                ADD     8, R0               ; next source line
                ADD     1, R3               ; next dest column
                CMP     8, R3               ; end of source line?
                RBRA    _RTTR_DXL, !Z
                SUB     1, R1
                RBRA    _RTTR_DYL, !N       ; check for N for full all 8 cols
                RBRA    _RTTR_END, 1

                ; rotate right
_RTTR_RR        NOP

_RTTR_END       DECRB
                RET

; ****************************************************************************
; PAINT_PLAYFIELD
;   paint the actual playfield including the logo
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
                MOVE    QTRIS_0, R8
                MOVE    QTRIS_X, R9
                MOVE    QTRIS_Y, R10
                MOVE    QTRIS_H, R6
_PPF_NEXT_QT    RSUB    PRINT_STR_AT, 1
                ADD     QTRIS_W, R8
                ADD     1, R8
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
