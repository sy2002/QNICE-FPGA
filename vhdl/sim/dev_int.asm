;
;  This is a simple test program for QNICE interrupts. The idea is as follows:
;
;   1) The program starts writing 1, 2, 3, ... into the data area pointed to
;      by DATA.
;   2) After some of these MOVEs, an interrupt will be requested which will
;      cause a jump to the ISR which writes CCCC to the DATA area.
;   3) The interrupt is finished with RTI which causes a jump back to the
;      next move which will then continue writing the ascending series of 
;      integers to the DATA area.
;
        .ORG    0x0000
        MOVE    DATA, R12
        MOVE    1, @R12++
        MOVE    2, @R12++
        MOVE    3, @R12++
        MOVE    4, @R12++
        MOVE    5, @R12++
        HALT

        ; Start of ISR: Look at the .lis file to find out where it is
        ; Currently it should be: 0x000D
        MOVE    0xCCCC, @R12++
        RTI

        .ORG     0x8000
DATA    .DW     0, 0, 0, 0, 0, 0, 0, 0
