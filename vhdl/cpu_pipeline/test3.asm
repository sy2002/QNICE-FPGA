ABRA  R1, !1
MOVE  R15, R2     ; Should move 0x0002 into R2
ABRA  R3, !1
MOVE  R15, R4     ; Should move 0x0004 into R4
ABRA  R5, !1
ABRA  R6, !1
MOVE  R0, R1      ; Performs a register write in stage 4
MOVE  @R2++, R3   ; Should move 0xF308 into R3, and increment R2 to 0x0003.
MOVE  @R4++, R5   ; Should move 0xF508 into R5, and increment R4 to 0x0005.
HALT

