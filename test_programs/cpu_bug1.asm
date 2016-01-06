; rsub-after-rbra cpu bug (?) testbed
; done by sy2002 in January 2016

#define SIMULATOR

#ifdef SIMULATOR

#define RET     MOVE    @R13++, R15
#define INCRB   ADD     0x0100, R14
#define DECRB   SUB     0x0100, R14

#define PC  R15
#define SR  R14
#define SP  R13

#else

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG        0x8000
#endif

.ORG        0x8000

#ifdef SIMULATOR
                AND         0x00FF, SR
                MOVE        0x8010, SP
#endif

                MOVE        0xFF10, R10
                MOVE        0x0020, R11

                MOVE        0xAAAA, @R10
#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
#endif                

TST_LOOP        MOVE        R11, @R10
#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
#endif                
                RSUB        TESTBED, 1
                SUB         1, R11
                RBRA        TST_LOOP, !Z

                MOVE        0xFFFF, @R10

#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
                ABRA        QMON$MAIN_LOOP, 1
#endif 

ABRA        0x0012, 1


TESTBED         INCRB
                MOVE        0x000A, @R10
#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
                MOVE        0x000B, @R10
                RSUB        WAIT_KEY, 1
#endif        

                MOVE        0, R0
                MOVE        R0, R1
                AND         0x001, R1
                RBRA        CONT, Z

                RSUB        TEST_1, 1           ; this is exactly the...
                RBRA        END, 1              ; ...pattern as it is seen...

CONT            RSUB        TEST_2, 1           ; ...io_library.asm
END             DECRB
                RET 

TEST_1          INCRB
                MOVE        0x0001, @R10
#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
#endif                
                XOR         R1, R1
                DECRB
                RET

TEST_2          INCRB
                MOVE        0x0002, @R10
#ifndef SIMULATOR
                RSUB        WAIT_KEY, 1
#endif                
                XOR         R2, R2
                DECRB
                RET

#ifndef SIMULATOR
; wait for a keypress on uart
WAIT_KEY        INCRB                        ; next register bank
                MOVE    IO$UART_SRA, R0
                MOVE    IO$UART_RHRA, R1  

WAIT_FOR_CHAR   MOVE    @R0, R2
                AND     0x0001, R2
                RBRA    WAIT_FOR_CHAR, Z
                MOVE    @R1, R3

                DECRB                        ; previous register bank
                RET
#endif
