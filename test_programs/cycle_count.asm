; tests the hardware clock cycle counter and is meant to
; run as rom within the simululator
; done by sy2002 in May 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x0000

                ; excecute some arbitrary MOVES to get the counter going
                MOVE    0x0023, R0
                MOVE    0x8000, R1
                MOVE    R0, @R1

                ; read the lower 16 bit of the counter into R3
                MOVE    IO$CYC_LO, R2
                MOVE    @R2, R3

                ; stop the counter
                MOVE    IO$CYC_STATE, R4
                MOVE    0, @R4
                MOVE    @R2, R5

                ; test if stop worked
                NOP
                NOP
                MOVE    @R2, R6             ; R5 must be equal to R6


                ; restart the counter
                MOVE    2, @R4

                ; test if the restart worked
                NOP
                NOP
                MOVE    @R2, R7             ; R7 must be higher than R6

                ; stop the counter again
                MOVE    0, @R4

                ; reset (and therefore automatically restart) the counter
                MOVE    1, @R4

                ; test if the reset and restart worked
                NOP
                NOP
                MOVE    @R2, R8             ; R8 must be lower than R7

                HALT
                