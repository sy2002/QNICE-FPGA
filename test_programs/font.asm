; displays all 256 characters of the current VGA font on the VGA screen
; and then waits for a key to be pressed on STDIN
; (therefore only works, if VGA is present, on UART, nothing is being output)
; done by sy2002 in January 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

START_X         .EQU 24
START_Y         .EQU 5        

                ; switch off cursor and hw scrolling and clear screen
                RSUB    CLRSCR, 1

                ; draw y axis legend
                MOVE    VGA$CR_Y, R0
                MOVE    VGA$CR_X, R1
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

LOOP_Y          MOVE    START_X, R3             ; x-starting pos. of each row
                XOR     R9, R9                  ; current x-counter: 0..15

LOOP_X          MOVE    R3, @R0                 ; cursor x-pos to hardware
                MOVE    R4, @R1                 ; dito cursor y-pos
                MOVE    R8, @R2                 ; print character on VGA
                RSUB    WAIT_FOR_VGA, 1         ; wait for print being done

                ADD     2, R3                   ; skip one column
                ADD     1, R8                   ; next character
                ADD     1, R9                   ; x-counter: 0..15
                CMP     16, R9                  ; already more than 15?
                RBRA    LOOP_X, !Z              ; no: next column

                ADD     2, R4                   ; yes: next line
                CMP     256, R8                 ; already more than 255 chars?
                RBRA    LOOP_Y, !Z              ; no: go on printing

                ; wait for a keypress, then return to the system by
                ; reseting (necessary to restore cursor, HW scrolling, etc.)
                SYSCALL(getc, 1)
                RSUB    CLRSCR, 1
                SYSCALL(reset, 1)

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
                RSUB    WAIT_FOR_VGA, 1         ; CPU is too fast for VGA
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

                ; VGA is much slower than CPU, so for example between
                ; drawing multiple characters, CPU needs to wait until
                ; the drawing of the old character finished
WAIT_FOR_VGA    INCRB
                MOVE    VGA$STATE, R0
_WAIT_FOR_VGAL  MOVE    @R0, R1
                AND     VGA$BUSY, R1
                RBRA    _WAIT_FOR_VGAL, !Z
                DECRB
                RET

                ; switch off cursor and hw scrolling and clear screen
CLRSCR          INCRB
                MOVE    VGA$STATE, R0
                MOVE    0x0082, @R0             ; green, no cursor
                OR      VGA$CLR_SCRN, @R0
                RSUB    WAIT_FOR_VGA, 1
                DECRB
                RET
