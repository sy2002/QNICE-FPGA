;; VGA hardware scrolling test
;; assumes that some test-data is already on the screen and then performs:
;;   1. Scroll down by 10 lines
;;   2. Scroll up by 5 lines
;;   3. Reset back to normal
;; after each line, a key needs to be pressed on UART and the scroll offset
;; is displayed on TIL
;; done by sy2002 in January 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

VGA_EN_DISP_OFFS    .EQU    0x400
VGA_DISP_OFFS       .EQU    0xFF04

VGA_BYTES_PER_LINE  .EQU    80

RUNTIME             .EQU    15
MIRROR_DIR_AT       .EQU    5

                    .ORG    0x8000

                    MOVE    IO$TIL_DISPLAY, R7      ; TIL for debug out
                    MOVE    VGA_BYTES_PER_LINE, R4  ; positive = scroll fwd

                    ; setup VGA for scrolling
                    MOVE    VGA$STATE, R5           ; vga ctl and state reg
                    OR      VGA_EN_DISP_OFFS, @R5   ; enable hw scrolling                    
                    MOVE    VGA_DISP_OFFS, R6       ; vga display offs reg
                    MOVE    0, R1                   ; scroll offset
                    MOVE    R1, @R6                 ; init scroll offs reg

                    MOVE    RUNTIME, R0             ; # of lines to scroll

SCROLL_LOOP         MOVE    R1, @R7                 ; display current offset

                    CMP     MIRROR_DIR_AT, R0       ; mirror scroll direction?
                    RBRA    NO_MIRROR_YET, !Z

                    MOVE    0, R8
                    SUB     R4, R8                  ; negate the line offset
                    MOVE    R8, R4

NO_MIRROR_YET       RSUB    WAIT_KEY, 1             ; wait for a keypress

                    ADD     R4, R1                  ; offset for next line
                    MOVE    R1, @R6                 ; scroll to offset

                    SUB     1, R0                   ; one less line to scroll
                    RBRA    SCROLL_LOOP, !Z         ; loop if not done

                    MOVE    R1, @R7
                    RSUB    WAIT_KEY, 1

                    ; switch off hw scrolling (resets viewport)
                    ;NOT     VGA_EN_DISP_OFFS, R3
                    ;AND     R3, @R5

                    ; end of this program => back to monitor
                    SYSCALL(exit, 1)

; wait for a keypress on uart
WAIT_KEY        INCRB                        ; next register bank
                MOVE    IO$UART_SRA, R0
                MOVE    IO$UART_RHRA, R1  

WAIT_FOR_CHAR   MOVE    @R0, R2
                AND     0x0001, R2
                RBRA    WAIT_FOR_CHAR, Z
                MOVE    @R1, R3

                DECRB                        ; previous register bank
                RET
