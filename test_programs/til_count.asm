;; This is the very first "real" QNICE-FPGA test program which is and was used during the
;; initial development of QNICE-FPGA by sy2002.
;;
;; It is inspired by vaxman's original test program "til_count.asm" that displays
;; a count on the TIL-311 display on the original QNICE/A evaluation board.

IO$TIL_BASE     .EQU    0xFF10                  ; Address of TIL-display

; QNICE-FPGA in the current early stage of development is running at about 20 MIPS. As the
; inner loop consists of two instructions, we need to count to about 10.000.000 for having
; the effect of an 1 Hz incrementing counter on the TIL.
; So we choose WAIT_CYCLES1 as 5.000 equ 0x1388 and WAIT_CYCLES2 as 2.000 equ 0x07D0
WAIT_CYCLES1    .EQU    0x1388
WAIT_CYCLES2    .EQU    0x07D0

                .ORG    0x0000                  ; Start address
                MOVE    0x0000, R0              ; Clear R0
                MOVE    IO$TIL_BASE, R1         ; Base address of TIL-display for output
LOOP            MOVE    R0, @R1                 ; Write contents of R0 to the TIL-display

                MOVE    WAIT_CYCLES2, R3
WAIT_LOOP2      MOVE    WAIT_CYCLES1, R2
WAIT_LOOP1      SUB     1, R2                   ; Decrement loop counter
                RBRA    WAIT_LOOP1, !Z           ; If not zero, perform next loop
                SUB     1, R3
                RBRA    WAIT_LOOP2, !Z

                ADD     1, R0                   ; Increment R0
                RBRA    LOOP, !Z                ; Unconditional jump to display the next value
                HALT