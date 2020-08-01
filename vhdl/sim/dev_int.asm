;  Development testbed for the simulation environment "dev_int.vhd"
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
;  The way how dev_int.vhd wires the interrupt_generator (dev_int_source),
;  the expected memory layout is:
;  1, 2, 3, CCCC, CCCC, 4, 5, DD00, DD01, DD02, DD03, DD03, DD04, 6, 7
;
;  done by vaxman and sy2002 in July/August 2020

#include "../../dist_kit/sysdef.asm"

        .ORG    0x0000

        ; register test of the timer interrupt device
        MOVE    IO$TIMER_0_PRE, R0
        MOVE    IO$TIMER_0_CNT, R1
        MOVE    IO$TIMER_0_INT, R2
        MOVE    IO$TIMER_1_PRE, R3
        MOVE    IO$TIMER_1_CNT, R4
        MOVE    IO$TIMER_1_INT, R5

        MOVE    0xFFFF, @R0
        MOVE    0xEEEE, @R1
        MOVE    0xDDDD, @R2
        MOVE    0xCCCC, @R3
        MOVE    0xBBBB, @R4
        MOVE    0xAAAA, @R5

        CMP     0xDDDD, @R2
        RBRA    A_HALT, !Z
        MOVE    0x0000, @R2
        CMP     0xAAAA, @R5
        RBRA    A_HALT, !Z
        MOVE    0x0000, @R5
        CMP     0xFFFF, @R0
        RBRA    A_HALT, !Z
        CMP     0xEEEE, @R1
        RBRA    A_HALT, !Z
        CMP     0xCCCC, @R3
        RBRA    A_HALT, !Z
        CMP     0xBBBB, @R4
        RBRA    A_HALT, !Z

        ; hardware interrupts
        MOVE    DATA, R12
        MOVE    1, @R12++
        MOVE    2, @R12++
        MOVE    3, @R12++   ; expectation: hardware interrupt here and another
        MOVE    4, @R12++   ; hw int that interrupts the first hw int
        MOVE    5, @R12++

        ; since we are running in a simulation, that uses this code in ROM,
        ; we need to fill the values in the 0x8000+ range, that we need to be
        ; nonzero for the test so we move the same values there, that "should"
        ; be already there due to the .dw command
        MOVE    A_RIND, R8
        MOVE    I_RIND, @R8++
        MOVE    I_RIPD, @R8++
        MOVE    I_RIPI, @R8

        ; software interrupts
        INT     I_ABS       ; test direct ISR address

        MOVE    I_REG, R8   ; test ISR via register
        INT     R8

        MOVE    A_RIND, R8  ; test ISR via register indirect
        INT     @R8

        MOVE    A_RIPD1, R8 ; test ISR via register indirect with predecrement
        INT     @--R8

        INT     @R8++       ; test if register postinc works
        INT     @R8

        MOVE    6, @R12++
        MOVE    7, @R12++
A_HALT  HALT

        ; HARDWARE INTERRUPT ISR
        ; Start of ISR: Look at the .lis file to find out where it is
        ; Currently it should be: 0x0026 <=needs to be edited in "dev_int.vhd"
        MOVE    0xCCCC, @R12++
        RTI

        ; SOFTWARE INTERRUPT ISRs
        ; Absolute ISR
I_ABS   MOVE    0xDD00, @R12++
        RTI
        ; Register ISR
I_REG   MOVE    0xDD01, @R12++
        RTI
I_RIND  ; Register indirect ISR
        MOVE    0xDD02, @R12++
        RTI
I_RIPD  ; Register indirect predec ISR
        MOVE    0xDD03, @R12++
        RTI
I_RIPI  ; Register indirect postinc ISR
        MOVE    0xDD04, @R12++
        RTI


        .ORG    0x8000

DATA    .DW     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

A_RIND  .DW     I_RIND
A_RIPD0 .DW     I_RIPD    
A_RIPD1 .DW     I_RIPI
