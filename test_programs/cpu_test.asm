                ;
                ; cpu_test.asm
                ;
                ;  This is a comprehensive test suite for all combinations of instructions and addressing modes
                ; of QNICE. The first tests make sure that basic functionality is there - if problems show up 
                ; during this stage the test program will halt the processor. The halt address corresponds to
                ; the failing test.
                ;
                ; 05-MAY-2016   Bernd Ulmann
                ;
#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"
                ;
                .ORG    0x8000
                ;
                ; MOVE and CMP
                ;
                MOVE    0x1234, R0
                CMP     0x1234, R0
                RBRA    M1, Z
                ; Moving a constant to a register or comparing that with a constant failed.
                HALT
M1              CMP     R0, 0x1234
                RBRA    M1_1, Z
                ; CMP with constant as second parameter failed.
                HALT
M1_1            MOVE    R0, R1
                CMP     R1, 0x1234
                RBRA    M2, Z
                ; Moving the contents of a register to another register failed.
                HALT
M2              MOVE    M2_SCRATCH, R1
                MOVE    R0, @R1
                CMP     0x1234, @R1
                RBRA    M3, Z
                ; Either writing indirect to memory or reading this in a compare failed.
                HALT
M2_SCRATCH      .BLOCK  2               ; Two scratch memory cells.
M3              MOVE    @R1++, @R1++
                MOVE    M2_SCRATCH, R2
                ADD     0x0002, R2
                CMP     R2, R1
                RBRA    M3_1, Z         ; R1 points to the correct address.
                HALT
M3_1            SUB     0x0001, R1
                MOVE    @R1, R2
                CMP     R0, R2
                RBRA    M4, Z
                ;  If we end up here, the second memory cell in M2_SCRATCH did either not contain
                ; 0x1234 or the value could not be retrieved.
                HALT
                ;  Now we test ADD @R0++, @R0:
M4              MOVE    M2_SCRATCH, R0
                MOVE    0x5555, @R0++
                MOVE    0xAAAA, @R0
                SUB     0x0001, R0
                OR      @R0++, @R0
                CMP     0xFFFF, @R0
                RBRA    M5, Z
                HALT
M5
                ; If we end up here we can be pretty sure that the CPU is working.
                SYSCALL(exit, 1)
