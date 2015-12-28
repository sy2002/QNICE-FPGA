                .ORG    0x8000
;
#undef          FPGA
#define         POINTER R12
;
#include "../monitor/sysdef.asm"
                MOVE    IO$BASE, SP
;
DIVERGENT       .EQU    0x0400              ; Constant for divergence test
X_START         .EQU    -0x0200             ; -512 = - 2 * scale with scale = 256
X_END           .EQU    0x0100              ; +128
X_STEP          .EQU    0x0006              ; 10
Y_START         .EQU    -0x0180             ; -256
Y_END           .EQU    0x0180              ; 256
Y_STEP          .EQU    0x000F              ; 25
ITERATION       .EQU    0x001A              ; Number of iterations
;
; for (y = y_start; y <= y_end; y += y_step)
; {
                MOVE    Y_START, R0         ; R0 = y
OUTER_LOOP      CMP     Y_END, R0           ; End reached?
                RBRA    MANDEL_END, !N      ; Yes
;   for (x = x_start; x <= x_end; x += x_step)
;   {
                MOVE    X_START, R1         ; R1 = x
INNER_LOOP      CMP     X_END, R1           ; End reached?
                RBRA    INNER_LOOP_END, !N  ; Yes
;     z0 = z1 = 0;
                XOR     R2, R2
                XOR     R3, R3
;     for (i = i_max; i; i--)
;     {
                MOVE    ITERATION, R6       ; i = i_max
;;;
ITERATION_LOOP  MOVE R3, R8                 ; Computer z1 ** 2 for z2 = (z0 * z0 - z1 * z1) / 256
                MOVE R3, R9
                RSUB MTH$MUL, 1
;
                MOVE    Z1SQUARE_LOW, POINTER
                MOVE    R10, @POINTER       ; Remember the result for later
                MOVE    Z1SQUARE_HIGH, POINTER
                MOVE    R11, @POINTER
;
                MOVE    R2, R8              ; Compute z0 * z0
                MOVE    R2, R9
                RSUB    MTH$MUL, 1
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
                RSUB    MTH$MUL, 1          ; R11|R10 = 2 * R2 * R3
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
                RBRA    BREAK, !N           ; The sequence is diverging
;;;
                SUB     1, R6               ; i--
                RBRA    ITERATION_LOOP, !Z
;     }
;     printf("%c", display[iteration % 7]);
BREAK           MOVE    DISPLAY, R7
                AND     0x0007, R6
                ADD     R6, R7
                MOVE    @R7, R8
                RSUB    IO$PUTCHAR, 1
                ADD     X_STEP, R1          ; x += x_step
                RBRA    INNER_LOOP, 1
;   }
;   printf("\n");
INNER_LOOP_END  RSUB    IO$PUT_CRLF, 1
                ADD     Y_STEP, R0
                RBRA    OUTER_LOOP, 1
; }
MANDEL_END      RSUB    IO$PUT_CRLF, 1


                HALT
DISPLAY         .ASCII_P    " .-+*=#*"      ; Characters for the display
Z0SQUARE_LOW    .BLOCK      1
Z0SQUARE_HIGH   .BLOCK      1
Z1SQUARE_LOW    .BLOCK      1
Z1SQUARE_HIGH   .BLOCK      1
;
;
#include "../monitor/io_library.asm"
#include "../monitor/string_library.asm"
#include "../monitor/math_library.asm"
;
QMON$WARMSTART  HALT                        ; Dummy
