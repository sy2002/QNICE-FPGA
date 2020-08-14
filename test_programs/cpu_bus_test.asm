// CPU bus test

// CMP reads from both operands
// NOT reads from first operand and writes to second operand
// ADD reads from both operands and writes to second operand

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000

                MOVE    0xFF84, R4              // Reads from 0xFF80
                MOVE    0xFF85, R5              // Reads from 0xFF81
                MOVE    0xFF86, R6              // Writes to 0xFF80
                MOVE    0xFF87, R7              // Writes to 0xFF81

                MOVE    STIM_START, R8

LOOP            MOVE    OPCODE, R9              // Store instruction to execute
                MOVE    @R8++, @R9

                MOVE    0, @R4                  // Reset counters
                MOVE    0, @R5
                MOVE    0, @R6
                MOVE    0, @R7

                MOVE    0xFF80, R0              // Setup registers
                MOVE    0xFF81, R1
                MOVE    0xFF81, R2
                MOVE    0xFF82, R3

OPCODE          MOVE    R0, R0                  // Perform instruction (one word)

                MOVE    @R4, R9                 // Read counters
                MOVE    @R5, R10
                MOVE    @R6, R11
                MOVE    @R7, R12

                CMP     @R8++, R9
                RBRA    ERR_0, !Z
                CMP     @R8++, R10
                RBRA    ERR_1, !Z
                CMP     @R8++, R11
                RBRA    ERR_2, !Z
                CMP     @R8++, R12
                RBRA    ERR_3, !Z

                CMP     R8, STIM_END
                RBRA    LOOP, !Z

                RBRA    EXIT, 1

ERR_0           HALT
ERR_1           HALT
ERR_2           HALT
ERR_3           HALT

STIM_START      CMP     R0, @R2
                .DW     0x0000, 0x0001, 0x0000, 0x0000
                CMP     R0, @R2++
                .DW     0x0000, 0x0001, 0x0000, 0x0000
                CMP     R0, @--R3
                .DW     0x0000, 0x0001, 0x0000, 0x0000
                CMP     @R0, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                CMP     @R0, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @R0, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @R0, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @R0++, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                CMP     @R0++, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @R0++, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @R0++, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @--R1, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                CMP     @--R1, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @--R1, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0000
                CMP     @--R1, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0000

                NOT     R0, @R2
                .DW     0x0000, 0x0000, 0x0000, 0x0001
                NOT     R0, @R2++
                .DW     0x0000, 0x0000, 0x0000, 0x0001
                NOT     R0, @--R3
                .DW     0x0000, 0x0000, 0x0000, 0x0001
                NOT     @R0, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                NOT     @R0, @R2
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @R0, @R2++
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @R0, @--R3
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @R0++, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                NOT     @R0++, @R2
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @R0++, @R2++
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @R0++, @--R3
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @--R1, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                NOT     @--R1, @R2
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @--R1, @R2++
                .DW     0x0001, 0x0000, 0x0000, 0x0001
                NOT     @--R1, @--R3
                .DW     0x0001, 0x0000, 0x0000, 0x0001

                ADD     R0, @R2
                .DW     0x0000, 0x0001, 0x0000, 0x0001
                ADD     R0, @R2++
                .DW     0x0000, 0x0001, 0x0000, 0x0001
                ADD     R0, @--R3
                .DW     0x0000, 0x0001, 0x0000, 0x0001
                ADD     @R0, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                ADD     @R0, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @R0, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @R0, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @R0++, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                ADD     @R0++, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @R0++, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @R0++, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @--R1, R2
                .DW     0x0001, 0x0000, 0x0000, 0x0000
                ADD     @--R1, @R2
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @--R1, @R2++
                .DW     0x0001, 0x0001, 0x0000, 0x0001
                ADD     @--R1, @--R3
                .DW     0x0001, 0x0001, 0x0000, 0x0001

STIM_END


// Everything worked as expected! We are done now.
EXIT            MOVE    OK, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

OK              .ASCII_W    "OK\n"

