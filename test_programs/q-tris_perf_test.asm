; ****************************************************************************
; Q-TRIS
;
; Tetris clone and the first game ever developed for QNICE-FPGA.
;
; The rules of the game are very close to the "official" Tetris rules as
; they can be found e.g. on http://tetris.wikia.com/wiki/Tetris_Guideline
;
; Clearing a larger amount of lines at once (e.g. Double, Triple, Q-TRIS)
; leads to much higher scores. The scoring algorithm is:
; (<amount of cleared lines> ^ 2) x <Level>
;
; Clearing a certain treshold of lines leads to the next level. The game
; speed increases from level top level. If you clear 1.000 lines, then
; you win the game.
;
; The game uses the PS2/USB keyboard and VGA, no matter how STDIN/STDOUT
; are routed. All speed calculations are based on a 50 MHz CPU that is equal
; to the CPU revision contained in release V1.3.
;
; The game can run stand-alone, i.e. instead of the Monitor as the "ROM"
; for the QNICE-FPGA - or - it can run regularly as an app. In the latter case
; it loads to 0x8000. #define QTRIS_STANDALONE for the standalone mode.
;
; done by sy2002 in January and February 2016
; ****************************************************************************
;
; PERFORMANCE TEST VERSION TO DETERMINE THE MIPS DURING PLAYING Q-TRIS
;
; Measurement #1 done on MEGA65 by sy2002 on July, 13th 2020:
; Clock cycles: 0003 C771 F13E = 16.231.035.198 => 324,62 sec
; Instructions: 0000 EA6E 73D1 =  3.933.107.153 => 12,12 MIPS
;
; ****************************************************************************

#undef QTRIS_STANDALONE

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

#ifdef QTRIS_STANDALONE
                .ORG    0x0000                  ; start at 0x0000
                AND     0x00FF, SR              ; make sure we are at rbank 0
                MOVE    0xFEFF, SP              ; setup stack pointer
#else
                .ORG    0x8000                  ; start at 0x8000
#endif

                ; PERFORMANCE TEST CODE
                MOVE    IO$CYC_STATE, R0    ; reset hw cycle counter
                MOVE    1, @R0
                MOVE    IO$INS_STATE, R0    ; reset hw instruction counter
                MOVE    1, @R0

                ; STANDARD Q-TRIS CODE
                RSUB    INIT_SCREENHW, 1        ; clear screen, no hw cursor
                RSUB    INIT_GLOBALS, 1         ; init global variables
                RSUB    PAINT_PLAYFIELD, 1      ; paint playfield & logo
                RSUB    PAINT_STATS, 1          ; paint score, level, etc.
                RSUB    HANDLE_PAUSE, 1         ; check space, inc pseudo rnd
NEXT_GAME       RSUB    DRAW_FROM_BAG, 1        ; randomizer algorithm
                MOVE    R8, R3                  ; R3: result = next Tetromino

                ; use "draw from bag" algorithm to dice a new Tetromino
MAIN_LOOP       RSUB    DRAW_FROM_BAG, 1        ; dice another Tetromino
                MOVE    R3, R4                  ; R4: old "next" = new current
                MOVE    R8, R3                  ; R3: dice result = new "next"
                RSUB    PAINT_NEXT_TTR, 1       ; fill the preview window
                MOVE    RenderedNumber, R0      ; make sure the renderer...
                MOVE    NEW_TTR, @R0            ; ...treats this TTR as new

                ; show score, level, lines, stats and check if game is won
                RSUB    PAINT_STATS, 1          ; update all stats on screen
                MOVE    Level, R0
                CMP     GAME_WON, @R0           ; game won?
                RBRA    CALC_TTR_POS, !Z        ; no: new TTR emerges
                MOVE    1, R8                   ; make sure "you win" is shown
                RBRA    END_GAME_W, 1

                ; calculate the position where new Tetrominos emerge from
CALC_TTR_POS    MOVE    Tetromino_Y, R1
                MOVE    -8, @R1                 ; y start pos = -8
                MOVE    PLAYFIELD_X, R0         ; x start pos is the middle...
                ADD     PLAYFIELD_W, R0         ; ... of the playfield ...
                SHR     1, R0                   ; ..which is ((X+W) / 2) - of
                MOVE    TTR_SX_Offs, R1         ; of is taken from TTR_SX_Offs
                MOVE    R4, R2
                ADD     R2, R1
                ADD     @R1, R0
                MOVE    Tetromino_X, R1
                MOVE    R0, @R1
         
                ; drop the Tetromino using the speed given from the current
                ; Level: SPEED_DELAY uses a look up table for the speed and
                ; executes the MULTITASK routine for keyboard handling while
                ; wasting CPU cycles to slow down the game
DROP            RSUB    HANDLE_PAUSE, 1         ; pause game, if needed
                XOR     R8, R8                  ; R8 = 0 means move down
                RSUB    DECIDE_MOVE, 1          ; can we move down?
                CMP     0, R9                   
                RBRA    HNDL_COMPL_ROWS, Z      ; no: handle completed rows
                
                MOVE    R4, R8                  ; yes: move down one row
                XOR     R9, R9
                MOVE    1, R10
                XOR     R11, R11
                RSUB    UPDATE_TTR, 1
                MOVE    1, R8                   ; multitask on while delay
                RSUB    SPEED_DELAY, 1          ; game speed regulation
                RBRA    DROP, 1

                ; detect a potential game over and handle completed rows
HNDL_COMPL_ROWS MOVE    Tetromino_Y, R1          
                CMP     -5, @R1                 ; reached upper boundary?
                RBRA    END_GAME_L, V           ; yes: end game (game over)
                RSUB    COMPLETED_ROWS, 1       ; no: handle completed rows

                ; next iteration
                RBRA    MAIN_LOOP, 1

                ; handle end of the game
END_GAME_L      XOR     R8, R8                  ; show "game over" message
END_GAME_W      RSUB    HANDLE_END, 1           ; prepare for next round
                RBRA    NEXT_GAME, 1            ; play next game

                ; end Q-TRIS (will only be called in non-stand-alone mode)
EXIT            SYSCALL(vga_init, 1)            ; cursor blinking, etc.
                SYSCALL(vga_cls, 1)             ; clear screen

                ; PERFORMANCE TEST CODE

                MOVE    IO$CYC_STATE, R0
                MOVE    0, @R0              ; stop hw cycle counter
                MOVE    IO$INS_STATE, R0
                MOVE    0, @R0              ; stop hw instruction counter

                ; output cycle counter

                MOVE    PERF_STR, R8
                SYSCALL(puts, 1)            ; output info string
                MOVE    IO$CYC_HI, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output hi word of 48bit counter
                MOVE    SPACE_STR, R8
                SYSCALL(puts, 1)
                MOVE    IO$CYC_MID, R1
                MOVE    @R1, R8                 
                SYSCALL(puthex, 1)          ; output mid word of 48bit counter
                MOVE    SPACE_STR, R8
                SYSCALL(puts, 1)                
                MOVE    IO$CYC_LO, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output lo word of 48bit counter
                SYSCALL(crlf, 1)

                ; output instruction counter

                MOVE    INS_STR, R8
                SYSCALL(puts, 1)            ; output info string
                MOVE    IO$INS_HI, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output hi word of 48bit counter
                MOVE    SPACE_STR, R8
                SYSCALL(puts, 1)
                MOVE    IO$INS_MID, R1
                MOVE    @R1, R8                 
                SYSCALL(puthex, 1)          ; output mid word of 48bit counter
                MOVE    SPACE_STR, R8
                SYSCALL(puts, 1)                
                MOVE    IO$INS_LO, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output lo word of 48bit counter

                SYSCALL(exit, 1)                ; return to monitor

; PERFORMANCE TEST CODE
PERF_STR    .ASCII_W    "Overall clock cycles: "
INS_STR     .ASCII_W    "Overall instructions: "
SPACE_STR   .ASCII_W    " "

; STANDARD GAME FROM HERE ONWARDS

NEW_TTR     .EQU 0xFFFF ; signal value for RenderedNumber: new Tetromino

; Game logo
QTRIS_X     .EQU 25     ; x-pos on screen
QTRIS_Y     .EQU 1      ; y-pos on screen
QTRIS_W     .EQU 53     ; width of the pattern in chars (without zero term.)
QTRIS_H     .EQU 6      ; height of the pattern in lines
QTris       .ASCII_W "  ____             _______   _____    _____    _____ "
            .ASCII_W " / __ \           |__   __| |  __ \  |_   _|  / ____|"
            .ASCII_W "| |  | |  ______     | |    | |__) |   | |   | (___  "
            .ASCII_W "| |  | | |______|    | |    |  _  /    | |    \___ \ "
            .ASCII_W "| |__| |             | |    | | \ \   _| |_   ____) |"
            .ASCII_W " \___\_\             |_|    |_|  \_\ |_____| |_____/ "

; Logos (game over, game won) and restart message
GAME_OVER_X .EQU 33
GAME_OVER_Y .EQU 2
GAME_OVER_W .EQU 37
GAME_OVER_H .EQU 12
Game_Over   .ASCII_W "  _____              __  __   ______ "
            .ASCII_W " / ____|     /\     |  \/  | |  ____|"
            .ASCII_W "| |  __     /  \    | \  / | | |__   "
            .ASCII_W "| | |_ |   / /\ \   | |\/| | |  __|  "
            .ASCII_W "| |__| |  / ____ \  | |  | | | |____ "
            .ASCII_W " \_____| /_/    \_\ |_|  |_| |______|"
            .ASCII_W "  ____   __      __  ______   _____  "
            .ASCII_W " / __ \  \ \    / / |  ____| |  __ \ "
            .ASCII_W "| |  | |  \ \  / /  | |__    | |__) |"
            .ASCII_W "| |  | |   \ \/ /   |  __|   |  _  / "
            .ASCII_W "| |__| |    \  /    | |____  | | \ \ "
            .ASCII_W " \____/      \/     |______| |_|  \_\ "

