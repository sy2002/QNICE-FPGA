; tests RAM, stack and the sub routine calls ASUB and RSUB
; expects RAM to start at $8000, so works for example in environment "env1"
; done by sy2002 on August, 2nd 2015

        MOVE 0x8020, R13        ; setup stack pointer

        MOVE 0x8000, R8         ; source memory area
        MOVE 0x800A, R9         ; destination memory area
        RSUB MEMFILL, 1

        MOVE 0x1111, R0
        MOVE 0x2222, R1
        MOVE 0x3333, R2

        MOVE 0x8020, R8
        MOVE 0x802A, R9
        RSUB MEMFILL, 1

        MOVE 0x4444, R3
        MOVE 0x5555, R4
        MOVE 0x6666, R5

        HALT


MEMFILL ADD 0x0100, R14         ; save register bank 

        ;fill some data beginning at R8
        MOVE R8, R0
        MOVE 0x5DA8, @R0++
        MOVE 0x1000, @R0++
        MOVE 0x0100, @R0++
        MOVE 0x0010, @R0++
        MOVE 0x0001, @R0++
        MOVE 0x1111, @R0++
        MOVE 0xFFFF, @R0++

        ; copy the data from R8 to R9
        MOVE R8, R0
        MOVE R9, R1
        MOVE 0x0007, R2
        MOVE 0x0001, R3

COPY    MOVE @R0++, @R1++
        SUB R3, R2
        RBRA COPY, !Z

        SUB 0x0100, R14        ; restore register bank
        MOVE @R13++, R15       ; return from sub routine

