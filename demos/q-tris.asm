; Q-TRIS is a Tetris clone and the first game ever developed for QNICE-FPGA.
; It uses the PS2/USB keyboard and VGA, no matter how STDIN/STDOUT are routed.
; All speed calculations are based on a 50 MHz CPU that is equal to the CPU
; revision contained in release V1.2.
; done by sy2002 in January 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

; ***** TEMP ********
                RBRA    START, 1

TEMP_SEQ_CNT    .DW 10
TEMP_SEQ        .DW 2, 2, 2, 0, 1, 2, 3, 4, 5, 6

START           NOP
; ***** TEMP ********

                ; clear screen, switch of hw cursor
                RSUB    CLRSCR, 1
                MOVE    VGA$STATE, R0
                NOT     VGA$EN_HW_CURSOR, R1
                AND     @R0, R1
                MOVE    R1, @R0

                RSUB    INIT_GLOBALS, 1         ; init global variables
                RSUB    PAINT_PLAYFIELD, 1      ; paint playfield & logo

                MOVE    0, R3                   ; R3: sequence position

MAIN_LOOP       MOVE    TEMP_SEQ, R0
                ADD     R3, R0
                MOVE    @R0, R4                 ; R4: current Tetromino
                MOVE    RenderedNumber, R0
                MOVE    NEW_TTR, @R0

                MOVE    Tetromino_Y, R1
                MOVE    -8, @R1                 ; y start pos = -8
                MOVE    PLAYFIELD_X, R0         ; x start pos is the middle...
                ADD     PLAYFIELD_W, R0         ; ... of the playfield ...
                SHR     1, R0                   ; ..which is ((X+W) / 2) - of
                MOVE    TTR_SX_OFFS, R1         ; of is taken from TTR_SX_OFFS
                MOVE    R4, R2
                ADD     R2, R1
                ADD     @R1, R0
                MOVE    Tetromino_X, R1
                MOVE    R0, @R1
         
DROP            RSUB    DECIDE_DROP, 1
                CMP     0, R8
                RBRA    NEXT_TTR, Z
                
                MOVE    R4, R8
                MOVE    0, R9
                MOVE    1, R10
                MOVE    0, R11
                RSUB    UPDATE_TTR, 1
                RSUB    SPEED_DELAY, 1
                RBRA    DROP, 1

NEXT_TTR        ADD     1, R3
                CMP     7, R3
                RBRA    MAIN_LOOP, !Z

                ; end Q-TRIS
EXIT            SYSCALL(reset, 1)
  

NEW_TTR     .EQU 0xFFFF ; signal value for RenderedNumber: new Tetromino

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

; specifications of the net playfield (without walls)
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

; Tetromino starting position x offset for centering them on screen
TTR_SX_OFFS .DW -1                         ; Tetromino "I"
            .DW -1                         ; Tetromino "O"
            .DW -2                         ; Tetromino "T"
            .DW -2                         ; Tetromino "S"
            .DW -2                         ; Tetromino "Z"
            .DW -2                         ; Tetromino "L"
            .DW -2                         ; Tetromino "J"

; When rotating a Tetromino, take care, that it still fits to the grid
TTR_ROT_XO  .DW -1
            .DW  0
            .DW -1
            .DW -1
            .DW -1
            .DW -1
            .DW -1

; Level speed table
; speed is defined by wasted cycles, both numbers are multiplied
LEVEL_SPEED .DW 400, 400

; ****************************************************************************
; DECIDE_DROP
;   Decides, if the current Tetromino can be dropped one more line down below.
;   This is true, if there is no obstacle under each of the current Tetrominos
;   "pixels" plus if we are not at the bottom, yet
;   R8: returns 1 if true and 0 if falso
; ****************************************************************************

DECIDE_DROP     INCRB

                MOVE    1, R8                   ; assume true for DECIDE_DROP

                ; find the line number and the x-coordinate within the
                ; 8x8 matrix of the current Tetromino, where there is at least
                ; one "pixel" as we need to "look below" it
                ; R6: x-coordinate (column)
                ; R7: y-coordinate (line)
                MOVE    7, R7                   ; search from bottom to top..
                MOVE    RenderedTTR, R0
                ADD     56, R0                  ; .. ditto buffer pointer
