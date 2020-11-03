.DW   0x0100      ; This is just some dummy words, since PC currently starts at 0x0010
.DW   0x0101
.DW   0x0102
.DW   0x0103
.DW   0x0104
.DW   0x0105
.DW   0x0106
.DW   0x0107
.DW   0x0108
.DW   0x0109
.DW   0x010A
.DW   0x010B
.DW   0x010C
.DW   0x010D
.DW   0x010E
.DW   0x010F
MOVE  R15, R0     ; Should put 0x0011 into R0
MOVE  R15, R1     ; Should put 0x0012 into R1
MOVE  R15, R2     ; Should put 0x0013 into R2
MOVE  R15, R3     ; Should put 0x0014 into R3
MOVE  @R0, R4     ; Should put 0x0F04 into R4
MOVE  R15, R5     ; Should put 0x0016 into R5
MOVE  R15, R6     ; Should put 0x0017 into R6
MOVE  R15, R7     ; Should put 0x0018 into R7
MOVE  R15, R8     ; Should put 0x0019 into R9
