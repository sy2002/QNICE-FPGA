;; VGA clear screen test
;; done by sy2002 in December 2015

QMON$MAIN_LOOP      .EQU    0x000C
IO$TIL_BASE         .EQU    0xFF10
IO$UART_STATUS      .EQU    0xFF21
IO$UART_RX          .EQU    0xFF22
NEXT_BANK           .EQU    0x0100

VGA_CTL             .EQU    0xFF00
VGA_CX              .EQU    0xFF01
VGA_CY              .EQU    0xFF02

                    .ORG    0x8000

                    MOVE    IO$TIL_BASE, R7
                    MOVE    VGA_CTL, R1
                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1 

                    MOVE    VGA_CX, R0
                    MOVE    1, @R0
                    MOVE    @R0, R2
                    MOVE    VGA_CY, R0
                    MOVE    1, @R0
                    MOVE    @R0, R3

                    SHL     8, R2
                    OR      R3, R2
                    MOVE    R2, @R7
                    RSUB    WAIT_KEY, 1

                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1

                    MOVE    0x01E1, @R1
                    MOVE    @R1, @R7
                    RSUB    WAIT_KEY, 1

                    ABRA    QMON$MAIN_LOOP, 1

; wait for a keypress on uart
WAIT_KEY        ADD     NEXT_BANK, R14      ; next register bank
                MOVE    IO$UART_STATUS, R0
                MOVE    IO$UART_RX, R1  

WAIT_FOR_CHAR   MOVE    @R0, R2
                AND     0x0001, R2
                RBRA    WAIT_FOR_CHAR, Z
                MOVE    @R1, R3

                SUB     NEXT_BANK, R14      ; previous register bank
                MOVE    @R13++, R15         ; return from sub routine