_DD_NX_Y        XOR     R6, R6
_DD_NX_X        CMP     0x20, @R0++             ; anything else but space?
                RBRA    _DD_FOUND, !Z           ; yes
                ADD     1, R6                   ; next column
                CMP     8, R6                   ; all columns reached?
                RBRA    _DD_NX_X, !Z            ; no: go on
                SUB     16, R0                  ; yes: one line up ...
                SUB     1, R7                   ; ... ditto buffer pointer
                RBRA    _DD_NX_Y, 1             ; not an endless loop

                ; check, if we reached the bottom of the screen, by
                ; calculating the last coordinate of the playfield and
                ; comparing it to the lowest line of the Tetromino
_DD_FOUND       MOVE    R7, R1
                MOVE    Tetromino_Y, R0
                ADD     @R0, R1                 ; y-pos of lowest line                 
                MOVE    PLAYFIELD_Y, R0         
                ADD     PLAYFIELD_H, R0
                SUB     1, R0                   ; y-pos of last playfield line
                CMP     R0, R1                  ; hit it?
                RBRA    _DD_CHK, !Z             ; no: go on checking
                MOVE    0, R8                   ; yes: return false
                RBRA    _DD_END, 1

_DD_CHK         NOP                

_DD_END         DECRB
                RET

; ****************************************************************************
; MULTITASK
;   Perform tasks, that shall happen "all the time" in the "background", i.e.
;   even when cycles are wasted.
; ****************************************************************************

MULTITASK       INCRB

                ; inc the "random" number
                MOVE    PseudoRandom, R0
                ADD     1, @R0

                ; check for key press and read key
                MOVE    IO$KBD_STATE, R0        ; check keyboard state reg.
                MOVE    KBD$NEW_ANY, R1
                AND     @R0, R1                 ; any key pressed?
                RBRA    _MT_RET, Z              ; no: return

                ; key pressed: read key value
                MOVE    IO$KBD_DATA, R0
                MOVE    @R0, R0

                ; save parameter registers
                MOVE    R8, R1
                MOVE    R9, R2
                MOVE    R10, R3
                MOVE    R11, R4

                MOVE    RenderedNumber, R5
                MOVE    @R5, R8
                XOR     R9, R9
                XOR     R10, R10
                XOR     R11, R11

                ; cursor left: move left
                CMP     KBD$CUR_LEFT, R0
                RBRA    _MT_N_LEFT, !Z
                MOVE    -2, R9
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; cursor right: move right
_MT_N_LEFT      CMP     KBD$CUR_RIGHT, R0       ; move right
                RBRA    _MT_N_RIGHT, !Z
                MOVE    2, R9
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; x: rotate left
_MT_N_RIGHT     CMP     0x78, R0                ; "x" = ASCII 0x78
                RBRA    _MT_N_x, !Z
                MOVE    1, R11
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; c: rotate right
_MT_N_x         CMP     0x63, R0                ; "c" = ASCII 0x63
                RBRA    _MT_ELSE, !Z
                MOVE    2, R11
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; CTRL+E or F12 exit
_MT_ELSE        CMP     KBD$CTRL_E, R0
                RBRA    EXIT, Z
                CMP     KBD$F12, R0
                RBRA    EXIT, Z
                RBRA    _MT_RET_REST, 1

                ; restore parameter registers
_MT_RET_REST    MOVE    R1, R8
                MOVE    R2, R9
                MOVE    R3, R10
                MOVE    R4, R11

_MT_RET         DECRB
                RET

; ****************************************************************************
; UPDATE_TTR
;   Deletes the old Tetromino from the screen, re-renders it, if necessary
;   due to a new Tetromino or due to rotation, updates the global coordinates
;   and paints the new one.
;   R8: new number of Tetromino
;   R9: delta x
;   R10: delta y
;   R11: rotation
; ****************************************************************************

UPDATE_TTR      INCRB
                
                ; save original values of the parameter registers
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                ; delete old Tetromino
                MOVE    Tetromino_X, R4
                MOVE    @R4, R8
                MOVE    Tetromino_Y, R4
                MOVE    @R4, R9
                MOVE    0, R10
                RSUB    PAINT_TTR, 1

                ; if the current Tetromino is a new one, the rotate x-pos
                ; compensation mechanism needs to be deactivated
                MOVE    RenderedNumber, R4
                CMP     NEW_TTR, @R4
                RBRA    _UTTR_IGN_OLD, Z        ; new Tetromino
                MOVE    Tetromino_HV, R4        ; existing: is it currently
                MOVE    @R4, R5                 ; horizontal or vertical
                RBRA    _UTTR_RENDER, 1

