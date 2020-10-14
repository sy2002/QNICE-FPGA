; Development testbed for the monitor calls shl32 and shr32
;
; done by MJoergen in October 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

#define ST______ 0x0001
#define ST_____X 0x0003
#define ST____C_ 0x0005
#define ST____CX 0x0007

L_SHL32_00      MOVE    STIM_SHL32, R11
L_SHL32_01      MOVE    0x89AB, R8
                MOVE    0x4567, R9
                MOVE    @R11++, R10
                RBRA    L_SHL32_02, N
                MOVE    @R11++, R14
                SYSCALL(shl32, 1)
                MOVE    @R11++, R0
                MOVE    @R11++, R1
                MOVE    @R11++, R2

                MOVE    R14, R3
                AND     ST____C_, R3
                CMP     R3, R2
                RBRA    E_SHL32_00, !Z
                CMP     R9, R0
                RBRA    E_SHL32_01, !Z
                CMP     R8, R1
                RBRA    E_SHL32_02, !Z
                RBRA    L_SHL32_01, 1

E_SHL32_00      HALT
E_SHL32_01      HALT
E_SHL32_02      HALT

L_SHL32_02


L_SHR32_00      MOVE    STIM_SHR32, R11
L_SHR32_01      MOVE    0x89AB, R8
                MOVE    0x4567, R9
                MOVE    @R11++, R10
                RBRA    L_SHR32_02, N
                MOVE    @R11++, R14
                SYSCALL(shr32, 1)
                MOVE    @R11++, R0
                MOVE    @R11++, R1

                CMP     R9, R0
                RBRA    E_SHR32_01, !Z
                CMP     R8, R1
                RBRA    E_SHR32_02, !Z
                RBRA    L_SHR32_01, 1

E_SHR32_01      HALT
E_SHR32_02      HALT

L_SHR32_02

; Everything worked as expected! We are done now.
EXIT            MOVE    OK, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

OK              .ASCII_W    "OK\n"



;* MTH$SHL32 performs 32-bit shift-left with the same semantics as SHL:
;*           fills with X and shifts to C
;*           R8 = low word, R9 = high word, R10 = SHL amount

STIM_SHL32      .DW     0x0000, ST____C_, 0x4567, 0x89AB, ST____C_
                .DW     0x0004, ST____C_, 0x5678, 0x9AB0, ST______
                .DW     0x0008, ST____C_, 0x6789, 0xAB00, ST____C_
                .DW     0x000C, ST____C_, 0x789A, 0xB000, ST______
                .DW     0x0010, ST____C_, 0x89AB, 0x0000, ST____C_
                .DW     0x0014, ST____C_, 0x9AB0, 0x0000, ST______
                .DW     0x0018, ST____C_, 0xAB00, 0x0000, ST____C_
                .DW     0x001C, ST____C_, 0xB000, 0x0000, ST______
                .DW     0x0020, ST____C_, 0x0000, 0x0000, ST____C_
                .DW     0x0024, ST____C_, 0x0000, 0x0000, ST______

                .DW     0x0000, ST_____X, 0x4567, 0x89AB, ST______
                .DW     0x0004, ST_____X, 0x5678, 0x9ABF, ST______
                .DW     0x0008, ST_____X, 0x6789, 0xABFF, ST____C_
                .DW     0x000C, ST_____X, 0x789A, 0xBFFF, ST______
                .DW     0x0010, ST_____X, 0x89AB, 0xFFFF, ST____C_
                .DW     0x0014, ST_____X, 0x9ABF, 0xFFFF, ST______
                .DW     0x0018, ST_____X, 0xABFF, 0xFFFF, ST____C_
                .DW     0x001C, ST_____X, 0xBFFF, 0xFFFF, ST______
                .DW     0x0020, ST_____X, 0xFFFF, 0xFFFF, ST____C_
                .DW     0x0024, ST_____X, 0xFFFF, 0xFFFF, ST____C_

                .DW     0xFFFF

;* MTH$SHR32 performs 32-bit shift-right with the same semantics as SHR:
;*           fills with C and shifts to X
;*           R8 = low word, R9 = high word, R10 = SHR amount

STIM_SHR32      .DW     0x0000, ST_____X, 0x4567, 0x89AB
                .DW     0x0004, ST_____X, 0x0456, 0x789A
                .DW     0x0008, ST_____X, 0x0045, 0x6789
                .DW     0x000C, ST_____X, 0x0004, 0x5678
                .DW     0x0010, ST_____X, 0x0000, 0x4567
                .DW     0x0014, ST_____X, 0x0000, 0x0456
                .DW     0x0018, ST_____X, 0x0000, 0x0045
                .DW     0x001C, ST_____X, 0x0000, 0x0004
                .DW     0x0020, ST_____X, 0x0000, 0x0000
                .DW     0x0024, ST_____X, 0x0000, 0x0000

                .DW     0x0000, ST____C_, 0x4567, 0x89AB
                .DW     0x0004, ST____C_, 0xF456, 0x789A
                .DW     0x0008, ST____C_, 0xFF45, 0x6789
                .DW     0x000C, ST____C_, 0xFFF4, 0x5678
                .DW     0x0010, ST____C_, 0xFFFF, 0x4567
                .DW     0x0014, ST____C_, 0xFFFF, 0xF456
                .DW     0x0018, ST____C_, 0xFFFF, 0xFF45
                .DW     0x001C, ST____C_, 0xFFFF, 0xFFF4
                .DW     0x0020, ST____C_, 0xFFFF, 0xFFFF
                .DW     0x0024, ST____C_, 0xFFFF, 0xFFFF

                .DW     0xFFFF

