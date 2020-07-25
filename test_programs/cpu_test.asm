                ;
                ; cpu_test.asm
                ;
                ;  This is a comprehensive test suite for all combinations of instructions and addressing modes
                ; of QNICE. The first tests make sure that basic functionality is there - if problems show up 
                ; during this stage the test program will halt the processor. The halt address corresponds to
                ; the failing test.
                ;
                ; Turn on switch SW2 to put QNICE-FPGA into debugging mode, i.e. the TIL register will show
                ; the address where the HALT occured.
                ;
                ; 05-MAY-2016   Bernd Ulmann
                ; 30-DEC-2016   sy2002: Added these testcases: ADD R4, @--R4; ADD @--R4, R4;
                ;                                              ADD @--R4, @R4; ADD @R4, @--R4;
                ;                                              ADD @--R4, @--R4
                ; 25-JUL-2020   
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
                ;  Now we test OR @R0++, @R0:
M4              MOVE    M2_SCRATCH, R0
                MOVE    0x5555, @R0++
                MOVE    0xAAAA, @R0
                SUB     0x0001, R0
                OR      @R0++, @R0
                CMP     0xFFFF, @R0
                RBRA    M5, Z
                HALT
                ; test ADD R4, @--R4
M5_VAR          .DW     0x0004, 0xFFFF, 0x4444, 0x9876, 0x5432, 0x2309
M5              MOVE    M5_VAR, R4
                ADD     1, R4
                ADD     R4, @--R4
                MOVE    @R4, R4
                CMP     @R4, 0x2309
                RBRA    M6, Z
                HALT
                ; test ADD @--R4, R4
                ; for more details, see test_programs/predec.asm
M6_VAR          .DW 0x0003, 0xAAAA, 0xFFFF, 0xCCCC, 0xBBBB, 0xEEEE
M6              MOVE    M6_VAR, R4              ; now points to 0x0003 
                ADD     1, R4                   ; now points to 0xAAAA
                ADD     @--R4, R4               ; now should point to 0xCCCC
                CMP     0xCCCC, @R4
                RBRA    M7, Z
                HALT
                ; test ADD @--R4, @R4
M7_VAR         .DW     0xAAAA, 0x1234, 0xBBBB
M7              MOVE    M7_VAR, R4
                ADD     2, R4
                ADD     @--R4, @R4
                CMP     @R4, 0x2468
                RBRA    M8, Z
                HALT
                ; test ADD @--R4, @--R4
M8_VAR          .DW     0x5555, 0x0076, 0x1900, 0xDDDD, 0x9999, 0x8888
M8              MOVE    M8_VAR, R4
                ADD     3, R4
                ADD     @--R4, @--R4
                CMP     @R4, 0x1976
                RBRA    M9, Z
                HALT
                ; ADD @R4, @--R4
M9_VAR          .DW     0x1100, 0x4455
M9              MOVE    M9_VAR, R4
                ADD     1, R4
                ADD     @R4, @--R4
                CMP     @R4, 0x5555
                RBRA    CPU_OK, Z
                HALT

                ; If we end up here we can be pretty sure that the CPU is working.
CPU_OK          SYSCALL(exit, 1)
