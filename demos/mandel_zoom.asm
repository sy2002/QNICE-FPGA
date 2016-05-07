;*******************************************************************************
;*
;*  This program generates a set of Mandelbrot-set-pictures. Starting with 
;* an initial set of parameters (X- and Y-boundaries and -stepsizes) it is 
;* possible to translate the display and to zoom into or out of the initial
;* display.
;*
;* 07-MAY-2016  Bernd Ulmann
;*
;*******************************************************************************
;
                .ORG    0x8000
;
#define         POINTER R12
;
#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"
;
DIVERGENT       .EQU    0x0400              ; Constant for divergence test
ITERATION       .EQU    0x001A              ; Number of iterations
;
;*******************************************************************************
;*
;*  Main program - display a Mandelbrot-set and then wait for a key to be
;* pressed to control translation and zoom operations.
;*
;*******************************************************************************
;
                MOVE    WELCOME, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
_MAIN_LOOP      SYSCALL(cls, 1)
                RSUB    MANDEL, 1           ; Generate one Mandelbrot-set
;
                MOVE    X_STEP, R7
                MOVE    @R7, R0             ; R0 now contains X_STEP
                MOVE    X_START, R7
                MOVE    @R7, R1             ; R1 contains X_START
                MOVE    X_END, R7
                MOVE    @R7, R2             ; R2 contains X_END
                MOVE    Y_STEP, R7
                MOVE    @R7, R3             ; R3 contains Y_STEP
                MOVE    Y_START, R7
                MOVE    @R7, R4             ; R4 contains Y_START
                MOVE    Y_END, R7
                MOVE    @R7, R5             ; R5 contains Y_END
;
                MOVE    R0, R9              ; This is the step size to be
                SHL     2, R9               ; used in horizontal shifts,
                MOVE    R3, R10             ; while this one is used in
                SHL     2, R10              ; vertical shifts
;
_MAIN_GET_KEY   SYSCALL(getc, 1)            ; Wait for a key to be pressed
                CMP     'l', R8
                RBRA    _MAIN_NOT_L, !Z
                SUB     R9, R1              ; "l" has been pressed
                SUB     R9, R2
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_L     CMP     'r', R8
                RBRA    _MAIN_NOT_R, !Z
                ADD     R9, R1              ; "r" has been pressed
                ADD     R9, R2
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_R     CMP     'u', R8
                RBRA    _MAIN_NOT_U, !Z
                SUB     R10, R4              ; "u" has been pressed
                SUB     R10, R5
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_U     CMP     'd', R8
                RBRA    _MAIN_NOT_D, !Z
                ADD     R10, R4              ; "d" has been pressed
                ADD     R10, R5
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_D     CMP     'i', R8
                RBRA    _MAIN_NOT_I, !Z
                SUB     0x0001, R0          ; "i" has been pressed
                SUB     0x0001, R3
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_I     CMP     'o', R8
                RBRA    _MAIN_NOT_O, !Z
                ADD     0x0001, R0          ; "o" has been pressed
                ADD     0x0001, R3
                RBRA    _MAIN_NEXT, 1
_MAIN_NOT_O     CMP     'x', R8
                RBRA    _MAIN_NOT_X, !Z
                SYSCALL(exit, 1)            ! "x" has been pressed, exit
_MAIN_NOT_X     MOVE    CHR$BELL, R8
                SYSCALL(putc, 1)
                RBRA    _MAIN_GET_KEY, 1
_MAIN_NEXT      MOVE    X_STEP, R7          ! Write back parameters for next loop
                MOVE    R0, @R7
                MOVE    X_START, R7
                MOVE    R1, @R7
                MOVE    X_END, R7
                MOVE    R2, @R7
                MOVE    Y_STEP, R7
                MOVE    R3, @R7
                MOVE    Y_START, R7
                MOVE    R4, @R7
                MOVE    Y_END, R7
                MOVE    R5, @R7
;
                RBRA    _MAIN_LOOP, 1