_UTTR_IGN_OLD   MOVE    0, R5

                ; render new tetromino to render buffer
_UTTR_RENDER    MOVE    R0, R8
                MOVE    R3, R9
                RSUB    RENDER_TTR, 1

                ; if the Tetromino was rotated, we need to compensate
                ; the x-axis position to still make it fit into the grid
                MOVE    Tetromino_HV, R4        ; get new HV orientation
                MOVE    @R4, R4                 
                CMP     R4, R5
                RBRA    _UTTR_PAINT, Z          ; orientation did not change
                MOVE    TTR_ROT_XO, R6          ; look up compensation...
                ADD     R8, R6                  ; ...per Tetromino
                CMP     R5, 0                   ; if was horizontal before...
                RBRA    _UTTR_WAS_H, Z
                ADD     @R6, R1                 ; ...then we need to add
                RBRA    _UTTR_PAINT, 1
_UTTR_WAS_H     SUB     @R6, R1                 ; ...otherwise we need to sub

                ; paint new Tetromino
_UTTR_PAINT     MOVE    Tetromino_X, R4
                ADD     R1, @R4
                MOVE    @R4, R8
                MOVE    Tetromino_Y, R4
                ADD     R2, @R4
                MOVE    @R4, R9
                MOVE    1, R10
                RSUB    PAINT_TTR, 1

                ; restore paramter registers
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11

                DECRB
                RET

; ****************************************************************************
; PAINT_TTR
;   Draws or clears the tetromino at the specified xy-pos respecting
;   "transparency" which is defined as 0x20 ("space"). Negative y-positions
;   are possible to allow the "slide-in" effect for each new Tetromino.
;   Uses RenderedTTR as source.
;   R8: x-pos
;   R9: y-pos
;   R10: 0 = clear, 1 = paint
; ****************************************************************************

PAINT_TTR       INCRB

                MOVE    VGA$CR_X, R0            ; R0: hw cursor X
                MOVE    VGA$CR_Y, R1            ; R1: hw cursor Y
                MOVE    VGA$CHAR, R2            ; R2: print at hw cursor pos

                MOVE    R8, @R0                 ; set hw x pos

                MOVE    RenderedTTR, R3         ; source memory location

                MOVE    0, R5                   ; R5: line counter
_PAINT_TTR_YL   MOVE    8, R4                   ; R4: column counter
                MOVE    R9, R7                  ; is R9+R5 < 0, i.e. is the...
                ADD     R5, R7                  ; y-pos negative?
                CMP     0, R7
                RBRA    _PAINT_TTR_XL, !N       ; no: go on painting
                ADD     8, R3                   ; yes: skip line
                RBRA    _PAINT_NEXT_LN, 1       

_PAINT_TTR_XL   CMP     0x20, @R3               ; transparent "pixel"?
                RBRA    _PAINT_TTR_SKIP, Z      ; yes: skip painting

                MOVE    R7, @R1                 ; set hw cursor y-pos

                CMP     0, R10                  ; no: check: clear or paint?
                RBRA    _PAINT_CLEAR, Z         ; clear
                MOVE    @R3, @R2                ; paint
                RBRA    _PAINT_TTR_SKIP, 1
_PAINT_CLEAR    MOVE    0x20, @R2               ; clear                

_PAINT_TTR_SKIP ADD     1, R3                   ; next source "pixel"
                ADD     1, @R0                  ; next screen x-pos
                SUB     1, R4                   ; column counter
                RBRA    _PAINT_TTR_XL, !Z       ; column done? no: go on