GAME_WON_X  .EQU 36
GAME_WON_Y  .EQU 2
GAME_WON_W  .EQU 30
GAME_WON_H  .EQU 12
Game_Won    .ASCII_W " __     __   ____    _    _   "
            .ASCII_W " \ \   / /  / __ \  | |  | |  "
            .ASCII_W "  \ \_/ /  | |  | | | |  | |  "
            .ASCII_W "   \   /   | |  | | | |  | |  "
            .ASCII_W "    | |    | |__| | | |__| |  "
            .ASCII_W "    |_|     \____/   \____/   "
            .ASCII_W "__          __  _____   _   _ "
            .ASCII_W "\ \        / / |_   _| | \ | |"
            .ASCII_W " \ \  /\  / /    | |   |  \| |"
            .ASCII_W "  \ \/  \/ /     | |   | . ` |"
            .ASCII_W "   \  /\  /     _| |_  | |\  |"
            .ASCII_W "    \/  \/     |_____| |_| \_|"

#ifdef QTRIS_STANDALONE
RESTMSG_X   .EQU 39
RESTMSG_Y   .EQU 16
RestartMsg  .ASCII_W "Space key to restart game"
#else
RESTMSG_X   .EQU 25
RESTMSG_Y   .EQU 16
RestartMsg  .ASCII_W "Space key to restart game  F12 or CTRL+E to exit game"
#endif

; Credits and help text
CAH_X       .EQU 41
CAH_Y       .EQU 8
CAH_W       .EQU 40

#ifdef QTRIS_STANDALONE
CAH_H       .EQU 9          ; do not show the "Exit the game..." string
#else
CAH_H       .EQU 10
#endif

CRE_A_HELP  .ASCII_W "Q-TRIS V1.1 by sy2002 in May 2016       "
            .ASCII_W "                                        "
            .ASCII_W "How to play:                            "
            .ASCII_W "                                        "
            .ASCII_W "* Space key starts game and pauses      "
            .ASCII_W "* Cursor left / right / down to move    "
            .ASCII_W "* Drop using cursor up                  "
            .ASCII_W "* Rotate left using the 'x' key         "
            .ASCII_W "* Rotate right using the 'c' key        "            
            .ASCII_W "* Exit the game using F12 or CTRL+E     "

; Stats (_LX, _LY = label coordinates, _X, _Y = display coordinates)
STSCORE_LX  .EQU 25                         
STSCORE_LY  .EQU 20                         
STSCORE_X   .EQU 25                            
STSCORE_Y   .EQU 22                            
Stat_Score  .ASCII_W "Score:"
STLEVEL_LX  .EQU 70 
STLEVEL_LY  .EQU 20
STLEVEL_X   .EQU 70
STLEVEL_Y   .EQU 22
Stat_Level  .ASCII_W "Level:"
STLINES_LX  .EQU 25
STLINES_LY  .EQU 32
STLINES_X   .EQU 33
STLINES_Y   .EQU 32
Stat_Lines  .ASCII_W "Lines:"
STSINGLE_LX .EQU 25
STSINGLE_LY .EQU 34
STSINGLE_X  .EQU 33
STSINGLE_Y  .EQU 34
Stat_Single .ASCII_W "Single:"
STDOUBLE_LX .EQU 25
STDOUBLE_LY .EQU 35
STDOUBLE_X  .EQU 33
STDOUBLE_Y  .EQU 35
Stat_Double .ASCII_W "Double:"
STTRIPLE_LX .EQU 25
STTRIPLE_LY .EQU 36
STTRIPLE_X  .EQU 33
STTRIPLE_Y  .EQU 36
Stat_Triple .ASCII_W "Triple:"
STQTRIS_LX  .EQU 25
STQTRIS_LY  .EQU 37
STQTRIS_X   .EQU 33
STQTRIS_Y   .EQU 37
Stat_QTris  .ASCII_W "Q-Tris:"

; Digits 0..9
DIGITS_DX   .EQU 7      ; width of one digit
DIGITS_DY   .EQU 7      ; height of one digit
DIGITS_WPD  .EQU 56     ; words per digits in memory (incl. zero terminator)
DIGITS_XSP  .EQU 1      ; space between two digits on screen
Digits      .ASCII_W "  ###  "
            .ASCII_W " #   # "
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W " #   # "
            .ASCII_W "  ###  "
            .ASCII_W "   #   "
            .ASCII_W "  ##   "
            .ASCII_W " # #   "
            .ASCII_W "   #   "
            .ASCII_W "   #   "
            .ASCII_W "   #   "
            .ASCII_W " ##### "
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "      #"
            .ASCII_W " ##### "
            .ASCII_W "#      "
            .ASCII_W "#      "
            .ASCII_W "#######"
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "      #"
            .ASCII_W " ##### "
            .ASCII_W "      #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
            .ASCII_W "#      "
            .ASCII_W "#    # "
            .ASCII_W "#    # "
            .ASCII_W "#    # "
            .ASCII_W "#######"
            .ASCII_W "     # "
            .ASCII_W "     # "
            .ASCII_W "#######"
            .ASCII_W "#      "
            .ASCII_W "#      "
            .ASCII_W "###### "
            .ASCII_W "      #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "#      "
            .ASCII_W "###### "
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
            .ASCII_W "#######"
            .ASCII_W "#    # "
            .ASCII_W "    #  "
            .ASCII_W "   #   "
            .ASCII_W "  #    "
            .ASCII_W "  #    "
            .ASCII_W "  #    "
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
            .ASCII_W " ##### "
            .ASCII_W "#     #"
            .ASCII_W "#     #"
            .ASCII_W " ######"
            .ASCII_W "      #"
            .ASCII_W "#     #"
            .ASCII_W " ##### "
                                         
; special painting characters
WALL_L      .EQU 0x09   ; left wall
WALL_R      .EQU 0x08   ; right wall
LN_COMPLETE .EQU 0x11   ; line(s) completed blink char (together with 0x20)

; specifications of the net playfield (without walls)
PLAYFIELD_X .EQU 2      ; x-pos on screen
PLAYFIELD_Y .EQU 0      ; y-pos on screen
PLAYFIELD_H .EQU 40     ; height
PLAYFIELD_W .EQU 20     ; width

; Tetromino patterns
TTR_AMOUNT  .EQU 7
Tetrominos  .DW 0x20, 0x20, 0x20, 0x20     ; Tetromino "I"
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
TTR_Offs    .DW 0, 1                       ; Tetromino "I"
            .DW 0, 2                       ; Tetromino "O"
            .DW 1, 2                       ; Tetromino "T"
            .DW 1, 2                       ; Tetromino "S"
            .DW 1, 2                       ; Tetromino "Z"
            .DW 1, 2                       ; Tetromino "L"
            .DW 1, 2                       ; Tetromino "J"

; Tetromino starting position x offset for centering them on screen
TTR_SX_Offs .DW -1                         ; Tetromino "I"
            .DW -1                         ; Tetromino "O"
            .DW -2                         ; Tetromino "T"
            .DW -2                         ; Tetromino "S"
            .DW -2                         ; Tetromino "Z"
            .DW -2                         ; Tetromino "L"
            .DW -2                         ; Tetromino "J"

; When rotating a Tetromino, take care, that it still fits to the grid
TTR_Rot_Xo  .DW -1
            .DW  0
            .DW -1
            .DW -1
            .DW -1
            .DW -1
            .DW -1

; Preview window for next Tetromino
PREVIEW_X   .EQU 25
PREVIEW_Y   .EQU 10
PREVIEW_W   .EQU 12
PREVIEW_H   .EQU 8
Preview_Win .DW 0x86, 0x8A, 0x8D, 0x4E, 0x65, 0x78, 0x74, 0x87, 0x8A, 0x8A, 0x8A, 0x8C, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x85, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x85, 0
            .DW 0x83, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x8A, 0x89, 0

; Level advancement table
; how many lines does the player need to clear to advance one level
Level_Thresh .DW    5       ;    5 Lines => Level 2
             .DW   10       ;   10 Lines => Level 3
             .DW   20       ;   20 Lines => Level 4
             .DW   40       ;   40 Lines => Level 5
             .DW   80       ;   80 Lines => Level 6
             .DW  160       ;  160 Lines => Level 7
             .DW  320       ;  320 Lines => Level 8
             .DW  640       ;  640 Lines => Level 9
             .DW 1000       ; 1000 Lines => Game Won
             .DW 2000       ; dummy for non existing "Level 10"

GAME_WON     .EQU 10        ; game is won, when "Level 10" is reached

; Level speed table
; speed is defined by wasted cycles, both numbers are multiplied
; second number is also used for blinking frequency, so adjust carefully
; (preferably only adjust the first number)
Level_Speed .DW 946, 251    ; Level 1  (was 800 at V1.21)
            .DW 827, 251    ; Level 2  (was 700 at V1.21)
            .DW 709, 251    ; Level 3  (was 600 at V1.21)
            .DW 591, 251    ; Level 4  (was 500 at V1.21)
            .DW 532, 251    ; Level 5  (was 450 at V1.21)
            .DW 473, 251    ; Level 6  (was 400 at V1.21)
            .DW 414, 251    ; Level 7  (was 350 at V1.21)
            .DW 355, 251    ; Level 8  (was 300 at V1.21)
            .DW 296, 251    ; Level 9  (was 250 at V1.21)
            .DW 296, 251    ; non existing "Level 10" => Game Won

