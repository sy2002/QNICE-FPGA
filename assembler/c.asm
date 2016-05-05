        .ORG    0x8000
        BLA     R5, R6
        CMPU    R0, R1
        CMPU    0x0100, R0
        CMPU    R0, 0x0100
        CMPU    0x0100, 0x0200
        CMPS    R0, R1
        CMPS    0x0100, R0
        CMPS    R0, 0x0100
        CMPS    0x0100, 0x0200
        HALT