_PAINT_NEXT_LN  MOVE    R8, @R0                 ; yes: reset x-pos
                ADD     1, R5                   ; line counter to next line
                CMP     8, R5                   ; all lines done?
                RBRA    _PAINT_TTR_YL, !Z       ; no: go on

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
_CLEAR_RBUF_L   MOVE    0x20, @R0++             ; clear current "pixel"
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
;   R9: rotation: 0 = do not rotate, 1 = rotate left, 2 = rotate right
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

                ; all Tetrominos start horizontal
                MOVE    Tetromino_HV, R0
                MOVE    0, @R0

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

                MOVE    Tetromino_HV, R0        ; flip the orientation
                XOR     1, @R0

                CMP     2, R9                   ; rotate right?
                RBRA    _RTTR_RR, Z             ; yes

                ; rotate left:
                ; walk through the source tile column by column starting from
                ; the rightmost column and ending at the leftmost column
                ; going through each column from top to bottom and copy
                ; the resulting bytes from left to right to the destination
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

                ; rotate right:
                ; walk through the source tile column by column starting from
                ; the leftmost column and ending at the rightmost column
                ; going through each column from bottom to top and copy
                ; the resulting bytes from left to right to the destination
_RTTR_RR        MOVE    RenderedTTR, R2         ; R2: dest.: rotated Tetromino
                XOR     R3, R3                  ; R3: source column counter
_RTTR_RR_DYL    MOVE    RenderedTemp, R0        ; R0: source: raw Tetromino
                ADD     R3, R0                  ; select right source column
                ADD     56, R0                  ; go to the last row
                MOVE    8, R4                   ; 8 "pixels" per row
_RTTR_RR_DXL    MOVE    @R0, @R2++              ; copy "pixel"
                SUB     8, R0                   ; go up one row
                SUB     1, R4                   ; all "pixels" copied in col.
                RBRA    _RTTR_RR_DXL, !Z        ; no: go on
                ADD     1, R3                   ; yes: next col
                CMP     8, R3                   ; all cols copied?
                RBRA    _RTTR_RR_DYL, !Z        ; no: go on

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
                MOVE    PLAYFIELD_H, R6         ; R6: playfield height
                MOVE    PLAYFIELD_Y, @R1        ; hw cursor y = start y pos
_PPF_NEXT_LINE  MOVE    PLAYFIELD_X, @R0        ; hw cursor x = start x pos
                SUB     1, @R0                  ; PLAYFIELD_X is a net coord.
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
; SPEED_DELAY
;   Wastes (a x b) iterations whereas a and b are determined by the level
;   speed table (LEVEL_SPEED) and the current game level (Level).
; ****************************************************************************

SPEED_DELAY     INCRB

                ; retrieve the two multipliers and store them to R0 and R1
                MOVE    Level, R7
                MOVE    @R7, R0
                SUB     1, R0                   ; level counting starts with 1
                SHL     1, R0                   ; 2 words per table entry
                MOVE    LEVEL_SPEED, R7
                ADD     R0, R7                  ; select table row
                MOVE    @R7++, R0               ; R0 contains first multiplier
                MOVE    @R7, R1                 ; R1 contains second mult.

                MOVE    R1, R2                  ; remeber R1
                MOVE    1, R3                   ; for more precise counting

                ; waste cycles but continue to multitask while waiting
_SPEED_DELAY_L  RSUB    MULTITASK, 1
                SUB     R3, R1
                RBRA    _SPEED_DELAY_L, !Z
                MOVE    R2, R1
                SUB     R3, R0
                RBRA    _SPEED_DELAY_L, !Z

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
; INIT_GLOBALS
;    Initialize global variables.
; ****************************************************************************
                
INIT_GLOBALS    INCRB

                MOVE    RenderedNumber, R0      ; make sure, that very first..
                MOVE    NEW_TTR, @R0            ; ..Tetromino is rendered
                MOVE    Level, R0               ; start with Level 1
                MOVE    1, @R0
                MOVE    PseudoRandom, R0        ; Init PseudoRandom to 0
                MOVE    0, @R0

                DECRB
                RET

; ****************************************************************************
; GLOBAL VARIABLES
; ****************************************************************************

RenderedNumber  .BLOCK 1    ; Number of last Tetromino that was rendered
RenderedTTR     .BLOCK 64   ; Tetromino rendered in the correct angle
RenderedTemp    .BLOCK 64   ; Tetromino rendered in neutral position

Level           .BLOCK 1    ; Current level (determines speed and score)
PseudoRandom    .BLOCK 1    ; Pseudo random number is just a fast counter

Tetromino_X     .BLOCK 1    ; x-pos of current Tetromino on screen
Tetromino_Y     .BLOCK 1    ; y-pos of current Tetromino on screen
Tetromino_HV    .BLOCK 1    ; Tetromino currently horiz. (0) or vert. (1)