; ****************************************************************************
; HANDLE_END
;   Displays either the normal "game over" message or the "you win" message,
;   depending on the parameter R8. Then handle the keyboard for triggering
;   a restart or for triggering a game exit.
;   R8: 0 = game over message; 1 = you win message
; ****************************************************************************

HANDLE_END      INCRB

                MOVE    R8, R0

                MOVE    QTRIS_X, R8             ; clear rect for message
                MOVE    QTRIS_Y, R9
                MOVE    QTRIS_W, R10
                ADD     1, R10
                MOVE    18, R11
                RSUB    CLR_RECT, 1

                CMP     1, R0                   ; print win message?
                RBRA    _HANDLE_END_GO, !Z      ; no: print game over

                MOVE    Game_Won, R8            ; yes: print win message
                MOVE    GAME_WON_X, R9
                MOVE    GAME_WON_Y, R10
                MOVE    GAME_WON_W, R11
                MOVE    GAME_WON_H, R12
                RSUB    PRINT_PATTERN, 1
                RBRA    _HANDLE_END_RM, 1

_HANDLE_END_GO  MOVE    Game_Over, R8           ; print game over
                MOVE    GAME_OVER_X, R9
                MOVE    GAME_OVER_Y, R10
                MOVE    GAME_OVER_W, R11
                MOVE    GAME_OVER_H, R12
                RSUB    PRINT_PATTERN, 1

_HANDLE_END_RM  MOVE    RestartMsg, R8          ; print restart message
                MOVE    RESTMSG_X, R9
                MOVE    RESTMSG_Y, R10
                RSUB    PRINT_STR_AT, 1

                MOVE    Pause, R0               ; Wait for space to be pressed
                MOVE    1, @R0
                RSUB    HANDLE_PAUSE, 1

                RSUB    CLR_SCR, 1              ; rebuild clean screen
                RSUB    PAINT_PLAYFIELD, 1
                RSUB    RESTART_GAME, 1         ; reset global game variables

                DECRB
                RET

; ****************************************************************************
; HANDLE_STATS
;   Uses the current level and the amount of cleared lines to update all
;   global statistic variables including score, lines, line-stats. Also
;   takes care that the level upgrade happens.
;   R8: amount of cleared lines
; ****************************************************************************

HANDLE_STATS    INCRB

                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                INCRB

                CMP     0, R8                   ; no line cleared
                RBRA    _H_STATS_RET, Z

                ; update "how-many-lines-cleared" specific stat variables
                ; (treat them like an array; as they are ordered linearily
                ; in memory, we can do that)
                MOVE    Lines_Single, R0        ; "pointer to the array"     
                ADD     R8, R0                  ; index to "array"
                SUB     1, R0                   ; 1 cleared = Lines_Single
                ADD     1, @R0                  ; update stat

                ; update line counter
                MOVE    Lines, R0          
                MOVE    Lines_Old, R1
                MOVE    @R0, @R1                
                ADD     R8, @R0

                ; ascend the level ladder
                MOVE    Level_Thresh, R3        ; Level threshold table
                MOVE    Level, R4               ; calculate next treshold ...
                ADD     @R4, R3                 ; ... for current level
                SUB     1, R3                   
                CMP     @R3, @R0                ; lines < treshold?
                RBRA    _H_STATS_SCORE, N       ; yes: go on, calculate score
                ADD     1, @R4                  ; no: increase level

                ; score += (squared amount of lines) x (level)
                ; the amount of lines is squared, to reward the player
                ; when clearing large blocks
                ; the level is multipled to account for the higher difficulty
                ; in higher levels
_H_STATS_SCORE  MOVE    R8, R9
                RSUB    MUL, 1
                MOVE    R10, R8
                MOVE    Level, R9
                MOVE    @R9, R9
                RSUB    MUL, 1
                MOVE    Score, R0
                ADD     R10, @R0

_H_STATS_RET    DECRB

                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11

                DECRB
                RET

; ****************************************************************************
; HANDLE_PAUSE
;   If "Pause" == 1, then wait for space to be pressed again and while
;   waiting, PseudoRandom is incremented.
; ****************************************************************************

HANDLE_PAUSE    INCRB

                ; skip this function if no pause mode
                MOVE    Pause, R4
                CMP     0, @R4
                RBRA    _HP_RET, Z

                ; check for key press and read key
                MOVE    IO$KBD_STATE, R0        ; check keyboard state reg.                  
                MOVE    PseudoRandom, R2                
_HP_WAITFORKEY  ADD     1, @R2                  ; inc pseudo random number
                MOVE    KBD$NEW_ANY, R1       
                AND     @R0, R1                 ; any key pressed?
                RBRA    _HP_WAITFORKEY, Z       ; no: loop

                ; key pressed: space? yes, pause ends, no: loop goes on
                MOVE    IO$KBD_DATA, R5                                
                MOVE    @R5, R5                 ; read pressed key
                CMP     KBD$SPACE, R5           ; space pressed?
                RBRA    _HP_END_PAUSE, Z        ; yes: end pause

#ifndef QTRIS_STANDALONE
                CMP     KBD$CTRL_E, R5          ; CTRL+E pressed?
                RBRA    EXIT, Z                 ; yes: exit game
                CMP     KBD$F12, R5             ; F12 pressed?
                RBRA    EXIT, Z                 ; yes: exit game
#endif                

                RBRA    _HP_WAITFORKEY, 1       ; unknown key: loop

                ; disable pause mode                
_HP_END_PAUSE   MOVE    0, @R4

_HP_RET         DECRB
                RET

; ****************************************************************************
; PAINT_NEXT_TTR
;   Fill the preview window by painting the next upcoming Tetromino.
;   R8: number of upcoming Tetromino
; ****************************************************************************

PAINT_NEXT_TTR  INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4

                INCRB

                MOVE    R8, R0

                ; print preview window
                MOVE    Preview_Win, R8
                MOVE    PREVIEW_X, R9
                MOVE    PREVIEW_Y, R10
                MOVE    PREVIEW_W, R11
                MOVE    PREVIEW_H, R12
                RSUB    PRINT_PATTERN, 1

                ; render preview TTR
                MOVE    RenderedNumber, R1      ; make sure the renderer...
                MOVE    NEW_TTR, @R1            ; ...treats this TTR as new
                MOVE    R0, R8                  ; original TTR to be shown                
                XOR     R9, R9                  ; no rotation
                RSUB    RENDER_TTR, 1

                ; paint preview TTR
                MOVE    PREVIEW_X, R8
                ADD     2, R8
                MOVE    PREVIEW_Y, R9
                MOVE    1, R10
                RSUB    PAINT_TTR, 1

                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12

                DECRB
                RET

; ****************************************************************************
; DRAW_FROM_BAG
;   Implements the "Random Generator" according to the official
;   Tetris Guideline, e.g. as seen here:
;
;   http://tetris.wikia.com/wiki/Random_Generator
;
;   Random Generator generates a sequence of all Tetrominos permuted randomly,
;   as if they were drawn from a bag. Then it deals all seven Tetrominos to
;   the piece sequence before generating another bag.
;
;   R8: Number between 0 and (TTR_AMOUNT - 1)
; ****************************************************************************

DRAW_FROM_BAG   INCRB

                MOVE    Tetromino_BFill, R0     ; empty bag?
                CMP     0, @R0
                RBRA    _DFB_START, !Z

                ; create new bag
                MOVE    Tetromino_Bag, R1       ; R1: pointer to bag
                XOR     R2, R2                  ; R2: counter to fill bag
_DFB_FILL       MOVE    R2, @R1++               ; fill bag: 0, 1, 2, 3, ...
                ADD     1, R2   
                CMP     TTR_AMOUNT, R2          ; bag full?
                RBRA    _DFB_FILL, !Z           ; no: go on filling
                MOVE    TTR_AMOUNT, @R0         ; yes: store new bag size
                RBRA    _DFB_MODULO, 1

_DFB_START      CMP     TTR_AMOUNT, @R0         ; bag completely full?
                RBRA    _DFB_MODULO, Z          ; yes

                ; compress bag by filling all empty spots (marked by -1)
                ; with their right neighbour
                MOVE    Tetromino_Bag, R1
                XOR     R2, R2
_DFB_CP_CMP     CMP     -1, @R1                 ; empty spot?
                RBRA    _DFB_CP_ES, Z
_DFB_CP_NEXT    ADD     1, R1
                ADD     1, R2
                CMP     TTR_AMOUNT, R2
                RBRA    _DFB_CP_CMP, !Z
                RBRA    _DFB_MODULO, 1

_DFB_CP_ES      MOVE    R1, R3                  ; R3: bagpointer (saved)
                MOVE    R2, R4                  ; R4: counter (saved)
_DFB_CP_ESCP    CMP     TTR_AMOUNT, R4          ; end of bag reached?
                RBRA    _DFB_CP_NEXT, Z         ; yes: back to upper loop
                MOVE    R3, R5
                ADD     1, R5
                MOVE    @R5, @R3
                ADD     1, R3
                ADD     1, R4
                RBRA    _DFB_CP_ESCP, 1

                ; calculate last byte of "PseudoRandom" modulo the amount
                ; of Tetrominos in the current compressed bag to draw
                ; a Tetromino
