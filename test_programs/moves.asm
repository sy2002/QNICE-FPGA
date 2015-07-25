; MOVE and register unit tests including bank switching and some flag tests

; in both cases, R14 should be 0x0009, i.e. Z and 1 flag set
; as you cannot clear the status register
        MOVE 0x0000, R0             ; first try using a register to register operation, so lead R0 ...
        MOVE R0, R14             ; ... and store it to R14

        MOVE 1, R1               ; dummy operation to clear the Z flag, i.e. SR should be 1 right now

N32768  .EQU 0x8000              ; 2-complement of -32768 as the assembler is not supporting negatives
N2      .EQU 0xFFFE              ; 2-complement of -2

        MOVE 0xFFFF, R2          ; dummy operation to set the X flag and N flag, i.e. SR should be 0x13 right now
        MOVE N32768, R3          ; prepare overflow, N flag is set, SR should be 0x11 now
        MOVE N2, R4              ; second component for overflow, SR stays 0x11
        ADD R3, R4               ; R4 should be 0x7FFE now and the C and V flag should be set, i.e. SR should be 0x25

        MOVE 0x0000, R14         ; second try use a @R15++ operation, SR should be 9 afterwards


; check memory reading and register bank switching
        ABRA NEXT1, 1

BANK    .EQU 0x0100             ; this adds 1 to the upper 8 bit, i.e. can be used for bank switching 

DATA    .ASCII_W "ABC"

NEXT1   MOVE DATA, R10          ; upper register bank

        ADD BANK, R14           ; next register bank via @R15++ operation
        MOVE 1, R0
        MOVE 2, R1
        MOVE 3, R2              ; after this, (R0, R1, R2) must be (1, 2, 3) in bank #1

        MOVE BANK, R11          ; next register bank via register to register operation
        ADD R11, R14            ; after this, the current bank should be #2

        MOVE @R10++, R0
        MOVE @R10++, R1
        MOVE @R10++, R2
        SUB @--R10, R2          ; after this, (R0, R1, R2) must be (0x41, 0x42, 0x00) in bank #2

        ADD R11, R14
        MOVE 0x2309, R7
        MOVE R7, R6             ; R7 and R6 shall contain 0x2309 in bank #3
        
        MOVE 0, R1
        OR 4, R14               ; set carry, SR = 0x305
        ADDC 1, R1              ; R1 shall be 2, carry cleared afterwards therefore SR = 1

        SUB BANK, R14           ; switch bank to bank #2
        MOVE @R10, R2           ; after this (R0, R1, R2) must be (0x41, 0x42, 0x43)

        HALT
