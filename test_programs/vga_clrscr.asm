;; VGA clear screen test
;; done by sy2002 in December 2015

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                    .ORG    0x8000

                    MOVE    IO$TIL_DISPLAY, R7
                    MOVE    VGA$STATE, R1
                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1 

                    MOVE    VGA$CR_X, R0
                    MOVE    1, @R0
                    MOVE    @R0, R2
                    MOVE    VGA$CR_Y, R0
                    MOVE    1, @R0
                    MOVE    @R0, R3

                    AND     0xFFFD, SR              ; clear X (shift in '0')
                    SHL     8, R2
                    OR      R3, R2
                    MOVE    R2, @R7     
                    RSUB    WAIT_KEY, 1

                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1

                    ; execute the clear screen command and in parallel
                    ; switch the font color to blue
                    MOVE    0x01E1, @R1

                    ; As the execution of the clear screen takes a while,
                    ; you will read the busy bit (bit 9) and the clear
                    ; screen bit (bit 8) as '1' when reading the status
                    ; register directly after issuing the clear screen
                    ; command. Therefore, the value 3E1 should be shown
                    ; on the TIL.
                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1

                    ABRA    QMON$MAIN_LOOP, 1

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