_DFB_MODULO     MOVE    PseudoRandom, R1
                MOVE    @R1, R1

                AND     0x00FF, R1

_DFB_DO_MOD_C   CMP     R1, @R0
                RBRA    _DFB_DO_MOD_S, N
                CMP     R1, @R0
                RBRA    _DFB_DO_MOD_S, Z
                RBRA    _DFB_DRAW, 1

_DFB_DO_MOD_S   SUB     @R0, R1
                RBRA    _DFB_DO_MOD_C, 1

                ; draw a Tetromino
_DFB_DRAW       MOVE    Tetromino_Bag, R2
                ADD     R1, R2
                MOVE    @R2, R8
                MOVE    -1, @R2

                SUB     1, @R0                

                DECRB
                RET

; ****************************************************************************
; COMPLETED_ROWS
;   Handle completed rows: The current Tetromino_Y position is the starting
;   point, from where overall 8 lines on the screen (4 Tetromino "pixels") are
;   checked. Completed rows are marked within the list "CompletedRows".
;   Then the completed rows are visualzed by a blinking "graphics effect",
;   which blinks as often as lines were cleard.
;   After that they are cleared with space characters and then the whole
;   playfield is compressed accordingly.
; ****************************************************************************

COMPLETED_ROWS  INCRB
                MOVE    R8, R0                  ; save R8 .. R12
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4

                INCRB

                MOVE    VGA$CR_X, R0            ; screen memory access
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2

                MOVE    NumberOfCompl, R8       ; assume zero completed rows
                MOVE    0, @R8
                MOVE    CompletedRows, R7       ; list with all compl. rows

                ; handle negative y values
                MOVE    8, R4                   ; R4: how many y-lines visible
                MOVE    Tetromino_Y, R3
                MOVE    @R3, R3                 ; R3 = Tetromino Y start coord
                CMP     0, R3                   ; is it < 0?
                RBRA    _CRH_START, !V          ; no: start
                MOVE    R3, R4                  ; yes: how many lines visible?
                ADD     8, R4                   ; R4: how many y-lines visible
                RBRA    _CRH_RET, Z             ; return, if no y-lines visib.
                MOVE    0, R3                   ; R3: assume 0 as start coord

                ; scan the environemnt of the recently dropped Tetromino
                ; by checking, if whole screen lines are "non-spaces"
                ; and if so, remember this line in @R7 (CompletedRows)
_CRH_START      MOVE    R3, R11                 ; remember y-start coord
                MOVE    R4, R12                 ; remember amount of visib. y
_CRH_NEXT_Y     MOVE    0, @R7                  ; asumme: row is not completed
                MOVE    Playfield_MY, R6        ; get maximum y-coord
                CMP     R3, @R6                 ; current y > maximum y coord
                RBRA    _CRH_NEXT_LINE, V       ; yes: skip line
                MOVE    R3, @R1                 ; hw cursor y to the first row
                MOVE    PLAYFIELD_X, @R0        ; hw cursor x to the left
                MOVE    PLAYFIELD_W, R5         ; init column counter

_CRH_NEXT_X     CMP     0x20, @R2               ; a single space is enough...
                RBRA    _CRH_NEXT_LINE, Z       ; ...to detect non-completion
                ADD     1, @R0                  ; next x-coordinate
                SUB     1, R5                   ; dec width cnt, line done?
                RBRA    _CRH_NEXT_X, !Z         ; loop if line is not done
                MOVE    1, @R7                  ; line fully scanned: complete
                ADD     1, @R8                  ; one more "blink"

_CRH_NEXT_LINE  SUB     1, R4                   ; one less line to check
                RBRA    _CRH_CHK_COMPL, Z       ; all lines scanned, now check
                ADD     1, R3                   ; increase y counter
                ADD     1, R7                   ; next element in compl. list
                RBRA    _CRH_NEXT_Y, 1          ; scan next line

                ; blink completed lines
_CRH_CHK_COMPL  CMP     0, @R8                  ; any lines completed?
                RBRA    _CRH_RET, Z             ; no: return

                MOVE    R11, R9                 ; first scanned line on scrn
                MOVE    R12, R10                ; amount of lines to process                
                MOVE    @R8, R3                 ; amount of "blinks"
                SHR     1, R3                   ; 2 screen pixels = 1 real row

                MOVE    R3, R8                  ; process cleared lines ...
                RSUB    HANDLE_STATS, 1         ; ... by updating all stats

_CRH_BLINK      MOVE    LN_COMPLETE, R8         ; completion character
                RSUB    PAINT_LN_COMPL, 1       ; paint it
                MOVE    0, R8                   ; no "multitasking" while...
                RSUB    SPEED_DELAY, 1          ; ...performing a delay
                MOVE    0x20, R8                ; use the space character ...
                RSUB    PAINT_LN_COMPL, 1       ; to clear the compl. char
                MOVE    0, R8                   ; and again no "multitasking"
                RSUB    SPEED_DELAY, 1          ; while waiting
                SUB     1, R3                   ; done blinking?
                RBRA    _CRH_BLINK, !Z          ; no: go on blinking

                ; let the playfield fall down to fill the cleared lines
                MOVE    R11, R3
                MOVE    R12, R5

CRH_PD_NEXT_Y   MOVE    Playfield_MY, R7
                CMP     R3, @R7                 ; y > playfield size?
                RBRA    _CRH_RET, V             ; yes: return

                MOVE    R3, @R1                 ; hw cursor to y start line

                MOVE    PLAYFIELD_X, @R0        ; hw cursor to x start column
                MOVE    PLAYFIELD_W, R4         ; width of one column
CRH_PD_NEXT_X   CMP     0x20, @R2               ; is there a space char?
                RBRA    _CRH_PD_NEXT_LN, !Z     ; one non-space means: not clr
                ADD     1, @R0                  ; yes: next column
                SUB     1, R4                   ; column done?
                RBRA    CRH_PD_NEXT_X, !Z       ; no: continue checking

                MOVE    R3, R8                  ; line is cleared, so ...
                RSUB    PF_FALL_DN, 1           ; let the playfield fall down
                MOVE    0, R8                   ; no "multitasking"...
                RSUB    SPEED_DELAY, 1          ; ...while delaying

_CRH_PD_NEXT_LN ADD     1, R3                   ; scan again: one line deeper
                SUB     1, R5                   ; whole Tetromino env. scanned
                RBRA    CRH_PD_NEXT_Y, !Z       ; no: continue scanning

_CRH_RET        DECRB
                MOVE    R0, R8                  ; restore R8 .. R12
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12

                DECRB
                RET

; ****************************************************************************
; PF_FALL_DN
;   Let the whole playfield above line R8 let fall down into line R8.
;   R8: the line that has been cleared and that should be filled now
; ****************************************************************************

PF_FALL_DN      INCRB

                MOVE    VGA$CR_X, R0            ; screen memory access
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2

                MOVE    R8, @R1                 ; hw y cursor to cleared ln

_PFFD_NY        SUB     1, @R1                  ; take the line above it
                RBRA    _PFFD_RET, N            ; return, if out of bounds
                MOVE    PLAYFIELD_X, @R0        ; first column
                MOVE    PLAYFIELD_W, R4         ; amount of chars per column

_PFFD_NX        MOVE    @R2, R5                 ; take one char above
                ADD     1, @R1                  ; go one line down
                MOVE    R5, @R2                 ; copy the char from above
                SUB     1, @R1                  ; go up one line for next char
                ADD     1, @R0                  ; next x-position
                SUB     1, R4                   ; any column left?
                RBRA    _PFFD_NX, !Z            ; yes: go on
                RBRA    _PFFD_NY, 1             ; no: next line

_PFFD_RET       DECRB
                RET

; ****************************************************************************
; PAINT_LN_COMPL
;   Scans the list of completed lines in "CompletedRows" and paints all of
;   these lines using the character submitted in R8 onto the screen.
;   Note, that CompletedRows is always relative to the current Tetromino.
;   R8: character to be painted
;   R9: y-start position on screen (relative to the Tetromino)
;   R10: amount of lines within the Tetromino to process
; ****************************************************************************

PAINT_LN_COMPL  INCRB

                MOVE    VGA$CR_X, R0            ; screen memory access
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2

                MOVE    CompletedRows, R7       ; list with all compl. rows
                MOVE    R9, R3                  ; first scanned line on scrn
                MOVE    R10, R4                 ; amount of lines to process                

                MOVE    Playfield_MY, R6        ; current y line larger ...
_PLN_NEXT_CLY   CMP     R3, @R6                 ; ... than maximum y position?
                RBRA    _PLN_RET, V             ; yes: return

                CMP     1, @R7                  ; current line completed?
                RBRA    _PLN_N_COMPL_NY, !Z     ; no: next line

                MOVE    PLAYFIELD_W, R5         ; yes: init column counter
                MOVE    PLAYFIELD_X, @R0        ; hw cursor to start column
                MOVE    R3, @R1                 ; hw cursor to correct y pos
_PLN_NEXT_CLC   MOVE    R8, @R2                 ; paint completion char
                ADD     1, @R0
                SUB     1, R5
                RBRA    _PLN_NEXT_CLC, !Z

_PLN_N_COMPL_NY ADD     1, R3
                ADD     1, R7
                SUB     1, R4
                RBRA    _PLN_NEXT_CLY, !Z

_PLN_RET        DECRB
                RET

