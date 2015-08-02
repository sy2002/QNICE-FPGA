; tests RAM, stack and the sub routine calls ASUB and RSUB
; expects RAM to start at $8000, so works for example in environment "env1"
; done by sy2002 on August, 1st 2015

        MOVE 0x8000, R0
        MOVE 0x5DA8, @R0++
        MOVE 0x1000, @R0++
        MOVE 0x0100, @R0++
        MOVE 0x0010, @R0++
        MOVE 0x0001, @R0++
        MOVE 0x1111, @R0++
        MOVE 0xFFFF, @R0++

        MOVE 0x8000, R0
        MOVE 0x8010, R1
        MOVE 0x0007, R2
        MOVE 0x0001, R3

COPY    MOVE @R0++, @R1++
        SUB R3, R2
        RBRA COPY, !Z

HALT