;
;*******************************************************************************
;*
;*  Generate a Mandelbrot-set display - boundaries and step-sizes are expected
;* in memory cells X_START, X_END, X_STEP, Y_START, Y_END, and Y_STEP.
;*
;*******************************************************************************
;
MANDEL          INCRB
;
; for (y = y_start; y <= y_end; y += y_step)
; {
                MOVE    Y_START, R8
                MOVE    @R8, R0             ; R0 = y
OUTER_LOOP      MOVE    Y_END, R8
                CMP     @R8, R0             ; End reached?
                RBRA    MANDEL_END, !V      ; Yes
;   for (x = x_start; x <= x_end; x += x_step)
;   {
                MOVE    X_START, R8
                MOVE    @R8, R1             ; R1 = x
INNER_LOOP      MOVE    X_END, R8
                CMP     @R8, R1             ; End reached?
                RBRA    INNER_LOOP_END, !V  ; Yes
;     z0 = z1 = 0;
                XOR     R2, R2
                XOR     R3, R3
;     for (i = i_max; i; i--)
;     {
                MOVE    ITERATION, R6       ; i = i_max
;;;
ITERATION_LOOP  MOVE R3, R8                 ; Compute z1 ** 2 for z2 = (z0 * z0 - z1 * z1) / 256
                MOVE R3, R9
                SYSCALL(muls, 1)
;
                MOVE    Z1SQUARE_LOW, POINTER
                MOVE    R10, @POINTER       ; Remember the result for later
                MOVE    Z1SQUARE_HIGH, POINTER
                MOVE    R11, @POINTER
;
                MOVE    R2, R8              ; Compute z0 * z0
                MOVE    R2, R9
                SYSCALL(muls, 1)
;
                MOVE    Z0SQUARE_LOW, POINTER
                MOVE    R10, @POINTER       ; Remember the result for later
                MOVE    Z0SQUARE_HIGH, POINTER
                MOVE    R11, @POINTER
;
                MOVE    Z1SQUARE_LOW, POINTER
                MOVE    @POINTER, R8
                MOVE    Z1SQUARE_HIGH, POINTER
                MOVE    @POINTER, R9
                SUB     R8, R10             ; First step of subtraction
                SUBC    R9, R11 ; Subtract high word
; R11/R10 now contains z0 ** 2 - z1 ** 2, next step is division by 256:
                SWAP    R10, R10
                AND     0x00FF, R10
                SWAP    R11, R11
                AND     0xFF00, R11
                OR      R11, R10
                MOVE    R10, R4             ; R4 now contains z2
;       z3 = 2 * z0 * z1 / 256
                MOVE    R2, R8
                ADD     R2, R8              ; R8 = 2 * z0
                MOVE    R3, R9
                SYSCALL(muls, 1)          ; R11|R10 = 2 * R2 * R3
                SWAP    R10, R10
                AND     0x00FF, R10
                SWAP    R11, R11
                AND     0xFF00, R11
                OR      R11, R10
                MOVE    R10, R5             ; R5 now contains z3
;       z1 = z3 + y
                MOVE    R5, R3
                ADD     R0, R3
;       z0 = z2 + x
                MOVE    R4, R2
                ADD     R1, R2
;       if (z0 * z0 / 256 + z1 * z1 / 256 > DIVERGENT)
; Implemented as (z0 ** 2 + z1 ** 2) / 256
                MOVE    Z0SQUARE_LOW, POINTER
                MOVE    @POINTER, R8
                MOVE    Z0SQUARE_HIGH, POINTER
                MOVE    @POINTER, R9
                MOVE    Z1SQUARE_LOW, POINTER
                MOVE    @POINTER, R10
                MOVE    Z1SQUARE_HIGH, POINTER
                MOVE    @POINTER, R11
                ADD     R10, R8
                ADDC    R11, R9
                SWAP    R8, R8
                AND     0x00FF, R8
                SWAP    R9, R9
                AND     0xFF00, R9
                OR      R9, R8              ; R8 now contains the left side of the comparison
                CMP     DIVERGENT, R8
;         break;
                RBRA    BREAK, !V           ; The sequence is diverging
;;;
                SUB     1, R6               ; i--
                RBRA    ITERATION_LOOP, !Z
;     }
;     printf("%c", display[iteration % 7]);
BREAK           MOVE    DISPLAY, R7
                AND     0x0007, R6
                ADD     R6, R7
                MOVE    @R7, R8
                SYSCALL(putc, 1)
                MOVE    X_STEP, R8
                ADD     @R8, R1             ; x += x_step
                RBRA    INNER_LOOP, 1
;   }
;   printf("\n");
INNER_LOOP_END  SYSCALL(crlf, 1)
                MOVE    Y_STEP, R8
                ADD     @R8, R0
                RBRA    OUTER_LOOP, 1
; }
MANDEL_END      SYSCALL(crlf, 1)
                DECRB
                RET
;
DISPLAY         .ASCII_P    " .-+*=#*"      ; Characters for the display
;
Z0SQUARE_LOW    .BLOCK      1
Z0SQUARE_HIGH   .BLOCK      1
Z1SQUARE_LOW    .BLOCK      1
Z1SQUARE_HIGH   .BLOCK      1
;
X_START         .DW     -0x0200             ; -512 = - 2 * scale with scale = 256
X_END           .DW     0x0100              ; +128
X_STEP          .DW     0x000B
Y_START         .DW     -0x0180             ; -256
Y_END           .DW     0x0180              ; 256
Y_STEP          .DW     0x0013
;
WELCOME         .ASCII_P    " This program computes and displays a Mandelbrot-set on QNICE.\n"
                .ASCII_P    "Using the following keys it is possible to perform translation and\n"
                .ASCII_P    "zoom operations:\n\n"
                .ASCII_P    "   l: Shift to the left.\n"
                .ASCII_P    "   r: Shift to the right.\n"
                .ASCII_P    "   u: Shift up.\n"
                .ASCII_P    "   d: Shift down.\n"
                .ASCII_P    "   i: Zoom in.\n"
                .ASCII_P    "   o: Zoom out.\n"
                .ASCII_P    "   x: Exit.\n\n"
                .ASCII_W    "Now, press any key to continue...\n"