; ****************************************************************************
; DECIDE_MOVE
;   Checks if a planned move in a certain direction (R8) is possible. It does
;   so by checking, if for each pixel in the 8x8 Tetromino matrix there is
;   room to move in the desired direction.
;   R8: direction: 0 = down, 1 = left, 2 = right, 3 = actual pos. (rotation)
;   R9: returns true (1) is the move is OK and false (0) if not
; ****************************************************************************

DECIDE_MOVE     INCRB

                MOVE    1, R9                   ; assume return true

                MOVE    R8, R0                  ; save R8, R10, R11, R12
                MOVE    R10, R1
                MOVE    R11, R2
                MOVE    R12, R3

                INCRB

                ; R0: hw x-cursor
                ; R1: hw y-cursor
                MOVE    VGA$CR_X, R0
                MOVE    VGA$CR_Y, R1

                ; R3: lowest possible y-position
                MOVE    Playfield_MY, R3
                MOVE    @R3, R3

                ; Set up an x and y "checking" offset: this offset is added
                ; to the current Tetromino x|y position for checking if
                ; the playfield is free there. Obviously depends on R8
                ; R10: x-checking-offset
                ; R11: y-checking-offset
                CMP     0, R8                   ; look downwards?
                RBRA    _DM_N_DN, !Z            ; no: continue to check
                XOR     R10, R10                ; yes: x-offset is 0 then...
                MOVE    1, R11                  ; ...and y-offset is 1
                RBRA    _DM_START, 1
_DM_N_DN        CMP     1, R8                   ; look left?
                RBRA    _DM_N_LT, !Z            ; no: continue to check
                MOVE    -1, R10                 ; yes: left means -1 as x-offs
                XOR     R11, R11                ; and 0 as y-offs
                RBRA    _DM_START, 1
_DM_N_LT        CMP     2, R8                   ; look right?
                RBRA    _DM_N_RT, !Z            ; no: continue to check
                MOVE    1, R10                  ; yes: right means 1 as x-offs
                XOR     R11, R11                ; and 0 as y offs
                RBRA    _DM_START, 1
_DM_N_RT        CMP     3, R8                   ; look at the actual position?
                RBRA    _DM_RET, !Z             ; no: illegal param. => return
                XOR     R10, R10                ; yes: x-offset is 0...
                XOR     R11, R11                ; ... and y-offset is 0

                ; set HW cursor to the y start pos of the Tetromino
                ; 8x8 matrix and apply the scanning offset
                ; R8 is needed as @R1 is not able to store negative values
                ; but as we slide in Tetrominos from negative y-positions, we
                ; need to be able to handle negative values
_DM_START       MOVE    Tetromino_Y, R6
                MOVE    @R6, R8
                ADD     R11, R8                 ; apply the y scanning offset
                MOVE    R8, @R1                 ; set HW cursor to Tetromini_Y

                MOVE    0, R4                   ; R4: line counter (y)
_DM_LOOP_Y      MOVE    R4, R5                  ; R5: y offset = 8 x y
                SHL     3, R5 
                MOVE    Tetromino_X, R6         ; set hw cursor to x start...
                MOVE    @R6, @R0                ; ...pos of Tetromino 8x8...
                ADD     R10, @R0                ; matrix and aplly scan offs
                MOVE    0, R6                   ; R6: column counter (x)
_DM_LOOP_X      MOVE    RenderedTTR, R7         ; pointer to Tetromino pattern
                ADD     R6, R7                  ; add x offset
                ADD     R5, R7                  ; add y offset (R5 = 8 x R4)

                ; basic idea: is there a pixel within the Tetromino pattern?
                ; if yes, then first check, if we are still at negative y
                ; values (sliding in) or if we reached the bottom of the scrn
                ; and if both are false, then check, if below or right or
                ; left (depending on the initial R8 parameter) of the pixel
                ; there is an obstacle on the screen, that is not the
                ; own pixel of the Tetromino
                CMP     0x20, @R7               ; empty "pixel" in Tetromino?
                RBRA    _DM_PX_FOUND, !Z        ; no: there is a pixel
                RBRA    _DM_INCX, 1             ; yes: skip to next pixel

_DM_PX_FOUND    CMP     0, R8                   ; negative y scanning coord?
                RBRA    _DM_EMULATE_WL, V       ; yes: emulate walls
                CMP     @R1, R3                 ; maximum y-position reached?
                RBRA    _DM_OBSTACLE, V         ; yes (@R1 > R3): return false
                MOVE    VGA$CHAR, R2            ; hw register for reading scrn   
                CMP     0x20, @R2               ; empty "pixel" on screen?
                RBRA    _DM_IS_IT_OWN, !Z       ; no: check if it is an own px
                RBRA    _DM_INCX, 1             ; yes: go to next checking pos

                ; while we are at negative y-positions, we need to emulate the
                ; walls of the playfield, so that the player cannot trick the
                ; game and move Tetrominos "over" the walls using very fast
                ; actions (e.g. double-rotate a "L" and then move it to the
                ; left very rapidly: it would stick - or - just move a "Z"
                ; very rapidly to the left: it would stick, too)
_DM_EMULATE_WL  MOVE    PLAYFIELD_X, R2
                SUB     1, R2
                CMP     R2, @R0                 ; emulate left wall
                RBRA    _DM_IS_IT_OWN, Z
                MOVE    PLAYFIELD_X, R2
                ADD     PLAYFIELD_W, R2
                CMP     R2, @R0                 ; emulate right wall
                RBRA    _DM_IS_IT_OWN, Z
                RBRA    _DM_INCX, 1

_DM_IS_IT_OWN   MOVE    R4, R12                 ; current y position
                ADD     R11, R12                ; apply y scanning offset
                CMP     0, R12                  ; y negative out-of-bound?                
                RBRA    _DM_INCX, V             ; yes: skip to next pixel
                CMP     8, R12                  ; y positive out-of-bound?
                RBRA    _DM_OBSTACLE, Z         ; yes: obstacle found
                MOVE    R6, R2                  ; current x position
                ADD     R10, R2                 ; apply x scanning offset
                CMP     0, R2                   ; x negative out-of-bound?                
                RBRA    _DM_OBSTACLE, V         ; yes: obstacle found
                CMP     8, R2                   ; x positive out-of-bound?
                RBRA    _DM_OBSTACLE, Z         ; yes: obstacle found
                SHL     3, R12                  ; (R12 = y) x 8 (line offset)
                ADD     R2, R12                 ; add (R2 = x)
                ADD     RenderedTTR, R12        ; completing the offset
                CMP     0x20, @R12              ; Tetromino empty here?
                RBRA    _DM_OBSTACLE, Z         ; then obstacle is found

                ; Arriving here means: No obstacle found in the classical
                ; movement situations, so we could jump to the next pixel
                ; by branching to _DM_INCX. But there is a special case:
                ; Rotation: if R10 == R11 == 0, then we have a rotation, and
                ; in this case, we want to know, if "under" the pixels of the
                ; potentially rotated Tetromino there are other pixels of
                ; other elements, because then the rotation is not allowed
                ; ("other elements" can also be the playfield borders)
                CMP     0, R10                  ; R10 == 0?
                RBRA    _DM_INCX, !Z            ; no rotation, no obstacle
                CMP     0, R11                  ; R11 == 0?
                RBRA    _DM_INCX, !Z            ; no rotation, no obstacle
                RBRA    _DM_OBSTACLE, 1         ; rotation: obstacle found

_DM_OBSTACLE    MOVE    0, R9                   ; obstacle detected ...
                RBRA    _DM_RET, 1              ; ... return false

_DM_INCX        ADD     1, R6                   ; next column...
                ADD     1, @R0                  ; ...ditto for hardware cursor
                CMP     8, R6                   ; line end reached?
                RBRA    _DM_LOOP_X, !Z          ; no: go on

_DM_INCY        ADD     1, R4                   ; next line, ditto for the..
                ADD     1, R8                   ; ..hw crs buffer R8 and for..
                MOVE    R8, @R1                 ; ..the hw cursor itself
                CMP     8, R4                   ; Tetromino end reached?
                RBRA    _DM_LOOP_Y, !Z          ; no go on

_DM_RET         DECRB                           ; restore R8, R10, R11, R12
                MOVE    R0, R8
                MOVE    R1, R10
                MOVE    R2, R11
                MOVE    R3, R12

                DECRB
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

                ; key pressed: inc "random" value and read key value
                MOVE    PseudoRandom, R0
                ADD     1, @R0
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
                MOVE    1, R8
                RSUB    DECIDE_MOVE, 1          ; can we move left?                
                CMP     0, R9
                RBRA    _MT_RET_REST, Z         ; no: return
                MOVE    @R5, R8                 ; yes: restore R8 ...
                MOVE    -2, R9                  ; ... and move left
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; cursor right: move right
_MT_N_LEFT      CMP     KBD$CUR_RIGHT, R0
                RBRA    _MT_N_RIGHT, !Z
                MOVE    2, R8
                RSUB    DECIDE_MOVE, 1          ; can we move right?
                CMP     0, R9
                RBRA    _MT_RET_REST, Z         ; no: return
                MOVE    @R5, R8                 ; yes: restore R8 ...
                MOVE    2, R9                   ; ... and move right
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
                RBRA    _MT_N_c, !Z
                MOVE    2, R11
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; cursor down: move down one row
_MT_N_c         CMP     KBD$CUR_DOWN, R0
                RBRA    _MT_N_DOWN, !Z
                XOR     R8, R8
                RSUB    DECIDE_MOVE, 1          ; can we move down?
                CMP     0, R9
                RBRA    _MT_RET_REST, Z         ; no: return
                MOVE    @R5, R8                 ; yes: restore R8
                XOR     R9, R9
                MOVE    1, R10                  ; move down
                RSUB    UPDATE_TTR, 1
                RBRA    _MT_RET_REST, 1

                ; cursor up: drop Tetromino as far as possible
