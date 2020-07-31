;; This is the very first "real" QNICE-FPGA test program which is and was used during the
;; initial development of QNICE-FPGA by sy2002 in July 2015.
;;
;; It is inspired by vaxman's original test program "til_count.asm" that displays
;; a count on the TIL-311 display on the original QNICE/A evaluation board.

#include "../dist_kit/sysdef.h"

FLAG_C_SET      .EQU    0x0004                  ; bit pattern for setting the carry flag with OR
FLAG_C_CLEAR    .EQU    0xFFFB                  ; bit pattern for clearing the carry flag with AND

; QNICE-FPGA in the current early stage of development is running at about 20 MIPS. As the
; inner loop consists of two instructions, we need to count to about 10.000.000 for having
; the effect of an ~1 Hz incrementing counter on the TIL.
; So we choose WAIT_CYCLES1 as 5.000 equ 0x1388 and WAIT_CYCLES2 as 2.000 equ 0x07D0
WAIT_CYCLES1    .EQU    0x1388
WAIT_CYCLES2    .EQU    0x07D0

                .ORG    0x8000                  ; Start address
                MOVE    0x0000, R0              ; Clear R0
                MOVE    IO_TIL_DISPLAY, R1      ; Base address of TIL-display for output
                MOVE    IO_TIL_MASK, R9         ; Mask register of TIL-display for selecting which TIL is lit

                ; Write contents of R0 to the TIL-display
LOOP            MOVE    R0, @R1                 

                ; Create mask for TIL digits, so that only those TILs are lit, that are displaying non zero digits
                MOVE    0x000F, R4              ; R4 is the resulting mask; at first, we assume all four digits are lit
                MOVE    0xF000, R5              ; R5 is the bit parttern to check, if a certain digit shall be lit
                MOVE    0x0003, R7              ; R7 is the loop counter

CREATE_MASK     MOVE    R5, R6                  ; use the pattern and ...
                AND     R0, R6                  ; ... check if one of the bits is set at the digit position implied the mask
                RBRA    MASK_READY, !Z          ; if bits are set, then mask is ready
                AND     FLAG_C_CLEAR, R14       ; clear C because SHR fills with C (not necessarry, because C is never set before)
                SHR     1, R4                   ; make the mask smaller by one bit
                SHR     4, R5                   ; move the "scanner pattern" to the next digit (i.e. 4 bits)
                SUB     1, R7                   ; reduce counter (counter necessary to avoid endless loop in case of R0 == 0)
                RBRA    CREATE_MASK, !Z         ; next iteration

                ; Set mask register of TIL-display
MASK_READY      MOVE    R4, @R9

                ; waste cycles to approximate a 1 Hz execution
                MOVE    WAIT_CYCLES2, R3
WAIT_LOOP2      MOVE    WAIT_CYCLES1, R2
WAIT_LOOP1      SUB     1, R2                   ; Decrement loop counter
                RBRA    WAIT_LOOP1, !Z          ; If not zero, perform next loop
                SUB     1, R3
                RBRA    WAIT_LOOP2, !Z

                ADD     1, R0                   ; Increment R0
                RBRA    LOOP, !Z                ; Unconditional jump to display the next value

                HALT                            ; stop the CPU
                                                ; this whitespace line is currently necessary due to a QNICE assembler bug
