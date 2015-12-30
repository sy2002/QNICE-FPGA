#include "../monitor/sysdef.asm"

            .ORG    0x8000
            MOVE    0x0100, R4
START       MOVE    0x0041, R8          ; Print an "A"
            RSUB    PRINT, 1
            MOVE    0x0042, R8          ; Prepare for a "B"
            XOR     R0, R0              ; Z is NOT set
            AND     0x0001, R0
            RBRA    L1, Z               ; , so this does not take place
L1          RSUB    PRINT, 1
            MOVE    0x0043, R8          ; ...now, a "C"
            RSUB    PRINT, 1
            SUB     0x0001, R4
            RBRA    START, !Z
            ABRA    0x0000, 1

PRINT       INCRB
            MOVE    IO$UART_SRA, R0
            MOVE    IO$UART_THRA, R1
_PRINT_W    MOVE    @R0, R2
            AND     0x0002, R2
            RBRA _PRINT_W, Z
            MOVE    R8, @R1
            DECRB
            RET
