; simple Block RAM test done by sy2002 in August 2015

IO$TIL_BASE     .EQU    0xFF10              ; address of TIL-display
RAM_VARIABLE    .EQU    0x8000              ; address of a variable in RAM

                MOVE IO$TIL_BASE, R12
                MOVE RAM_VARIABLE, R0

                MOVE 0x2300, @R0            ; write 0x2300 to BRAM's 0x8000
                ADD 0x0009, @R0             ; add 9 to BRAM's 0x8000
                MOVE @R0, @R12              ; display 0x2309 on the TIL

                HALT