_MT_N_DOWN      CMP     KBD$CUR_UP, R0
                RBRA    _MT_N_UP, !Z
                MOVE    Tetromino_Y, R11
                MOVE    @R11, R6                ; remember original y pos
                XOR     R10, R10                ; R10: line counter = 0
                XOR     R8, R8
_MT_DROP_DM     RSUB    DECIDE_MOVE, 1          ; can we move down one more ln
                CMP     1, R9                   
                RBRA    _MT_DROP_CHK, !Z        ; no: check how many we could
                ADD     1, R10                  ; yes: inc line counter
                ADD     1, @R11                 ; inc y pos: check a ln deeper
                RBRA    _MT_DROP_DM, 1

_MT_DROP_CHK    MOVE    R6, @R11                ; restore original y pos
                CMP     0, R10                  ; can we drop 1 or more lines?
                RBRA    _MT_RET_REST, Z         ; no: return
                MOVE    @R5, R8                 ; yes: restore Tetromino num.
                XOR     R9, R9                  ; delta x = 0; dx still in R10
                XOR     R11, R11                ; no rotation
                RSUB    UPDATE_TTR, 1           ; drop by R10 lines
                RBRA    _MT_RET_REST, 1

                ; activate pause mode
_MT_N_UP        CMP     KBD$SPACE, R0
                RBRA    _MT_ELSE, !Z
                MOVE    Pause, R8
                MOVE    1, @R8
                RBRA    _MT_RET_REST, 1

#ifdef QTRIS_STANDALONE
_MT_ELSE        RBRA    _MT_RET_REST, 1
#else
                ; CTRL+E or F12 exit
_MT_ELSE        CMP     KBD$CTRL_E, R0
                RBRA    EXIT, Z
                CMP     KBD$F12, R0
                RBRA    EXIT, Z
                RBRA    _MT_RET_REST, 1
