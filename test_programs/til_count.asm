;; This is the very first "real" QNICE-FPGA test program which is and was used during the
;; initial development of QNICE-FPGA by sy2002.
;;
;; It is based on vaxman's original test program "til_count.asm" that displays
;; a count on the TIL-311 display on the original QNICE/A evaluation board.

IO$TIL_BASE     .EQU    0xFF10                  ; Address of TIL-display
WAIT_CYCLES     .EQU    0x0010                  ; Number of wait iterations to be done for a slowly incrementing display
;;
                .ORG    0x0000                  ; Start address
                MOVE    0x0000, R0              ; Clear R0
                MOVE    IO$TIL_BASE, R1         ; Base address of TIL-display for output
LOOP            MOVE    R0, @R1                 ; Write contents of R0 to the TIL-display
                MOVE    WAIT_CYCLES, R2
WAIT_LOOP       SUB     1, R2                   ; Decrement loop counter
                RBRA    WAIT_LOOP, !Z           ; If not zero, perform next loop
                ADD     1, R0                   ; Increment R0
                RBRA    LOOP, !Z                ; Unconditional jump to display the next value
                HALT