#endif

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
                MOVE    TTR_Rot_Xo, R6          ; look up compensation...
                ADD     R8, R6                  ; ...per Tetromino
                CMP     0, R5                   ; if was horizontal before...
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
                RBRA    _PAINT_TTR_XL, !V       ; no: go on painting
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
;   Renders the Tetromino and rotates it, if specified by R9.
;
;   Automatically remembers the last Tetromino and its position so that
;   subsequent calls can be performed. The 8x8 buffer RenderedTTR contains
;   the resulting pattern. RenderedTemp is used temporarily and RenderedNumber
;   is used to remember, which tetromino has been rendered last time.
;
;   Additionally, when rotating, the routine checks, if the resulting,
;   rendered Tetromino is still "valid", i.e. not outside the boundaries
;   and also not overlapping with any existing piece; otherwise the rotation
;   command is ignored and the old pattern in copied back from RenderedTemp.
;   For the outside caller to know, if the rotation was performed or ignored,
;   Tetromino_HV can be checked.
;
;   R8: number of tetromino between 0..<amount of Tetrominos>
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
                MOVE    Tetrominos, R0          ; start address of patterns
                MOVE    R8, R1                  ; addr = (# x 8) + start
                SHL     3, R1                   ; SHL 3 means x 8
                ADD     R1, R0                  ; R0: source memory location

                ; calculate the start address within the destination memory
                ; location and take the TTR_Offs table for centering the
                ; Tetrominos within the 8x8 matrix into consideration
                ; R1: contains the destination memory location
                MOVE    R4, R1                  ; R1: destination mem. loc.
                MOVE    R8, R3                  ; TTR_Offs = # x 2
                SHL     1, R3
                ADD     TTR_Offs, R3
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
                RBRA    _RTTR_ROT_DONE, 1

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

                ; after any rotation (left or right):
                ; check if the rotated Tetromino is still "valid", i.e. not
                ; outside the playfield and not obscuring existing "pixels"                
_RTTR_ROT_DONE  MOVE    R8, R6                  ; save R8 & R9
                MOVE    R9, R7
                MOVE    3, R8                   ; check, if the rotation...
                RSUB    DECIDE_MOVE, 1          ; ... is allowed
                CMP     1, R9                   ; rotation allowed?
                RBRA    _RTTR_END_ROTOK, Z      ; yes: flip HV orientation

                ; in case of an invalid rotation: copy back the non-rotated
                ; Tetromino shape, to RenderedTTR and undo the rotation
                MOVE    RenderedTemp, R0
                MOVE    RenderedTTR, R1
                MOVE    64, R3
                MOVE    1, R4
_RTTR_COPYL2    MOVE    @R0++, @R1++
                SUB     R4, R3
                RBRA    _RTTR_COPYL2, !Z
                RBRA    _RTTR_END_REST, 1

_RTTR_END_ROTOK MOVE    Tetromino_HV, R0        ; each rotation flips... 
                XOR     1, @R0                  ; ...the orientation

_RTTR_END_REST  MOVE    R6, R8                  ; restore R8 & R9
                MOVE    R7, R9                            

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
                MOVE    QTris, R8               ; pointer to pattern
                MOVE    QTRIS_X, R9             ; start x-pos on screen
                MOVE    QTRIS_Y, R10            ; start y-pos on screen
                MOVE    QTRIS_W, R11            ; width of pattern
                MOVE    QTRIS_H, R12            ; height of pattern
                RSUB    PRINT_PATTERN, 1

                ; print preview window
                MOVE    Preview_Win, R8
                MOVE    PREVIEW_X, R9
                MOVE    PREVIEW_Y, R10
                MOVE    PREVIEW_W, R11
                MOVE    PREVIEW_H, R12
                RSUB    PRINT_PATTERN, 1

                ; print credits and help text
                MOVE    CRE_A_HELP, R8
                MOVE    CAH_X, R9
                MOVE    CAH_Y, R10
                MOVE    CAH_W, R11
                MOVE    CAH_H, R12
                RSUB    PRINT_PATTERN, 1

                ; print stat labels
                MOVE    Stat_Score, R8
                MOVE    STSCORE_LX, R9
                MOVE    STSCORE_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_Level, R8
                MOVE    STLEVEL_LX, R9
                MOVE    STLEVEL_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_Lines, R8
                MOVE    STLINES_LX, R9
                MOVE    STLINES_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_Single, R8
                MOVE    STSINGLE_LX, R9
                MOVE    STSINGLE_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_Double, R8
                MOVE    STDOUBLE_LX, R9
                MOVE    STDOUBLE_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_Triple, R8
                MOVE    STTRIPLE_LX, R9
                MOVE    STTRIPLE_LY, R10
                RSUB    PRINT_STR_AT, 1
                MOVE    Stat_QTris, R8
                MOVE    STQTRIS_LX, R9
                MOVE    STQTRIS_LY, R10
                RSUB    PRINT_STR_AT, 1

                DECRB
                RET

; ****************************************************************************
; PRINT_PATTERN
;   Prints a rectangular pattern consisting of zero terminated strings.
;   R8: pointer to pattern
;   R9: x-pos
;   R10: y-pos
;   R11: width
;   R12: height
; ****************************************************************************

PRINT_PATTERN   INCRB

                MOVE    R8, R0
                MOVE    R10, R1
                MOVE    R12, R2

_PP_NEXT_Y      MOVE    R11, R3
                RSUB    PRINT_STR_AT, 1
                MOVE    R3, R11
                SUB     1, R2
                RBRA    _PP_RET, Z
                ADD     R11, R8
                ADD     1, R8
                ADD     1, R10
                RBRA    _PP_NEXT_Y, 1

_PP_RET         MOVE    R0, R8
                MOVE    R1, R10

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
                ADD     1, R3                   ; next character in string                
                ADD     1, R4                   ; increase x-pos on screen
                CMP     0, @R3                  ; string end?
                RBRA    _PRINT_STR_LOOP, !Z     ; no: continue printing

                MOVE    R4, R11

                DECRB
                RET

; ****************************************************************************
; PAINT_STATS
;   Prints/paints the statistics, such as score, level, lines and the stats
;   about the lines themselves: single, double, triple, QTris (quadruple)
; ****************************************************************************

PAINT_STATS     INCRB

                ; speed optimization: only when the level changes or the
                ; amount of completed line changes, this routine shall be
                ; executed
                MOVE    Level, R8
                MOVE    Level_Old, R9
                CMP     @R8, @R9
                RBRA    _P_STATS_START, !Z
                MOVE    Lines, R8
                MOVE    Lines_Old, R9
                CMP     @R8, @R9
                RBRA    _P_STATS_START, !Z
                RBRA    _P_STATS_RET, 1

                ; level
_P_STATS_START  MOVE    Level, R8
                MOVE    @R8, R8
                MOVE    GAME_WON, R9            ; non existing level number
                SUB     1, R9                   ; maximum existing level num.
                CMP     R8, R9                  ; current level > max. lnum.?
                RBRA    _P_STATS_PL, !N
                MOVE    R9, R8                  ; yes: set lnum. to max lnum.
_P_STATS_PL     MOVE    STLEVEL_X, R9           ; no: paint digit
                MOVE    STLEVEL_Y, R10
                RSUB    PAINT_DIGIT, 1          ; ASCII art painting
                MOVE    Level_Old, R9           ; remember that this level...
                MOVE    R8, @R9                 ; ...has already been painted

                MOVE    Score, R8
                MOVE    @R8, R8
                MOVE    STSCORE_X, R9
                MOVE    STSCORE_Y, R10
                RSUB    PAINT_DECIMAL,1         ; ASCII art painting

                ; amount of completed lines incl. detailed stats
                MOVE    Lines, R8
                MOVE    @R8, R8
                MOVE    STLINES_X, R9
                MOVE    STLINES_Y, R10
                RSUB    PRINT_DECIMAL, 1
                MOVE    Lines_Old, R9           ; remember that this amount...
                MOVE    R8, @R9                 ; of lines has been painted
                MOVE    Lines_Single, R8
                MOVE    @R8, R8
                MOVE    STSINGLE_X, R9
                MOVE    STSINGLE_Y, R10
                RSUB    PRINT_DECIMAL, 1
                MOVE    Lines_Double, R8
                MOVE    @R8, R8
                MOVE    STDOUBLE_X, R9
                MOVE    STDOUBLE_Y, R10
                RSUB    PRINT_DECIMAL, 1
                MOVE    Lines_Triple, R8
                MOVE    @R8, R8
                MOVE    STTRIPLE_X, R9
                MOVE    STTRIPLE_Y, R10
                RSUB    PRINT_DECIMAL, 1
                MOVE    Lines_QTris, R8
                MOVE    @R8, R8
                MOVE    STQTRIS_X, R9
                MOVE    STQTRIS_Y, R10
                RSUB    PRINT_DECIMAL, 1

_P_STATS_RET    DECRB
                RET

; ****************************************************************************
; PAINT_DECIMAL
;   Paints a 16-bit decimal number (max 5 digits) using the ASCII art font
;   "Digits" in a left-aligned way. No trailing zeros.
;   R8: decimal number
;   R9: x coordinate
;   R10: y coordinate
; ****************************************************************************

PAINT_DECIMAL   INCRB

                MOVE    R8, R0                  ; save R8 .. R10
                MOVE    R9, R1
                MOVE    R10, R2

                INCRB

                MOVE    R9, R1

                ; decimal conversion
                MOVE    _PD_DECIMAL, R9         ; result array
                RSUB    MAKE_DECIMAL, 1         ; R9 now contains R8s digits

                ; remove trailing zeros                
                MOVE    5, R0                   ; how many digits to paint?
_PAINT_D_RTZ    CMP     0, @R9                  ; current digit zero?
                RBRA    _PAINT_D_NTZ, !Z        ; no: trailing zeros removed
                CMP     1, R0                   ; special case: R8 = 0
                RBRA    _PAINT_D_NTZ, Z         ; paint the 0
                ADD     1, R9                   ; skip this 0
                SUB     1, R0                   ; one less digit to be painted
                RBRA    _PAINT_D_RTZ, 1

_PAINT_D_NTZ    MOVE    R9, R2                  ; save pointer to R8s digits
                MOVE    R1, R9                  ; restore x-coordinate                
_PAINT_D_LOOP   MOVE    @R2, R8                 ; dereference pointer
                RSUB    PAINT_DIGIT, 1          ; ASCII art paiting
                ADD     DIGITS_DX, R9           ; x-coord: skip to end of char
                ADD     DIGITS_XSP, R9          ; space between chars
                ADD     1, R2                   ; increase pointer, next digit
                SUB     1, R0                   ; any digits left?
                RBRA    _PAINT_D_LOOP, !Z       ; yes: loop, next digit

                DECRB

                MOVE    R0, R8                  ; restore R8 .. R10
                MOVE    R1, R9
                MOVE    R2, R10

                DECRB
                RET

; ****************************************************************************
; PRINT_DECIMAL
;   Prints a 16-bit decimal number (max 5 digits) in a right-aligned way.
;   No trailing zeros.
;   R8: decimal number
;   R9: x coordinate (of leftmost digit), due to right-alignment, the real
;       coord. of the first printed digit might deviate
;   R10: y coordinate
; ****************************************************************************

PRINT_DECIMAL   INCRB

                MOVE    R8, R0                  ; save R8 .. R11
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                INCRB

                MOVE    _PD_DECIMAL, R9         ; result array
                RSUB    MAKE_DECIMAL, 1         ; R9 now contains R8s digits
                MOVE    _PD_DEC_STR_BUF, R1     ; zero terminated string buf.

                ; ASCII converson of digits
                MOVE    5, R2                   ; five digits hardcoded
_PD_ASCII_CNV   MOVE    @R9++, @R1              ; ASCII conversion of digits:
                ADD     0x30, @R1++             ; add ASCII code of "0"
                SUB     1, R2
                RBRA    _PD_ASCII_CNV, !Z 

                ; remove leading zeros
                MOVE    5, R2                  
                MOVE    _PD_DEC_STR_BUF, R1
_PD_RM_LEAD_0s  CMP     0x30, @R1
                RBRA    _PD_PRINT, !Z
                SUB     1, R2
                RBRA    _PD_PRINT, Z
                MOVE    0x20, @R1++
                RBRA    _PD_RM_LEAD_0s, 1

                ; print string
_PD_PRINT       MOVE    _PD_DEC_STR_BUF, R8     ; str. buffer to be printed
                DECRB
                MOVE    R1, R9                  ; x coord (restore R9)
                MOVE    R2, R10                 ; y coord (restore R10)
                INCRB
                RSUB    PRINT_STR_AT, 1         ; print

                DECRB

                MOVE    R0, R8                  ; only R8 & R11 need to be
                MOVE    R3, R11                 ; restored (R9, R10 above)

                DECRB
                RET

; ****************************************************************************
; PAINT_DIGIT
;   Paints a decimal digit using the ASCII art font "Digits".
;   R8: digit to print
;   R9: x coordinate
;   R10: y coordinate
; ****************************************************************************

PAINT_DIGIT     INCRB

                MOVE    R8, R0                  ; save R8 .. R10
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4

                INCRB

                MOVE    DIGITS_WPD, R9          ; calculate offset for digit
                RSUB    MUL, 1                  ; pattern: R8 x DIGITS_WPD

                MOVE    Digits, R8              ; apply offset
                ADD     R10, R8
                DECRB
                MOVE    R1, R9                  ; x-pos
                MOVE    R2, R10                 ; y-pos
                INCRB
                MOVE    DIGITS_DX, R11          ; width
                MOVE    DIGITS_DY, R12          ; height
                RSUB    PRINT_PATTERN, 1        ; paint digit

                DECRB

                MOVE    R0, R8                  ; restore R8 .. R10
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12

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
;   speed table (Level_Speed) and the current game level (Level).
;   While wasting cycles, SPEED_DELAY can perform the "background tasks", 
;   that are defined in MULTITASK.
;   In mode R8 = 0, the delay of the second multiplier is doubled for
;   compensating the missing delay of the multitasking.
;   R8: 0 = no background tasks (MULTITASK); 1 = perform MULTITASK
; ****************************************************************************

SPEED_DELAY     INCRB

                ; retrieve the two multipliers and store them to R0 and R1
                MOVE    Level, R7
                MOVE    @R7, R0
                SUB     1, R0                   ; level counting starts with 1
                SHL     1, R0                   ; 2 words per table entry
                MOVE    Level_Speed, R7
                ADD     R0, R7                  ; select table row
                MOVE    @R7++, R0               ; R0 contains first multiplier
                MOVE    @R7, R1                 ; R1 contains second mult.

                CMP     1, R8                   ; in R8 = 1 mode ...
                RBRA    _SPEED_DELAY_SS, Z      ; ... skip the doubling
                SHL     1, R1                   ; double the second multiplier

_SPEED_DELAY_SS MOVE    R1, R2                  ; remeber R1
                MOVE    1, R3                   ; for more precise counting

                ; waste cycles but continue to multitask while waiting
_SPEED_DELAY_L  CMP     0, R8                   ; multitasking?
                RBRA    _SPEED_DELAY_SM, Z      ; no: skip it
                RSUB    MULTITASK, 1
_SPEED_DELAY_SM SUB     R3, R1
                RBRA    _SPEED_DELAY_L, !Z
                MOVE    R2, R1
                SUB     R3, R0
                RBRA    _SPEED_DELAY_L, !Z

                DECRB
                RET

; ****************************************************************************
; MAKE_DECIMAL
;   16-bit decimal converter: Input a 16-bit number and receive a 5-element
;   list of digits between 0 and 9. Highest decimal at the lowest
;   memory address, unused leading decimals are filled with zero.
;   No overflow or sanity checks are performed.
;   performed.
;   R8: 16-bit number
;   R9: pointer to the 5-word list that will contain the decimal digits
; ****************************************************************************

MAKE_DECIMAL    INCRB

                MOVE    R8, R6                  ; preserve R8 & R9
                MOVE    R9, R7

                MOVE    10, R4                  ; R4 = 10
                XOR     R5, R5                  ; R5 = 0                

                MOVE    R9, R0                  ; R0: points to result list
                ADD     5, R0                   ; lowest digit at end of list

_MD_LOOP        MOVE    R4, R9                  ; divide by 10
                RSUB    DIV_AND_MODULO, 1       ; R8 = "shrinked" dividend
                MOVE    R9, @--R0               ; extract current digit place
                CMP     R5, R8                  ; done?
                RBRA    _MD_LOOP, !Z            ; no: next iteration

_MD_LEADING_0   CMP     R7, R0                  ; enough leading "0" there?
                RBRA    _MD_RET, Z              ; yes: return
                MOVE    0, @--R0                ; no: add a "0" digit
                RBRA    _MD_LEADING_0, 1

_MD_RET         MOVE    R6, R8                  ; restore R8 & R9
                MOVE    R7, R9
                DECRB
                RET

; ****************************************************************************
; DIV_AND_MODULO
;   16-bit integer division including modulo.
;   Ignores the sign of the dividend and the divisor.
;   Division by zero yields to an endless loop.
;   Input:
;      R8: Dividend
;      R9: Divisor
;   Output:
;      R8: Integer quotient
;      R9: Modulo
; ****************************************************************************

DIV_AND_MODULO  INCRB

                XOR     R0, R0                  ; R0 = 0

                CMP     R0, R8                  ; 0 divided by x = 0 ...
                RBRA    _DAM_START, !Z
                MOVE    R0, R9                  ; ... and the modulo is 0, too
                RBRA    _DAM_RET, 1

_DAM_START      MOVE    R9, R1                  ; R1: divisor
                MOVE    R8, R9                  ; R9: modulo
                MOVE    1, R2                   ; R2 is 1 for speeding up
                XOR     R8, R8                  ; R8: resulting int quotient

_DAM_LOOP       ADD     R2, R8                  ; calculate quotient
                SUB     R1, R9                  ; division by repeated sub.
                RBRA    _DAM_COR_OFS, V         ; wrap around: correct offset
                CMP     R0, R9
                RBRA    _DAM_RET, Z             ; zero: done and return
                RBRA    _DAM_LOOP, 1

                ; correct the values, as we did add 1 one time too much to the
                ; quotient and subtracted the divisor one time too much from
                ; the modulo for the sake of having a maxium tight inner loop
_DAM_COR_OFS    SUB     R2, R8
                ADD     R1, R9

_DAM_RET        DECRB
                RET

; ****************************************************************************
; MUL
;   16-bit integer multiplication, that only calculates the low-word of the
;   multiplication, i.e. (factor 1 x factor 2) needs to be smaller than
;   65535, otherwise the result wraps around. The factors as well as the
;   result are treated as unsigned.
;   Input:
;      R8: factor 1
;      R9: factor 2
;   Output:
;      R10: low word of (factor 1 x factor 2)
; ****************************************************************************

MUL             INCRB

                XOR     R10, R10                ; result = 0
                CMP     R10, R8                 ; if factor 1 = 0 ...
                RBRA    _MUL_RET, Z             ; ... then the result is 0

                MOVE    R8, R0                  ; counter for repeated adding
                MOVE    1, R1                   ; R1 = 1
                XOR     R2, R2                  ; R2 = 0

_MUL_LOOP       ADD     R9, R10                 ; multiply by rep. additions
                SUB     R1, R0                  ; are we done?
                RBRA    _MUL_COR_OFS, V         ; yes due to overflow: return
                CMP     R2, R0                  ; are we done?
                RBRA    _MUL_RET, Z             ; yes due to counter = 0
                RBRA    _MUL_LOOP, 1

_MUL_COR_OFS    SUB     R9, R10                 ; we added one time too often

_MUL_RET        DECRB
                RET

; ****************************************************************************
; CLR_SCR
;   Clear the screen
; ****************************************************************************

CLR_SCR         INCRB
                MOVE    VGA$STATE, R0
                OR      VGA$CLR_SCRN, @R0
                RSUB    WAIT_FOR_VGA, 1
                DECRB
                RET

; ****************************************************************************
; CLR_RECT
;   Clears the specified rectangle by printing spaces (0x20).
;   Minimum width/height is 1. No sanity checks are performed.
;   R8|R9:   x|y start coordinates
;   R10|R11: width, height
; ****************************************************************************

CLR_RECT        INCRB
                
                MOVE    VGA$CR_X, R0            ; VGA register access
                MOVE    VGA$CR_Y, R1
                MOVE    VGA$CHAR, R2

                MOVE    1, R3                   ; increase performance
                MOVE    0x20, R4                ; ASCII 0x20 = space

                MOVE    R10, R5                 ; calculate end coordinates
                ADD     R8, R5                  ; R5: x end coordinate
                MOVE    R11, R6
                ADD     R9, R6                  ; R6: y end coordinate

                MOVE    R9, @R1                 ; set y hw cursor to y
_CLR_RECT_YL    MOVE    R8, @R0                 ; set x hw cursor to x
_CLR_RECT_XL    MOVE    R4, @R2                 ; clear position
                ADD     R3, @R0                 ; next x
                CMP     R5, @R0                 ; x end coordinate reached?
                RBRA    _CLR_RECT_XL, !Z        ; no: continue looping x
                ADD     R3, @R1                 ; next y
                CMP     R6, @R1                 ; y end coordinate reached?
                RBRA    _CLR_RECT_YL, !Z        ; no: conitnue looping y

                DECRB
                RET

; ****************************************************************************
; INIT_SCREENHW
;   Clear the screen and do not display the hardware cursor
; ****************************************************************************

INIT_SCREENHW   INCRB

                MOVE    VGA$STATE, R0

#ifdef QTRIS_STANDALONE
                MOVE    0x00E0, @R0             ; enable everything
                OR      VGA$COLOR_GREEN, @R0    ; Set font color to green
#endif
                RSUB    CLR_SCR, 1
                NOT     VGA$EN_HW_CURSOR, R1    ; no blinking hw cursor
                AND     @R0, R1
                MOVE    R1, @R0
                DECRB
                RET

; ****************************************************************************
; INIT_GLOBALS
;    Initialize global variables at startup.
; ****************************************************************************
                
INIT_GLOBALS    INCRB

                MOVE    PseudoRandom, R0        ; Init PseudoRandom to 0
                MOVE    0, @R0
                MOVE    Playfield_MY, R0        ; maximum playfield y pos
                MOVE    PLAYFIELD_Y, @R0
                ADD     PLAYFIELD_H, @R0
                SUB     1, @R0
                MOVE    Pause, R0               ; first game starts paused
                MOVE    1, @R0                

                RSUB    RESTART_GAME, 1         ; init game dependent vars.

                DECRB
                RET

; ****************************************************************************
; RESTART_GAME
;    Reset all global variables, that are needed from game to game.
; ****************************************************************************

RESTART_GAME    INCRB

                MOVE    RenderedNumber, R0      ; make sure, that very first..
                MOVE    NEW_TTR, @R0            ; ..Tetromino is rendered
                MOVE    Level, R0               ; start with Level 1
                MOVE    1, @R0
                MOVE    Level_Old, R0
                MOVE    0, @R0
                MOVE    Tetromino_BFill, R0     ; bag is empty
                MOVE    0, @R0
                MOVE    Score, R0               ; initialize stats
                MOVE    0, @R0
                MOVE    Lines, R0               
                MOVE    0, @R0
                MOVE    Lines_Old, R0
                MOVE    -1, @R0
                MOVE    Lines_Single, R0
                MOVE    0, @R0
                MOVE    Lines_Double, R0
                MOVE    0, @R0
                MOVE    Lines_Triple, R0
                MOVE    0, @R0
                MOVE    Lines_QTris, R0
                MOVE    0, @R0

                DECRB
                RET

; ****************************************************************************
; LOCAL VARIABLES
; ****************************************************************************

#ifdef QTRIS_STANDALONE
                .ORG    0x8000                  ; ensure variables are in RAM
#endif

; PRINT_DECIMAL
_PD_DECIMAL     .BLOCK 5    ; array that stores the digits
_PD_DEC_STR_BUF .BLOCK 5    ; zero terminated string buffer
                .DW 0

; ****************************************************************************
; GLOBAL VARIABLES
; ****************************************************************************

RenderedNumber  .BLOCK 1    ; Number of last Tetromino that was rendered
RenderedTTR     .BLOCK 64   ; Tetromino rendered in the correct angle
RenderedTemp    .BLOCK 64   ; Tetromino rendered in neutral position

Score           .BLOCK 1    ; Score of the player in current game
Level           .BLOCK 1    ; Current level (determines speed and score)
Level_Old       .BLOCK 1    ; Speed optimization when painting stats
Lines           .BLOCK 1    ; Amount of completed lines in current game:
Lines_Old       .BLOCK 1    ; Speed optimization when painting stats
Lines_Single    .BLOCK 1    ; ... cleared as single
Lines_Double    .BLOCK 1    ; ... cleared as double (needs to follow Single)
Lines_Triple    .BLOCK 1    ; ... cleared as triples (needs to follow Double)
Lines_QTris     .BLOCK 1    ; ... cleared as quadruples aka Q-Tris (fllw Trpl)
PseudoRandom    .BLOCK 1    ; Pseudo random number is just a fast counter
Pause           .BLOCK 1    ; Game currently paused?

Playfield_MY    .BLOCK 1    ; Maximum Y-Coord = PLAYFIELD_Y + PLAYFIELD_H - 1

Tetromino_X     .BLOCK 1    ; x-pos of current Tetromino on screen
Tetromino_Y     .BLOCK 1    ; y-pos of current Tetromino on screen
Tetromino_HV    .BLOCK 1    ; Tetromino currently horiz. (0) or vert. (1)
Tetromino_Bag   .BLOCK 7    ; Bag for the Random Generator
Tetromino_BFill .BLOCK 1    ; How many Tetrominos are in the bag?

CompletedRows   .BLOCK 8    ; List that stores completed rows
NumberOfCompl   .BLOCK 1    ; Amount of completed rows (equals blink amount)
