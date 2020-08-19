; Extended CPU test

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000

; This is a comprehensive test suite of the QNICE processor.
; The QNICE processor has 18 different instructions, 4 different addressing
; modes, and 5 different status flags.
; Making an exhaustive test of all possible combinations of the three
; different parameters is too big.
; Instead, this program tests:
; 1. All combinations of flags and branching.
; 2. All combinations of instructions and status flags.
; 3. All combinations of instructions and addressing modes.

; Tests in this file:
; Group 1. All combinations of flags and branching.
; UNC      : Test unconditional absolute and relative branches
; R14_ST   : Test that moving data into R14 sets the correct status bits
; MOVE_IMM : Test the MOVE immediate instruction, and the X, Z, and N-conditional branches
; MOVE_REG : Test the MOVE register instruction, and the X, Z, and N-conditional branches
; CMP_IMM  : Test compare with immediate value and Z-conditional absolute branch
; CMP_REG  : Test compare between two registers and Z-conditional relative branch
; REG_13   : Test all 13 registers can contain different values
; ADD      : Test the ADD instruction, and the status register
; MOVE_CV  : Test the MOVE instruction doesnt change C and V flags
; MOVE_MEM : Test the MOVE instruction to/from a memory address
; PC_R15   : Test that PC is the same as R15
; SUB      : Test the instructions RSUB and ASUB, and the use of the Stack Pointer and R13.
; BANK     : Test register banking
; RB_R14   : Test RB instructions with R14

; Group 2. All combinations of instructions and status flags.
; ADDC     : Test the ADDC instruction with all flags
; SUB      : Test the SUB instruction with all flags
; SUBC     : Test the SUBC instruction with all flags
; SHL      : Test the SHL instruction with all flags
; SHR      : Test the SHR instruction with all flags
; SWAP     : Test the SWAP instruction with all flags
; NOT      : Test the NOT instruction with all flags
; AND      : Test the AND instruction with all flags
; OR       : Test the OR instruction with all flags
; XOR      : Test the XOR instruction with all flags
; CMP      : Test the CMP instruction with all flags

; Group 3. All combinations of instructions and addressing modes.
; MOVE_AM  : Test the MOVE instruction with all addressing modes (different registers)
; MOVE_AM2 : Test the MOVE instruction with all addressing modes (same registers)
; SUB_AM   : Test the SUB instruction with all addressing modes (different registers)
; SUB_AM2  : Test the SUB instruction with all addressing modes (same registers)

; Instructions:
; MOVE, ADD, ADDC, SUB, SUBC, SHL, SHR, SWAP
; NOT, AND, OR, XOR, CMP, res, HALT, BRA/SUB

; We cant explicitly test the HALT instruction, so we must just assume that
; it works as expected.

; Addressing modes
; R0
; @R0
; @R0++
; @--R0

; Status register (bits 7 - 0) of R14:
; - - V N Z C X 1

#define ST______ 0x0001
#define ST_____X 0x0003
#define ST____C_ 0x0005
#define ST____CX 0x0007
#define ST___Z__ 0x0009
#define ST___Z_X 0x000B
#define ST___ZC_ 0x000D
#define ST___ZCX 0x000F
#define ST__N___ 0x0011
#define ST__N__X 0x0013
#define ST__N_C_ 0x0015
#define ST__N_CX 0x0017
#define ST__NZ__ 0x0019
#define ST__NZ_X 0x001B
#define ST__NZC_ 0x001D
#define ST__NZCX 0x001F
#define ST_V____ 0x0021
#define ST_V___X 0x0023
#define ST_V__C_ 0x0025
#define ST_V__CX 0x0027
#define ST_V_Z__ 0x0029
#define ST_V_Z_X 0x002B
#define ST_V_ZC_ 0x002D
#define ST_V_ZCX 0x002F
#define ST_VN___ 0x0031
#define ST_VN__X 0x0033
#define ST_VN_C_ 0x0035
#define ST_VN_CX 0x0037
#define ST_VNZ__ 0x0039
#define ST_VNZ_X 0x003B
#define ST_VNZC_ 0x003D
#define ST_VNZCX 0x003F

; Instruction | Flags affected
;             | V | N | Z | C | X |
; MOVE        | . | * | * | . | * |
; SWAP        | . | * | * | . | * |
; NOT         | . | * | * | . | * |
; AND/OR/XOR  | . | * | * | . | * |
; ADD/SUB     | * | * | * | * | * |
; SHL         | . | . | . | * | . |
; SHR         | . | . | . | . | * |
; CMP         | * | * | * | . | . |
; BRA/SUB     | . | . | . | . | . |


; ---------------------------------------------------------------------------
; Test unconditional absolute and relative branches.

L_UNC_0         ABRA    E_UNC_1, !1             ; Verify "absolute branch never" is not taken.

                ABRA    L_UNC_1, 1              ; Verify "absolute branch always" is taken.
                HALT

E_UNC_1         HALT

E_UNC_2         HALT

L_UNC_2         RBRA    L_UNC_3, 1              ; Verify "relative branch always" is taken in the forward direction.
                HALT

L_UNC_1         RBRA    E_UNC_2, !1             ; Verify "relative branch never" is not taken.
                RBRA    L_UNC_2, 1              ; Verify "relative branch always" is taken in the backward direction.
                HALT

L_UNC_3


; ---------------------------------------------------------------------------
; Test that moving data into R14 sets the correct status bits

L_R14_ST_00     MOVE    0x00FF, R14                ; Set all bits in the status register
                RBRA    E_R14_ST_01, !V            ; Verify "relative branch nonoverflow" is not taken.
                RBRA    L_R14_ST_01, V             ; Verify "relative branch overflow" is taken.
                HALT
E_R14_ST_01     HALT
L_R14_ST_01
                RBRA    E_R14_ST_02, !N            ; Verify "relative branch nonnegative" is not taken.
                RBRA    L_R14_ST_02, N             ; Verify "relative branch negative" is taken.
                HALT
E_R14_ST_02     HALT
L_R14_ST_02
                RBRA    E_R14_ST_03, !Z            ; Verify "relative branch nonzero" is not taken.
                RBRA    L_R14_ST_03, Z             ; Verify "relative branch zero" is taken.
                HALT
E_R14_ST_03     HALT
L_R14_ST_03
                RBRA    E_R14_ST_04, !C            ; Verify "relative branch noncarry" is not taken.
                RBRA    L_R14_ST_04, C             ; Verify "relative branch carry" is taken.
                HALT
E_R14_ST_04     HALT
L_R14_ST_04
                RBRA    E_R14_ST_05, !X            ; Verify "relative branch nonX" is not taken.
                RBRA    L_R14_ST_05, X             ; Verify "relative branch X" is taken.
                HALT
E_R14_ST_05     HALT
L_R14_ST_05
                RBRA    E_R14_ST_06, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_R14_ST_06, 1             ; Verify "relative branch always" is taken.
                HALT
E_R14_ST_06     HALT
L_R14_ST_06

L_R14_ST_10     MOVE    0x0000, R14                ; Clear all bits in the status register
                RBRA    E_R14_ST_11, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_R14_ST_11, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_R14_ST_11     HALT
L_R14_ST_11
                RBRA    E_R14_ST_12, N             ; Verify "relative branch negative" is not taken.
                RBRA    L_R14_ST_12, !N            ; Verify "relative branch nonnegative" is taken.
                HALT
E_R14_ST_12     HALT
L_R14_ST_12
                RBRA    E_R14_ST_13, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_R14_ST_13, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_R14_ST_13     HALT
L_R14_ST_13
                RBRA    E_R14_ST_14, C             ; Verify "relative branch carry" is not taken.
                RBRA    L_R14_ST_14, !C            ; Verify "relative branch noncarry" is taken.
                HALT
E_R14_ST_14     HALT
L_R14_ST_14
                RBRA    E_R14_ST_15, X             ; Verify "relative branch X" is not taken.
                RBRA    L_R14_ST_15, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_R14_ST_15     HALT
L_R14_ST_15
                RBRA    E_R14_ST_16, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_R14_ST_16, 1             ; Verify "relative branch always" is taken.
                HALT
E_R14_ST_16     HALT
L_R14_ST_16



; ---------------------------------------------------------------------------
; Test the MOVE immediate instruction, and the X, Z, and N-conditional branches

L_MOVE_IMM_00   MOVE    0x1234, R0
                ABRA    E_MOVE_IMM_01, Z        ; Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_01, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_01   HALT
L_MOVE_IMM_01
                ABRA    E_MOVE_IMM_02, N        ; Verify "absolute branch negative" is not taken.
                ABRA    L_MOVE_IMM_02, !N       ; Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_IMM_02   HALT
L_MOVE_IMM_02
                ABRA    E_MOVE_IMM_03, X        ; Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_03, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_03   HALT
L_MOVE_IMM_03
                ABRA    E_MOVE_IMM_04, !1       ; Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_04, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_04   HALT
L_MOVE_IMM_04


L_MOVE_IMM_10   MOVE    0x0000, R0
                ABRA    E_MOVE_IMM_11, !Z       ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_MOVE_IMM_11, Z        ; Verify "absolute branch zero" is taken.
                HALT
E_MOVE_IMM_11   HALT
L_MOVE_IMM_11
                ABRA    E_MOVE_IMM_12, N        ; Verify "absolute branch negative" is not taken.
                ABRA    L_MOVE_IMM_12, !N       ; Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_IMM_12   HALT
L_MOVE_IMM_12
                ABRA    E_MOVE_IMM_13, X        ; Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_13, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_13   HALT
L_MOVE_IMM_13
                ABRA    E_MOVE_IMM_14, !1       ; Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_14, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_14   HALT
L_MOVE_IMM_14


L_MOVE_IMM_20   MOVE    0xFEDC, R0
                ABRA    E_MOVE_IMM_21, Z        ; Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_21, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_21   HALT
L_MOVE_IMM_21
                ABRA    E_MOVE_IMM_22, !N       ; Verify "absolute branch nonnegative" is not taken.
                ABRA    L_MOVE_IMM_22, N        ; Verify "absolute branch negative" is taken.
                HALT
E_MOVE_IMM_22   HALT
L_MOVE_IMM_22
                ABRA    E_MOVE_IMM_23, X        ; Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_23, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_23   HALT
L_MOVE_IMM_23
                ABRA    E_MOVE_IMM_24, !1       ; Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_24, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_24   HALT
L_MOVE_IMM_24


L_MOVE_IMM_30   MOVE    0xFFFF, R0
                ABRA    E_MOVE_IMM_31, Z        ; Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_31, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_31   HALT
L_MOVE_IMM_31
                ABRA    E_MOVE_IMM_32, !N       ; Verify "absolute branch nonnegative" is not taken.
                ABRA    L_MOVE_IMM_32, N        ; Verify "absolute branch negative" is taken.
                HALT
E_MOVE_IMM_32   HALT
L_MOVE_IMM_32
                ABRA    E_MOVE_IMM_33, !X       ; Verify "absolute branch nonX" is not taken.
                ABRA    L_MOVE_IMM_33, X        ; Verify "absolute branch X" is taken.
                HALT
E_MOVE_IMM_33   HALT
L_MOVE_IMM_33
                ABRA    E_MOVE_IMM_34, !1       ; Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_34, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_34   HALT
L_MOVE_IMM_34


; ---------------------------------------------------------------------------
; Test the MOVE register instruction, and the X, Z, and N-conditional branches

L_MOVE_REG_00   MOVE    0x1234, R1
                MOVE    0x0000, R2
                MOVE    0xFEDC, R3
                MOVE    0xFFFF, R4

                MOVE    R1, R0
                RBRA    E_MOVE_REG_01, Z        ; Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_01, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_01   HALT
L_MOVE_REG_01
                RBRA    E_MOVE_REG_02, N        ; Verify "absolute branch negative" is not taken.
                RBRA    L_MOVE_REG_02, !N       ; Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_REG_02   HALT
L_MOVE_REG_02
                RBRA    E_MOVE_REG_03, X        ; Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_03, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_03   HALT
L_MOVE_REG_03
                RBRA    E_MOVE_REG_04, !1       ; Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_04, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_04   HALT
L_MOVE_REG_04


L_MOVE_REG_10   MOVE    R2, R0
                RBRA    E_MOVE_REG_11, !Z       ; Verify "absolute branch nonzero" is not taken.
                RBRA    L_MOVE_REG_11, Z        ; Verify "absolute branch zero" is taken.
                HALT
E_MOVE_REG_11   HALT
L_MOVE_REG_11
                RBRA    E_MOVE_REG_12, N        ; Verify "absolute branch negative" is not taken.
                RBRA    L_MOVE_REG_12, !N       ; Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_REG_12   HALT
L_MOVE_REG_12
                RBRA    E_MOVE_REG_13, X        ; Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_13, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_13   HALT
L_MOVE_REG_13
                RBRA    E_MOVE_REG_14, !1       ; Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_14, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_14   HALT
L_MOVE_REG_14


L_MOVE_REG_20   MOVE    R3, R0
                RBRA    E_MOVE_REG_21, Z        ; Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_21, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_21   HALT
L_MOVE_REG_21
                RBRA    E_MOVE_REG_22, !N       ; Verify "absolute branch nonnegative" is not taken.
                RBRA    L_MOVE_REG_22, N        ; Verify "absolute branch negative" is taken.
                HALT
E_MOVE_REG_22   HALT
L_MOVE_REG_22
                RBRA    E_MOVE_REG_23, X        ; Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_23, !X       ; Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_23   HALT
L_MOVE_REG_23
                RBRA    E_MOVE_REG_24, !1       ; Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_24, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_24   HALT
L_MOVE_REG_24


L_MOVE_REG_30   MOVE    R4, R0
                RBRA    E_MOVE_REG_31, Z        ; Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_31, !Z       ; Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_31   HALT
L_MOVE_REG_31
                RBRA    E_MOVE_REG_32, !N       ; Verify "absolute branch nonnegative" is not taken.
                RBRA    L_MOVE_REG_32, N        ; Verify "absolute branch negative" is taken.
                HALT
E_MOVE_REG_32   HALT
L_MOVE_REG_32
                RBRA    E_MOVE_REG_33, !X       ; Verify "absolute branch nonX" is not taken.
                RBRA    L_MOVE_REG_33, X        ; Verify "absolute branch X" is taken.
                HALT
E_MOVE_REG_33   HALT
L_MOVE_REG_33
                RBRA    E_MOVE_REG_34, !1       ; Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_34, 1        ; Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_34   HALT
L_MOVE_REG_34


; ---------------------------------------------------------------------------
; Test compare with immediate value and Z-conditional absolute branch

L_CMP_IMM_0     MOVE    0x1234, R0
                MOVE    0x4321, R1

; Compare R0 with correct value.
                CMP     0x1234, R0
                ABRA    E_CMP_IMM_1, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_1, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_1     HALT
L_CMP_IMM_1
                CMP     R0, 0x1234
                ABRA    E_CMP_IMM_2, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_2, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_2     HALT
L_CMP_IMM_2

; Compare R1 with correct value.
                CMP     0x4321, R1
                ABRA    E_CMP_IMM_3, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_3, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_3     HALT
L_CMP_IMM_3
                CMP     R1, 0x4321
                ABRA    E_CMP_IMM_4, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_4, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_4     HALT
L_CMP_IMM_4

; Compare R1 with incorrect value.
                CMP     0x1234, R1
                ABRA    E_CMP_IMM_5, Z          ; Verify "absolute branch zero" is not taken.
                ABRA    L_CMP_IMM_5, !Z         ; Verify "absolute branch nonzero" is taken.
                HALT
E_CMP_IMM_5     HALT
L_CMP_IMM_5
                CMP     R1, 0x1234
                ABRA    E_CMP_IMM_6, Z          ; Verify "absolute branch zero" is not taken.
                ABRA    L_CMP_IMM_6, !Z         ; Verify "absolute branch nonzero" is taken.
                HALT
E_CMP_IMM_6     HALT
L_CMP_IMM_6
                MOVE    R0, R1
; Compare R1 with correct value.
                CMP     0x1234, R1
                ABRA    E_CMP_IMM_7, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_7, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_7     HALT
L_CMP_IMM_7
                CMP     R1, 0x1234
                ABRA    E_CMP_IMM_8, !Z         ; Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_8, Z          ; Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_8     HALT
L_CMP_IMM_8


; ---------------------------------------------------------------------------
; Test compare between two registers and Z-conditional relative branch

L_CMP_REG_0     MOVE    0x1234, R0
                MOVE    0x4321, R1

; Compare registers with different values.
                CMP     R0, R1
                RBRA    E_CMP_REG_1, Z          ; Verify "relative branch zero" is not taken.
                RBRA    L_CMP_REG_1, !Z         ; Verify "relative branch nonzero" is taken.
                HALT
E_CMP_REG_1     HALT
L_CMP_REG_1
                CMP     R1, R0
                RBRA    E_CMP_REG_2, Z          ; Verify "relative branch zero" is not taken.
                RBRA    L_CMP_REG_2, !Z         ; Verify "relative branch nonzero" is taken.
                HALT
E_CMP_REG_2     HALT
L_CMP_REG_2
                MOVE    R1, R0

; Compare registers with equal values.
                CMP     R0, R1
                RBRA    E_CMP_REG_3, !Z         ; Verify "relative branch nonzero" is not taken.
                RBRA    L_CMP_REG_3, Z          ; Verify "relative branch zero" is taken.
                HALT
E_CMP_REG_3     HALT
L_CMP_REG_3
                CMP     R1, R0
                RBRA    E_CMP_REG_4, !Z         ; Verify "relative branch nonzero" is not taken.
                RBRA    L_CMP_REG_4, Z          ; Verify "relative branch zero" is taken.
                HALT
E_CMP_REG_4     HALT
L_CMP_REG_4


; REG_13   : Test all 13 registers can contain different values
L_REG_13_00     MOVE    0x0123, R0
                MOVE    0x1234, R1
                MOVE    0x2345, R2
                MOVE    0x3456, R3
                MOVE    0x4567, R4
                MOVE    0x5678, R5
                MOVE    0x6789, R6
                MOVE    0x789A, R7
                MOVE    0x89AB, R8
                MOVE    0x9ABC, R9
                MOVE    0xABCD, R10
                MOVE    0xBCDE, R11
                MOVE    0xCDEF, R12

                CMP     0x0123, R0
                RBRA    E_REG_13_00, !Z
                CMP     0x1234, R1
                RBRA    E_REG_13_00, !Z
                CMP     0x2345, R2
                RBRA    E_REG_13_00, !Z
                CMP     0x3456, R3
                RBRA    E_REG_13_00, !Z
                CMP     0x4567, R4
                RBRA    E_REG_13_00, !Z
                CMP     0x5678, R5
                RBRA    E_REG_13_00, !Z
                CMP     0x6789, R6
                RBRA    E_REG_13_00, !Z
                CMP     0x789A, R7
                RBRA    E_REG_13_00, !Z
                CMP     0x89AB, R8
                RBRA    E_REG_13_00, !Z
                CMP     0x9ABC, R9
                RBRA    E_REG_13_00, !Z
                CMP     0xABCD, R10
                RBRA    E_REG_13_00, !Z
                CMP     0xBCDE, R11
                RBRA    E_REG_13_00, !Z
                CMP     0xCDEF, R12
                RBRA    E_REG_13_00, !Z
                RBRA    L_REG_13_01, 1
E_REG_13_00     HALT
L_REG_13_01


; ---------------------------------------------------------------------------
; Test the ADD instruction, and the status register
; Addition                 | V | N | Z | C | X | 1 |
; 0x1234 + 0x4321 = 0x5555 | 0 | 0 | 0 | 0 | 0 | 1 | ADD_0
; 0x8765 + 0x9876 = 0x1FDB | 1 | 0 | 0 | 1 | 0 | 1 | ADD_1
; 0x1234 + 0x9876 = 0xAAAA | 0 | 1 | 0 | 0 | 0 | 1 | ADD_2
; 0xFEDC + 0xEDCB = 0xECA7 | 0 | 1 | 0 | 1 | 0 | 1 | ADD_3
; 0xFEDC + 0x0123 = 0xFFFF | 0 | 1 | 0 | 0 | 1 | 1 | ADD_4
; 0xFEDC + 0x0124 = 0x0000 | 0 | 0 | 1 | 1 | 0 | 1 | ADD_5
; 0x7654 + 0x6543 = 0xDB97 | 1 | 1 | 0 | 0 | 0 | 1 | ADD_6

; Addition                 | V | N | Z | C | X | 1 |
; 0x1234 + 0x4321 = 0x5555 | 0 | 0 | 0 | 0 | 0 | 1 | ADD_0

                MOVE    0x0000, R14             ; Clear status register

L_ADD_00        MOVE    0x1234, R0
                ADD     0x4321, R0

                RBRA    E_ADD_01, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_01, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_01        HALT
L_ADD_01
                RBRA    E_ADD_02, N             ; Verify "relative branch negative" is not taken.
                RBRA    L_ADD_02, !N            ; Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_02        HALT
L_ADD_02
                RBRA    E_ADD_03, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_03, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_03        HALT
L_ADD_03
                RBRA    E_ADD_04, C             ; Verify "relative branch carry" is not taken.
                RBRA    L_ADD_04, !C            ; Verify "relative branch noncarry" is taken.
                HALT
E_ADD_04        HALT
L_ADD_04
                RBRA    E_ADD_05, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_05, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_05        HALT
L_ADD_05
                RBRA    E_ADD_06, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_06, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_06        HALT
L_ADD_06
                MOVE    R14, R1                 ; Verify status register: --000001
                CMP     0x0001, R1
                RBRA    E_ADD_07, !Z
                RBRA    L_ADD_07, Z
                HALT
E_ADD_07        HALT
L_ADD_07
                CMP     0x5555, R0              ; Verify result
                RBRA    E_ADD_08, !Z
                RBRA    L_ADD_08, Z
                HALT
E_ADD_08        HALT
L_ADD_08


; Addition                 | V | N | Z | C | X | 1 |
; 0x8765 + 0x9876 = 0x1FDB | 1 | 0 | 0 | 1 | 0 | 1 | ADD_1
L_ADD_10        MOVE    0x8765, R0
                ADD     0x9876, R0

                RBRA    E_ADD_11, !V            ; Verify "relative branch nonoverflow" is not taken.
                RBRA    L_ADD_11, V             ; Verify "relative branch overflow" is taken.
                HALT
E_ADD_11        HALT
L_ADD_11
                RBRA    E_ADD_12, N             ; Verify "relative branch negative" is not taken.
                RBRA    L_ADD_12, !N            ; Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_12        HALT
L_ADD_12
                RBRA    E_ADD_13, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_13, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_13        HALT
L_ADD_13
                RBRA    E_ADD_14, !C            ; Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_14, C             ; Verify "relative branch carry" is taken.
                HALT
E_ADD_14        HALT
L_ADD_14
                RBRA    E_ADD_15, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_15, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_15        HALT
L_ADD_15
                RBRA    E_ADD_16, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_16, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_16        HALT
L_ADD_16
                MOVE    R14, R1                 ; Verify status register: --100101
                CMP     0x0025, R1
                RBRA    E_ADD_17, !Z
                RBRA    L_ADD_17, Z
                HALT
E_ADD_17        HALT
L_ADD_17
                CMP     0x1FDB, R0
                RBRA    E_ADD_18, !Z
                RBRA    L_ADD_18, Z
                HALT
E_ADD_18        HALT
L_ADD_18


; Addition                 | V | N | Z | C | X | 1 |
; 0x1234 + 0x9876 = 0xAAAA | 0 | 1 | 0 | 0 | 0 | 1 | ADD_2
L_ADD_20        MOVE    0x1234, R0
                ADD     0x9876, R0

                RBRA    E_ADD_21, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_21, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_21        HALT
L_ADD_21
                RBRA    E_ADD_22, !N            ; Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_22, N             ; Verify "relative branch negative" is taken.
                HALT
E_ADD_22        HALT
L_ADD_22
                RBRA    E_ADD_23, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_23, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_23        HALT
L_ADD_23
                RBRA    E_ADD_24, C             ; Verify "relative branch carry" is not taken.
                RBRA    L_ADD_24, !C            ; Verify "relative branch noncarry" is taken.
                HALT
E_ADD_24        HALT
L_ADD_24
                RBRA    E_ADD_25, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_25, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_25        HALT
L_ADD_25
                RBRA    E_ADD_26, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_26, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_26        HALT
L_ADD_26
                MOVE    R14, R1                 ; Verify status register: --010001
                CMP     0x0011, R1
                RBRA    E_ADD_27, !Z
                RBRA    L_ADD_27, Z
                HALT
E_ADD_27        HALT
L_ADD_27
                CMP     0xAAAA, R0
                RBRA    E_ADD_28, !Z
                RBRA    L_ADD_28, Z
                HALT
E_ADD_28        HALT
L_ADD_28


; Addition                 | V | N | Z | C | X | 1 |
; 0xFEDC + 0xEDCB = 0xECA7 | 0 | 1 | 0 | 1 | 0 | 1 | ADD_3
L_ADD_30        MOVE    0xFEDC, R0
                ADD     0xEDCB, R0

                RBRA    E_ADD_31, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_31, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_31        HALT
L_ADD_31
                RBRA    E_ADD_32, !N            ; Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_32, N             ; Verify "relative branch negative" is taken.
                HALT
E_ADD_32        HALT
L_ADD_32
                RBRA    E_ADD_33, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_33, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_33        HALT
L_ADD_33
                RBRA    E_ADD_34, !C            ; Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_34, C             ; Verify "relative branch carry" is taken.
                HALT
E_ADD_34        HALT
L_ADD_34
                RBRA    E_ADD_35, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_35, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_35        HALT
L_ADD_35
                RBRA    E_ADD_36, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_36, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_36        HALT
L_ADD_36
                MOVE    R14, R1                 ; Verify status register: --010101
                CMP     0x0015, R1
                RBRA    E_ADD_37, !Z
                RBRA    L_ADD_37, Z
                HALT
E_ADD_37        HALT
L_ADD_37
                CMP     0xECA7, R0
                RBRA    E_ADD_38, !Z
                RBRA    L_ADD_38, Z
                HALT
E_ADD_38        HALT
L_ADD_38


; Addition                 | V | N | Z | C | X | 1 |
; 0xFEDC + 0x0123 = 0xFFFF | 0 | 1 | 0 | 0 | 1 | 1 | ADD_4
L_ADD_40        MOVE    0xFEDC, R0
                ADD     0x0123, R0

                RBRA    E_ADD_41, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_41, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_41        HALT
L_ADD_41
                RBRA    E_ADD_42, !N            ; Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_42, N             ; Verify "relative branch negative" is taken.
                HALT
E_ADD_42        HALT
L_ADD_42
                RBRA    E_ADD_43, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_43, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_43        HALT
L_ADD_43
                RBRA    E_ADD_44, C             ; Verify "relative branch carry" is not taken.
                RBRA    L_ADD_44, !C            ; Verify "relative branch noncarry" is taken.
                HALT
E_ADD_44        HALT
L_ADD_44
                RBRA    E_ADD_45, !X            ; Verify "relative branch nonX" is not taken.
                RBRA    L_ADD_45, X             ; Verify "relative branch X" is taken.
                HALT
E_ADD_45        HALT
L_ADD_45
                RBRA    E_ADD_46, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_46, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_46        HALT
L_ADD_46
                MOVE    R14, R1                 ; Verify status register: --010011
                CMP     0x0013, R1
                RBRA    E_ADD_47, !Z
                RBRA    L_ADD_47, Z
                HALT
E_ADD_47        HALT
L_ADD_47
                CMP     0xFFFF, R0
                RBRA    E_ADD_48, !Z
                RBRA    L_ADD_48, Z
                HALT
E_ADD_48        HALT
L_ADD_48


; Addition                 | V | N | Z | C | X | 1 |
; 0xFEDC + 0x0124 = 0x0000 | 0 | 0 | 1 | 1 | 0 | 1 | ADD_5
L_ADD_50        MOVE    0xFEDC, R0
                ADD     0x0124, R0

                RBRA    E_ADD_51, V             ; Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_51, !V            ; Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_51        HALT
L_ADD_51
                RBRA    E_ADD_52, N             ; Verify "relative branch negative" is not taken.
                RBRA    L_ADD_52, !N            ; Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_52        HALT
L_ADD_52
                RBRA    E_ADD_53, !Z            ; Verify "relative branch nonzero" is not taken.
                RBRA    L_ADD_53, Z             ; Verify "relative branch zero" is taken.
                HALT
E_ADD_53        HALT
L_ADD_53
                RBRA    E_ADD_54, !C            ; Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_54, C             ; Verify "relative branch carry" is taken.
                HALT
E_ADD_54        HALT
L_ADD_54
                RBRA    E_ADD_55, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_55, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_55        HALT
L_ADD_55
                RBRA    E_ADD_56, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_56, 1             ; Verify "relative branch always" is taken.
                HALT
E_ADD_56        HALT
L_ADD_56
                MOVE    R14, R1                 ; Verify status register: --001101
                CMP     0x000D, R1
                RBRA    E_ADD_57, !Z
                RBRA    L_ADD_57, Z
                HALT
E_ADD_57        HALT
L_ADD_57
                CMP     0x0000, R0
                RBRA    E_ADD_58, !Z
                RBRA    L_ADD_58, Z
                HALT
E_ADD_58        HALT
L_ADD_58


; Addition                 | V | N | Z | C | X | 1 |
; 0x7654 + 0x6543 = 0xDB97 | 1 | 1 | 0 | 0 | 0 | 1 | ADD_6
L_ADD_60        MOVE    0x7654, R0
                ADD     0x6543, R0

                RBRA    E_ADD_61, !V            ; Verify "relative branch nonoverflow" is not taken.
                RBRA    L_ADD_61, V             ; Verify "relative branch overflow" is taken.
                HALT
E_ADD_61        HALT
L_ADD_61
                RBRA    E_ADD_62, !N            ; Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_62, N             ; Verify "relative branch negative" is taken.
                HALT
E_ADD_62        HALT
L_ADD_62
                RBRA    E_ADD_63, Z             ; Verify "relative branch zero" is not taken.
                RBRA    L_ADD_63, !Z            ; Verify "relative branch nonzero" is taken.
                HALT
E_ADD_63        HALT
L_ADD_63
                RBRA    E_ADD_64, C             ; Verify "relative branch carry" is not taken.
                RBRA    L_ADD_64, !C            ; Verify "relative branch noncarry" is taken.
                HALT
E_ADD_64        HALT
L_ADD_64
                RBRA    E_ADD_65, X             ; Verify "relative branch X" is not taken.
                RBRA    L_ADD_65, !X            ; Verify "relative branch nonX" is taken.
                HALT
E_ADD_65        HALT
L_ADD_65
                RBRA    E_ADD_66, !1            ; Verify "relative branch never" is not taken.
                RBRA    L_ADD_66 1              ; Verify "relative branch always" is taken.
                HALT
E_ADD_66        HALT
L_ADD_66
                MOVE    R14, R1                 ; Verify status register: --110001
                CMP     0x0031, R1
                RBRA    E_ADD_67, !Z
                RBRA    L_ADD_67, Z
                HALT
E_ADD_67        HALT
L_ADD_67
                CMP     0xDB97, R0
                RBRA    E_ADD_68, !Z
                RBRA    L_ADD_68, Z
                HALT
E_ADD_68        HALT
L_ADD_68


; ---------------------------------------------------------------------------
; Test the MOVE instruction doesnt change C and V flags.
L_MOVE_CV_00    MOVE    0x0000, R14             ; Clear all bits in the status register

                MOVE    0x0000, R0              ; Perform a MOVE instruction
                RBRA    E_MOVE_CV_01, V         ; Verify "relative branch overflow" is not taken.
                RBRA    L_MOVE_CV_01, !V        ; Verify "relative branch nonoverflow" is taken.
                HALT
E_MOVE_CV_01    HALT
L_MOVE_CV_01
                RBRA    E_MOVE_CV_02, C         ; Verify "relative branch carry" is not taken.
                RBRA    L_MOVE_CV_02, !C        ; Verify "relative branch noncarry" is taken.
                HALT
E_MOVE_CV_02    HALT
L_MOVE_CV_02

L_MOVE_CV_10    MOVE    0x00FF, R14             ; Set all bits in the status register

                MOVE    0x0000, R0              ; Perform a MOVE instruction
                RBRA    E_MOVE_CV_11, !V        ; Verify "relative branch nonoverflow" is not taken.
                RBRA    L_MOVE_CV_11, V         ; Verify "relative branch overflow" is taken.
                HALT
E_MOVE_CV_11    HALT
L_MOVE_CV_11
                RBRA    E_MOVE_CV_12, !C        ; Verify "relative branch noncarry" is not taken.
                RBRA    L_MOVE_CV_12, C         ; Verify "relative branch carry" is taken.
                HALT
E_MOVE_CV_12    HALT
L_MOVE_CV_12


; ---------------------------------------------------------------------------
; MOVE_MEM : Test the MOVE instruction to/from a memory address.

L_MOVE_MEM_00   MOVE    VAL1234, R0
                MOVE    VAL4321, R1
                MOVE    BSS0, R2
                MOVE    BSS1, R3
                MOVE    @R0, R4                 ; Now R4 contains 0x1234
                MOVE    @R1, R5                 ; Now R5 contains 0x4321

                CMP     R4, 0x1234
                RBRA    E_MOVE_MEM_01, !Z
                RBRA    L_MOVE_MEM_01, Z
                HALT
E_MOVE_MEM_01   HALT
L_MOVE_MEM_01
                CMP     R5, 0x4321
                RBRA    E_MOVE_MEM_02, !Z
                RBRA    L_MOVE_MEM_02, Z
                HALT
E_MOVE_MEM_02   HALT
L_MOVE_MEM_02

                MOVE    R4, @R2                 ; Now BSS0 contains 0x1234
                MOVE    R5, @R3                 ; Now BSS1 contains 0x4321

                CMP     R4, 0x1234              ; R4 still contains 0x1234
                RBRA    E_MOVE_MEM_03, !Z
                RBRA    L_MOVE_MEM_03, Z
                HALT
E_MOVE_MEM_03   HALT
L_MOVE_MEM_03
                CMP     R5, 0x4321              ; R5 still contains 0x4321
                RBRA    E_MOVE_MEM_04, !Z
                RBRA    L_MOVE_MEM_04, Z
                HALT
E_MOVE_MEM_04   HALT
L_MOVE_MEM_04

                MOVE    @R2, R5                 ; Now R5 contains 0x1234
                MOVE    @R3, R4                 ; Now R4 contains 0x4321

                CMP     R5, 0x1234
                RBRA    E_MOVE_MEM_05, !Z
                RBRA    L_MOVE_MEM_05, Z
                HALT
E_MOVE_MEM_05   HALT
L_MOVE_MEM_05
                CMP     R4, 0x4321
                RBRA    E_MOVE_MEM_06, !Z
                RBRA    L_MOVE_MEM_06, Z
                HALT
E_MOVE_MEM_06   HALT

VAL1234         .DW     0x1234
VAL4321         .DW     0x4321
BSS0            .DW     0x0000
BSS1            .DW     0x0000

L_MOVE_MEM_06


; ---------------------------------------------------------------------------
; Test that PC is the same as R15
L_PC_R15_00     MOVE    R15, R0                 ; Copy PC to R0
L_PC_R15_01     MOVE    R1, R1                  ; Perform a NOP
                CMP     L_PC_R15_01, R0
                RBRA    E_PC_R15_01, !Z

                MOVE    0, R0                   ; Setup registers
                MOVE    1, R1
                MOVE    L_PC_R15_02, R15        ; Jump!
                HALT
L_PC_R15_02     MOVE    R0, R1                  ; Single-word instruction
                CMP     R0, R1                  ; Did previous instruction execute?
                RBRA    E_PC_R15_02, !Z
                RBRA    L_PC_R15_10, 1

E_PC_R15_01     HALT
E_PC_R15_02     HALT
L_PC_R15_10


; ---------------------------------------------------------------------------
; Test the instructions RSUB and ASUB, and the use of the Stack Pointer and R13.
L_RSUB_00       MOVE    L_STACK_TOP, R13
                RSUB    L_RSUB_01, 1            ; Test RSUB
L_RSUB_RET_01   HALT                            ; We will never return here!

L_RSUB_01       MOVE    L_STACK_TOP, R9
                CMP     0x5678, @R9             ; Verify value on stack unchanged
                RBRA    E_RSUB_01, !Z           ; Jump if error

                SUB     1, R9
                CMP     R9, R13                 ; Verify R13 decremented
                RBRA    E_RSUB_02, !Z           ; Jump if error

                CMP     L_RSUB_RET_01, @R9      ; Verify return address
                RBRA    E_RSUB_03, !Z           ; Jump if error

                SUB     1, R9
                CMP     0x3456, @R9             ; Verify value on stack unchanged
                RBRA    E_RSUB_04, !Z           ; Jump if error

                RBRA    L_RSUB_10, 1

E_RSUB_01       HALT
E_RSUB_02       HALT
E_RSUB_03       HALT
E_RSUB_04       HALT

L_STACK_BOT     .DW     0x0123, 0x1234, 0x2345, 0x3456, 0x4567
L_STACK_TOP     .DW     0x5678

L_RSUB_10


; ---------------------------------------------------------------------------
; Test RB instructions with R14

L_RB_R14_00     MOVE    0x0000, R14             ; All flags initially clear
                INCRB
                CMP     0x0101, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_01, !Z

                MOVE    0x00FF, R14             ; All flags initially set
                INCRB
                CMP     0x01FF, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_02, !Z

                MOVE    0xFF00, R14             ; All flags initially clear
                INCRB
                CMP     0x0001, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_03, !Z

                MOVE    0xFFFF, R14             ; All flags initially set
                INCRB
                CMP     0x00FF, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_04, !Z

                MOVE    0x0100, R14             ; All flags initially clear
                DECRB
                CMP     0x0001, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_05, !Z

                MOVE    0x01FF, R14             ; All flags initially set
                DECRB
                CMP     0x00FF, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_06, !Z

                MOVE    0x0000, R14             ; All flags initially clear
                DECRB
                CMP     0xFF01, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_07, !Z

                MOVE    0x00FF, R14             ; All flags initially set
                DECRB
                CMP     0xFFFF, R14             ; Verify flags unchanged
                RBRA    E_RB_R14_08, !Z

                RBRA    L_RB_R14_01, 1
E_RB_R14_01     HALT
E_RB_R14_02     HALT
E_RB_R14_03     HALT
E_RB_R14_04     HALT
E_RB_R14_05     HALT
E_RB_R14_06     HALT
E_RB_R14_07     HALT
E_RB_R14_08     HALT
L_RB_R14_01


; ---------------------------------------------------------------------------
; Test register banking

; First do a quick-and-dirty test to verify
; that R0-R7 are banked and R8-R15 are not.
L_BANK_00       MOVE    0, R14                  ; Reset register bank
                MOVE    L_STACK_TOP, R13        ; Reset stack pointer

                MOVE    0x0123, R0              ; Stores values in R0 and R8
                MOVE    0x4567, R8

                INCRB                           ; Change register bank

                MOVE    0x89AB, R0              ; Store new value in (banked) R0
                CMP     0x4567, R8              ; Verify R8 is unchanged
                RBRA    E_BANK_01, !Z           ; Jump if error
                CMP     0x89AB, R0              ; Verify R0 new value
                RBRA    E_BANK_02, !Z           ; Jump if error

                DECRB                           ; Revert register bank

                CMP     0x4567, R8              ; Verify R8 is unchanged
                RBRA    E_BANK_03, !Z           ; Jump if error
                CMP     0x0123, R0              ; Verify unbanked R0 is unchanged
                RBRA    E_BANK_04, !Z           ; Jump if error

; Fill all register banks
                MOVE    0, R9                   ; Current value to write
                MOVE    0, R14                  ; Reset register bank

L_BANK_01       RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R0
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R1
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R2
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R3
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R4
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R5
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R6
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                MOVE    R9, R7

                INCRB
                MOVE    R14, R10
                AND     0xFF00, R10
                RBRA    L_BANK_01, !Z

; Verify all register banks
                MOVE    0, R9                   ; Current value to write

L_BANK_02       RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R0
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R1
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R2
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R3
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R4
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R5
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R6
                RBRA    E_BANK_05, !Z           ; Jump if error
                RSUB    L_BANK_PRNG, 1          ; Get new value of R9
                CMP     R9, R7
                RBRA    E_BANK_05, !Z           ; Jump if error

                INCRB
                MOVE    R14, R10
                AND     0xFF00, R10
                RBRA    L_BANK_02, !Z

                RBRA    L_BANK_10, 1

E_BANK_01       HALT
E_BANK_02       HALT
E_BANK_03       HALT
E_BANK_04       HALT
E_BANK_05       HALT


; Generate PRNG by calculating R9 := (3*R9+1) mod 65536
; This generates more than 2100 different values
L_BANK_PRNG     MOVE    R9, R10
                ADD     R9, R10
                ADD     R10, R9
                ADD     1, R9
                RET

L_BANK_10


; ---------------------------------------------------------------------------
; Test the ADDC instruction

L_ADDC_00       MOVE    STIM_ADDC, R8
L_ADDC_01       MOVE    @R8, R0                 ; First operand
                RBRA    L_ADDC_02, Z            ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R1                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                ADDC    R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_ADDC_01, !Z           ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_ADDC_01, Z
                HALT
E_ADDC_01       HALT

STIM_ADDC       .DW     0x1234, 0x4321, ST______, 0x5555, ST______
                .DW     0x1234, 0x9876, ST______, 0xAAAA, ST__N___
                .DW     0x7654, 0x6543, ST______, 0xDB97, ST_VN___
                .DW     0x8765, 0x9876, ST______, 0x1FDB, ST_V__C_
                .DW     0xFEDC, 0x0123, ST______, 0xFFFF, ST__N__X
                .DW     0xFEDC, 0x0124, ST______, 0x0000, ST___ZC_
                .DW     0xFEDC, 0xEDCB, ST______, 0xECA7, ST__N_C_

                .DW     0x1234, 0x4321, ST____C_, 0x5556, ST______
                .DW     0x1234, 0x9876, ST____C_, 0xAAAB, ST__N___
                .DW     0x7654, 0x6543, ST____C_, 0xDB98, ST_VN___
                .DW     0x8765, 0x9876, ST____C_, 0x1FDC, ST_V__C_
                .DW     0xFEDC, 0x0122, ST____C_, 0xFFFF, ST__N__X
                .DW     0xFEDC, 0x0123, ST____C_, 0x0000, ST___ZC_
                .DW     0xFEDC, 0xEDCB, ST____C_, 0xECA8, ST__N_C_

                .DW     0x0000

L_ADDC_02


; ---------------------------------------------------------------------------
; Test the SUB instruction

L_SUB_00        MOVE    STIM_SUB, R8
L_SUB_01        MOVE    @R8, R1                 ; Dst operand (= minuend)
                RBRA    L_SUB_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Src operand (= subtrahend)
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                SUB     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_SUB_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_SUB_01, Z
                HALT
E_SUB_01        HALT

; See Issue #57
;STIM_SUB        .DW     0x5678, 0x4321, ST______, 0x1357, ST______
;                .DW     0x5678, 0x5678, ST____C_, 0x0000, ST___Z__
;                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST__N_CX
;                .DW     0x5678, 0x89AB, ST____C_, 0xCCCD, ST_VN_C_
;                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
;                .DW     0x89AB, 0x4321, ST____C_, 0x468A, ST_V____

STIM_SUB        .DW     0x5678, 0x4321, ST______, 0x1357, ST______
                .DW     0x5678, 0x5678, ST____C_, 0x0000, ST___Z__
                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST_VN_CX
                .DW     0x5678, 0x89AB, ST____C_, 0xCCCD, ST__N_C_
                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
                .DW     0x89AB, 0x4321, ST____C_, 0x468A, ST______

                .DW     0x0000

L_SUB_02


; ---------------------------------------------------------------------------
; Test the SUBC instruction

L_SUBC_00       MOVE    STIM_SUBC, R8
L_SUBC_01       MOVE    @R8, R1                 ; Dst operand (= minuend)
                RBRA    L_SUBC_02, Z            ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Src operand (= subtrahend)
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                SUBC    R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_SUBC_01, !Z           ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_SUBC_01, Z
                HALT
E_SUBC_01       HALT

; See Issue #57
;STIM_SUBC       .DW     0x5678, 0x4321, ST______, 0x1357, ST______
;                .DW     0x5678, 0x5678, ST______, 0x0000, ST___Z__
;                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST__N_CX
;                .DW     0x5678, 0x89AB, ST______, 0xCCCD, ST_VN_C_
;                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
;                .DW     0x89AB, 0x4321, ST______, 0x468A, ST_V____
;
;                .DW     0x5678, 0x4321, ST____C_, 0x1356, ST______
;                .DW     0x5678, 0x5678, ST____C_, 0xFFFF, ST__N_CX
;                .DW     0x5678, 0x5677, ST____C_, 0x0000, ST___Z__
;                .DW     0x5678, 0x89AB, ST____C_, 0xCCCC, ST_VN_C_
;                .DW     0x5678, 0xFEDC, ST____C_, 0x579B, ST____C_
;                .DW     0x89AB, 0x4321, ST____C_, 0x4689, ST_V____

STIM_SUBC       .DW     0x5678, 0x4321, ST______, 0x1357, ST______
                .DW     0x5678, 0x5678, ST______, 0x0000, ST___Z__
                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST_VN_CX
                .DW     0x5678, 0x89AB, ST______, 0xCCCD, ST__N_C_
                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
                .DW     0x89AB, 0x4321, ST______, 0x468A, ST______

                .DW     0x5678, 0x4321, ST____C_, 0x1356, ST______
                .DW     0x5678, 0x5678, ST____C_, 0xFFFF, ST_VN_CX
                .DW     0x5678, 0x5677, ST____C_, 0x0000, ST___Z__
                .DW     0x5678, 0x89AB, ST____C_, 0xCCCC, ST__N_C_
                .DW     0x5678, 0xFEDC, ST____C_, 0x579B, ST____C_
                .DW     0x89AB, 0x4321, ST____C_, 0x4689, ST______

                .DW     0x0000

L_SUBC_02


; ---------------------------------------------------------------------------
; Test the SHL instruction

L_SHL_00        MOVE    STIM_SHL, R8
L_SHL_01        MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_SHL_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                SHL     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_SHL_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_SHL_01, Z
                HALT
E_SHL_01        HALT

STIM_SHL
; X = 0, all other flags = 0
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x5678, 0x0000, ST______, 0x5678, ST______
                .DW     0x5678, 0x0001, ST______, 0xACF0, ST__N___
                .DW     0x5678, 0x0002, ST______, 0x59E0, ST____C_
                .DW     0x5678, 0x0003, ST______, 0xB3C0, ST__N___
                .DW     0x5678, 0x0004, ST______, 0x6780, ST____C_
                .DW     0x5678, 0x0005, ST______, 0xCF00, ST__N___
                .DW     0x5678, 0x000F, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0x000F, ST______, 0x8000, ST__N_C_
                .DW     0xFFFF, 0x0010, ST______, 0x0000, ST___ZC_
                .DW     0xFFFF, 0x0011, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0x8000, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFF0, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFF8, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFFC, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFFE, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFFF, ST______, 0x0000, ST___Z__

; X = 0, all other flags = 1
                .DW     0x0000, 0x0000, ST_VNZC_, 0x0000, ST_V_ZC_
                .DW     0x5678, 0x0000, ST_VNZC_, 0x5678, ST_V__C_   ; C is unchanged when shifting zero bits
                .DW     0x5678, 0x0001, ST_VNZC_, 0xACF0, ST_VN___
                .DW     0x5678, 0x0002, ST_VNZC_, 0x59E0, ST_V__C_
                .DW     0x5678, 0x0003, ST_VNZC_, 0xB3C0, ST_VN___
                .DW     0x5678, 0x0004, ST_VNZC_, 0x6780, ST_V__C_
                .DW     0x5678, 0x0005, ST_VNZC_, 0xCF00, ST_VN___
                .DW     0x5678, 0x000F, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0x000F, ST_VNZC_, 0x8000, ST_VN_C_
                .DW     0xFFFF, 0x0010, ST_VNZC_, 0x0000, ST_V_ZC_
                .DW     0xFFFF, 0x0011, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0x8000, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0xFFF0, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0xFFF8, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0xFFFC, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0xFFFE, ST_VNZC_, 0x0000, ST_V_Z__
                .DW     0xFFFF, 0xFFFF, ST_VNZC_, 0x0000, ST_V_Z__

; X = 1, all other flags = 0
                .DW     0x0000, 0x0000, ST_____X, 0x0000, ST___Z_X
                .DW     0x5678, 0x0000, ST_____X, 0x5678, ST_____X
                .DW     0x5678, 0x0001, ST_____X, 0xACF1, ST__N__X
                .DW     0x5678, 0x0002, ST_____X, 0x59E3, ST____CX
                .DW     0x5678, 0x0003, ST_____X, 0xB3C7, ST__N__X
                .DW     0x5678, 0x0004, ST_____X, 0x678F, ST____CX
                .DW     0x5678, 0x0005, ST_____X, 0xCF1F, ST__N__X
                .DW     0x5678, 0x000F, ST_____X, 0x7FFF, ST_____X
                .DW     0xFFFF, 0x000F, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0x0010, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0x0011, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0x8000, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0xFFF0, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0xFFF8, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0xFFFC, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0xFFFE, ST_____X, 0xFFFF, ST__N_CX
                .DW     0xFFFF, 0xFFFF, ST_____X, 0xFFFF, ST__N_CX

; X = 1, all other flags = 1
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZCX
                .DW     0x5678, 0x0000, ST_VNZCX, 0x5678, ST_V__CX   ; C is unchanged when shifting zero bits
                .DW     0x5678, 0x0001, ST_VNZCX, 0xACF1, ST_VN__X
                .DW     0x5678, 0x0002, ST_VNZCX, 0x59E3, ST_V__CX
                .DW     0x5678, 0x0003, ST_VNZCX, 0xB3C7, ST_VN__X
                .DW     0x5678, 0x0004, ST_VNZCX, 0x678F, ST_V__CX
                .DW     0x5678, 0x0005, ST_VNZCX, 0xCF1F, ST_VN__X
                .DW     0x5678, 0x000F, ST_VNZCX, 0x7FFF, ST_V___X
                .DW     0xFFFF, 0x000F, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0x0010, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0x0011, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0x8000, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFF0, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFF8, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFFC, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFFE, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX

                .DW     0x1111

L_SHL_02


; ---------------------------------------------------------------------------
; Test the SHR instruction

L_SHR_00        MOVE    STIM_SHR, R8
L_SHR_01        MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_SHR_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                SHR     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_SHR_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_SHR_01, Z
                HALT
E_SHR_01        HALT

STIM_SHR
; C = 0, all other flags = 0
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0x0000, ST______, 0x8765, ST__N___
                .DW     0x8765, 0x0001, ST______, 0x43B2, ST_____X
                .DW     0x8765, 0x0002, ST______, 0x21D9, ST______
                .DW     0x8765, 0x0003, ST______, 0x10EC, ST_____X
                .DW     0x8765, 0x0004, ST______, 0x0876, ST______
                .DW     0x8765, 0x0005, ST______, 0x043B, ST______
                .DW     0x8765, 0x000F, ST______, 0x0001, ST______
                .DW     0x8765, 0x0010, ST______, 0x0000, ST___Z_X
                .DW     0x8765, 0x0011, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0x8000, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0xFFF0, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0xFFF8, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0xFFFC, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0xFFFE, ST______, 0x0000, ST___Z__
                .DW     0x8765, 0xFFFF, ST______, 0x0000, ST___Z__
; C = 0, all other flags = 1
                .DW     0x0000, 0x0000, ST_VNZ_X, 0x0000, ST_V_Z_X
                .DW     0x8765, 0x0000, ST_VNZ_X, 0x8765, ST_VN__X    ; X is unchanged when shifting zero bits
                .DW     0x8765, 0x0001, ST_VNZ_X, 0x43B2, ST_V___X
                .DW     0x8765, 0x0002, ST_VNZ_X, 0x21D9, ST_V____
                .DW     0x8765, 0x0003, ST_VNZ_X, 0x10EC, ST_V___X
                .DW     0x8765, 0x0004, ST_VNZ_X, 0x0876, ST_V____
                .DW     0x8765, 0x0005, ST_VNZ_X, 0x043B, ST_V____
                .DW     0x8765, 0x000F, ST_VNZ_X, 0x0001, ST_V____
                .DW     0x8765, 0x0010, ST_VNZ_X, 0x0000, ST_V_Z_X
                .DW     0x8765, 0x0011, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0x8000, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0xFFF0, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0xFFF8, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0xFFFC, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0xFFFE, ST_VNZ_X, 0x0000, ST_V_Z__
                .DW     0x8765, 0xFFFF, ST_VNZ_X, 0x0000, ST_V_Z__
; C = 1, all other flags = 0
                .DW     0x0000, 0x0000, ST____C_, 0x0000, ST___ZC_ 
                .DW     0x8765, 0x0000, ST____C_, 0x8765, ST__N_C_
                .DW     0x8765, 0x0001, ST____C_, 0xC3B2, ST__N_CX
                .DW     0x8765, 0x0002, ST____C_, 0xE1D9, ST__N_C_
                .DW     0x8765, 0x0003, ST____C_, 0xF0EC, ST__N_CX
                .DW     0x8765, 0x0004, ST____C_, 0xF876, ST__N_C_
                .DW     0x8765, 0x0005, ST____C_, 0xFC3B, ST__N_C_
                .DW     0x8765, 0x000F, ST____C_, 0xFFFF, ST__N_C_
                .DW     0x8765, 0x0010, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0x0011, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0x8000, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0xFFF0, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0xFFF8, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0xFFFC, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0xFFFE, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x8765, 0xFFFF, ST____C_, 0xFFFF, ST__N_CX
; C = 1, all other flags = 1
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZCX
                .DW     0x8765, 0x0000, ST_VNZCX, 0x8765, ST_VN_CX   ; X is unchanged when shifting zero bits
                .DW     0x8765, 0x0001, ST_VNZCX, 0xC3B2, ST_VN_CX
                .DW     0x8765, 0x0002, ST_VNZCX, 0xE1D9, ST_VN_C_
                .DW     0x8765, 0x0003, ST_VNZCX, 0xF0EC, ST_VN_CX
                .DW     0x8765, 0x0004, ST_VNZCX, 0xF876, ST_VN_C_
                .DW     0x8765, 0x0005, ST_VNZCX, 0xFC3B, ST_VN_C_
                .DW     0x8765, 0x000F, ST_VNZCX, 0xFFFF, ST_VN_C_
                .DW     0x8765, 0x0010, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0x0011, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0x8000, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0xFFF0, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0xFFF8, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0xFFFC, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0xFFFE, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8765, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX

                .DW     0x1111

L_SHR_02


; ---------------------------------------------------------------------------
; Test the SWAP instruction

L_SWAP_00       MOVE    STIM_SWAP, R8
L_SWAP_01       MOVE    @R8, R0                 ; First operand
                CMP     0x1111, R0
                RBRA    L_SWAP_02, Z            ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                SWAP    R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_SWAP_01, !Z           ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_SWAP_01, Z
                HALT
E_SWAP_01       HALT

STIM_SWAP

                .DW     0x8765, ST______, 0x6587, ST______
                .DW     0x8765, ST_VNZCX, 0x6587, ST_V__C_
                .DW     0x6587, ST______, 0x8765, ST__N___
                .DW     0x6587, ST_VNZCX, 0x8765, ST_VN_C_
                .DW     0x0000, ST______, 0x0000, ST___Z__
                .DW     0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0xFFFF, ST______, 0xFFFF, ST__N__X
                .DW     0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX

                .DW     0x1111

L_SWAP_02


; ---------------------------------------------------------------------------
; Test the NOT instruction

L_NOT_00        MOVE    STIM_NOT, R8
L_NOT_01        MOVE    @R8, R0                 ; First operand
                CMP     0x1111, R0
                RBRA    L_NOT_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                NOT     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_NOT_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_NOT_01, Z
                HALT
E_NOT_01        HALT

STIM_NOT

                .DW     0x8765, ST______, 0x789A, ST______
                .DW     0x8765, ST_VNZCX, 0x789A, ST_V__C_
                .DW     0x6587, ST______, 0x9A78, ST__N___
                .DW     0x6587, ST_VNZCX, 0x9A78, ST_VN_C_
                .DW     0x0000, ST______, 0xFFFF, ST__N__X
                .DW     0x0000, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, ST_VNZCX, 0x0000, ST_V_ZC_

                .DW     0x1111

L_NOT_02


; ---------------------------------------------------------------------------
; Test the AND instruction

L_AND_00        MOVE    STIM_AND, R8
L_AND_01        MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_AND_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                AND     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_AND_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_AND_01, Z
                HALT
E_AND_01        HALT

STIM_AND        .DW     0x5678, 0x4321, ST______, 0x4220, ST______
                .DW     0xFFFF, 0x4321, ST______, 0x4321, ST______
                .DW     0x4321, 0xFFFF, ST______, 0x4321, ST______
                .DW     0x0000, 0x4321, ST______, 0x0000, ST___Z__
                .DW     0x4321, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0xFFFF, 0xFFFF, ST______, 0xFFFF, ST__N__X
                .DW     0xFFFF, 0xFFFF, ST______, 0xFFFF, ST__N__X
                .DW     0x8000, 0xFFFF, ST______, 0x8000, ST__N___
                .DW     0xFFFF, 0x8000, ST______, 0x8000, ST__N___

                .DW     0x5678, 0x4321, ST_VNZCX, 0x4220, ST_V__C_
                .DW     0xFFFF, 0x4321, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0x4321, 0xFFFF, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0x0000, 0x4321, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0x4321, 0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0xFFFF, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0xFFFF, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8000, 0xFFFF, ST_VNZCX, 0x8000, ST_VN_C_
                .DW     0xFFFF, 0x8000, ST_VNZCX, 0x8000, ST_VN_C_

                .DW     0x1111

L_AND_02


; ---------------------------------------------------------------------------
; Test the OR instruction

L_OR_00         MOVE    STIM_OR, R8
L_OR_01         MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_OR_02, Z              ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                OR      R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_OR_01, !Z             ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_OR_01, Z
                HALT
E_OR_01         HALT

STIM_OR         .DW     0x5678, 0x4321, ST______, 0x5779, ST______
                .DW     0x0000, 0x4321, ST______, 0x4321, ST______
                .DW     0x4321, 0x0000, ST______, 0x4321, ST______
                .DW     0xFFFF, 0x4321, ST______, 0xFFFF, ST__N__X
                .DW     0x4321, 0xFFFF, ST______, 0xFFFF, ST__N__X
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x8000, 0x0000, ST______, 0x8000, ST__N___
                .DW     0x0000, 0x8000, ST______, 0x8000, ST__N___

                .DW     0x5678, 0x4321, ST_VNZCX, 0x5779, ST_V__C_
                .DW     0x0000, 0x4321, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0x4321, 0x0000, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0xFFFF, 0x4321, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x4321, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0x8000, 0x0000, ST_VNZCX, 0x8000, ST_VN_C_
                .DW     0x0000, 0x8000, ST_VNZCX, 0x8000, ST_VN_C_

                .DW     0x1111

L_OR_02


; ---------------------------------------------------------------------------
; Test the XOR instruction

L_XOR_00        MOVE    STIM_XOR, R8
L_XOR_01        MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_XOR_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                XOR     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_XOR_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_XOR_01, Z
                HALT
E_XOR_01        HALT

STIM_XOR        .DW     0x5678, 0x4321, ST______, 0x1559, ST______
                .DW     0x0000, 0x4321, ST______, 0x4321, ST______
                .DW     0x4321, 0x0000, ST______, 0x4321, ST______
                .DW     0xFFFF, 0x4321, ST______, 0xBCDE, ST__N___
                .DW     0x4321, 0xFFFF, ST______, 0xBCDE, ST__N___
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x0000, 0x0000, ST______, 0x0000, ST___Z__
                .DW     0x7777, 0x8888, ST______, 0xFFFF, ST__N__X
                .DW     0x8888, 0x7777, ST______, 0xFFFF, ST__N__X
                .DW     0x8000, 0x0000, ST______, 0x8000, ST__N___
                .DW     0x0000, 0x8000, ST______, 0x8000, ST__N___

                .DW     0x5678, 0x4321, ST_VNZCX, 0x1559, ST_V__C_
                .DW     0x0000, 0x4321, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0x4321, 0x0000, ST_VNZCX, 0x4321, ST_V__C_
                .DW     0xFFFF, 0x4321, ST_VNZCX, 0xBCDE, ST_VN_C_
                .DW     0x4321, 0xFFFF, ST_VNZCX, 0xBCDE, ST_VN_C_
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0x0000, 0x0000, ST_VNZCX, 0x0000, ST_V_ZC_
                .DW     0x7777, 0x8888, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8888, 0x7777, ST_VNZCX, 0xFFFF, ST_VN_CX
                .DW     0x8000, 0x0000, ST_VNZCX, 0x8000, ST_VN_C_
                .DW     0x0000, 0x8000, ST_VNZCX, 0x8000, ST_VN_C_

                .DW     0x1111

L_XOR_02


; ---------------------------------------------------------------------------
; Test the CMP instruction

L_CMP_00        MOVE    STIM_CMP, R8
L_CMP_01        MOVE    @R8, R1                 ; First operand
                CMP     0x1111, R1
                RBRA    L_CMP_02, Z             ; End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 ; Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 ; Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 ; Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 ; Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 ; Set carry input
                CMP     R0, R1
                MOVE    R14, R9                 ; Copy status
                CMP     R1, R3                  ; Verify expected result
                RBRA    E_CMP_01, !Z            ; Jump if error
                CMP     R9, R4                  ; Verify expected status
                RBRA    L_CMP_01, Z
                HALT
E_CMP_01        HALT

; See Issue #57
;STIM_CMP        .DW     0x5678, 0x4321, ST______, 0x5678, ST______
;                .DW     0x5678, 0x5678, ST______, 0x5678, ST___Z__
;                .DW     0x5678, 0x5679, ST______, 0x5678, ST__N_CX
;                .DW     0x5678, 0x89AB, ST______, 0x5678, ST_VN_C_
;                .DW     0x5678, 0xFEDC, ST______, 0x5678, ST____C_
;                .DW     0x89AB, 0x4321, ST______, 0x89AB, ST_V____
;
;                .DW     0x5678, 0x4321, ST_VNZCX, 0x5678, ST______
;                .DW     0x5678, 0x5678, ST_VNZCX, 0x5678, ST___Z__
;                .DW     0x5678, 0x5679, ST_VNZCX, 0x5678, ST__N_CX
;                .DW     0x5678, 0x89AB, ST_VNZCX, 0x5678, ST_VN_C_
;                .DW     0x5678, 0xFEDC, ST_VNZCX, 0x5678, ST____C_
;                .DW     0x89AB, 0x4321, ST_VNZCX, 0x89AB, ST_V____

STIM_CMP        .DW     0x5678, 0x4321, ST______, 0x5678, ST______
                .DW     0x5678, 0x5678, ST______, 0x5678, ST___Z__
                .DW     0x5678, 0x5679, ST______, 0x5678, ST_VN___
                .DW     0x5678, 0x89AB, ST______, 0x5678, ST__N___
                .DW     0x5678, 0xFEDC, ST______, 0x5678, ST__N___
                .DW     0x89AB, 0x4321, ST______, 0x89AB, ST_V____

                .DW     0x5678, 0x4321, ST_VNZCX, 0x5678, ST____CX
                .DW     0x5678, 0x5678, ST_VNZCX, 0x5678, ST___ZCX
                .DW     0x5678, 0x5679, ST_VNZCX, 0x5678, ST_VN_CX
                .DW     0x5678, 0x89AB, ST_VNZCX, 0x5678, ST__N_CX
                .DW     0x5678, 0xFEDC, ST_VNZCX, 0x5678, ST__N_CX
                .DW     0x89AB, 0x4321, ST_VNZCX, 0x89AB, ST_V__CX

                .DW     0x1111

L_CMP_02


; ---------------------------------------------------------------------------
; Test the MOVE instruction with all addressing modes

; MOVE R1, @R2
; MOVE @R2, R1
; MOVE @R2++, R1
; MOVE @--R2, R1
L_MOVE_AM_00    MOVE    0x1234, R1
                MOVE    AM_BSS, R2
                MOVE    R1, @R2                 ; Store R1 into @R2
                CMP     R1, 0x1234              ; Verify R1 unchanged
                RBRA    E_MOVE_AM_01, !Z        ; Jump if error
                CMP     R2, AM_BSS              ; Verify R2 unchanged
                RBRA    E_MOVE_AM_02, !Z        ; Jump if error

                MOVE    0x0000, R1              ; Clear R1
                MOVE    @R2, R1                 ; Read R1 from @R2
                CMP     R1, 0x1234              ; Verify correct value read
                RBRA    E_MOVE_AM_03, !Z        ; Jump if error
                CMP     R2, AM_BSS              ; Verify R2 unchanged
                RBRA    E_MOVE_AM_04, !Z        ; Jump if error

                MOVE    0x0000, R1              ; Clear R1
                MOVE    @R2++, R1               ; Read R1 from @R2 and increment R2
                CMP     R1, 0x1234              ; Verify correct value read
                RBRA    E_MOVE_AM_05, !Z        ; Jump if error
                CMP     R2, AM_BSS1             ; Verify R2 incremented
                RBRA    E_MOVE_AM_06, !Z        ; Jump if error

                MOVE    0x0000, R1              ; Clear R1
                MOVE    @--R2, R1               ; Decrement R2 and read R1 from @R2
                CMP     R1, 0x1234              ; Verify correct value read
                RBRA    E_MOVE_AM_07, !Z        ; Jump if error
                CMP     R2, AM_BSS              ; Verify R2 decremented
                RBRA    E_MOVE_AM_08, !Z        ; Jump if error

                RBRA    L_MOVE_AM_01, 1
E_MOVE_AM_01    HALT
E_MOVE_AM_02    HALT
E_MOVE_AM_03    HALT
E_MOVE_AM_04    HALT
E_MOVE_AM_05    HALT
E_MOVE_AM_06    HALT
E_MOVE_AM_07    HALT
E_MOVE_AM_08    HALT
AM_BSS          .DW     0x0000
AM_BSS1         .DW     0x0000
AM_BSS2         .DW     0x0000
AM_BSS3         .DW     0x0000
L_MOVE_AM_01

; MOVE R1, @R2++
; MOVE R1, @--R2
L_MOVE_AM_10
                MOVE    0x1234, R1
                MOVE    AM_BSS, R3
                MOVE    AM_BSS1, R4
                MOVE    R1, @R3                 ; Store dummy value into @R3
                MOVE    R1, @R4                 ; Store dummy value into @R4

                MOVE    0x4321, R0
                MOVE    AM_BSS, R2

                MOVE    R0, @R2++               ; Store R0 into @R2 and increment R2
                CMP     R0, 0x4321              ; Verify R0 unchanged
                RBRA    E_MOVE_AM_11, !Z        ; Jump if error
                CMP     R2, AM_BSS1             ; Verify R2 incremented
                RBRA    E_MOVE_AM_12, !Z        ; Jump if error

                MOVE    @R3, R8                 ; Read back value stored in @R3
                CMP     R8, R0                  ; Verify value was correctly written
                RBRA    E_MOVE_AM_13, !Z        ; Jump if error

                MOVE    @R4, R8                 ; Read back value stored in @R4
                CMP     R8, R1                  ; Verify value was unchanged
                RBRA    E_MOVE_AM_14, !Z        ; Jump if error

                MOVE    0x5678, R0
                MOVE    R0, @--R2               ; Decrement R2 and store R0 into @R2
                CMP     R0, 0x5678              ; Verify R0 unchanged
                RBRA    E_MOVE_AM_15, !Z        ; Jump if error
                CMP     R2, AM_BSS              ; Verify R2 decremented
                RBRA    E_MOVE_AM_16, !Z        ; Jump if error

                MOVE    @R3, R8                 ; Read back value stored in @R3
                CMP     R8, R0                  ; Verify value was correctly written
                RBRA    E_MOVE_AM_17, !Z        ; Jump if error

                MOVE    @R4, R8                 ; Read back value stored in @R4
                CMP     R8, R1                  ; Verify value was unchanged
                RBRA    E_MOVE_AM_18, !Z        ; Jump if error

                RBRA    L_MOVE_AM_11, 1
E_MOVE_AM_11    HALT
E_MOVE_AM_12    HALT
E_MOVE_AM_13    HALT
E_MOVE_AM_14    HALT
E_MOVE_AM_15    HALT
E_MOVE_AM_16    HALT
E_MOVE_AM_17    HALT
E_MOVE_AM_18    HALT
L_MOVE_AM_11

; MOVE @R1, @R2
L_MOVE_AM_20
                MOVE    0x2345, R0
                MOVE    AM_BSS, R3
                MOVE    R0, @R3                 ; Store dummy value into @R3
                MOVE    0x5432, R0
                MOVE    AM_BSS2, R4
                MOVE    R0, @R4                 ; Store dummy value into @R4

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2

                MOVE    @R1, @R2                ; Copy @R1 to @R2

                CMP     R1, AM_BSS              ; Verify R1 unchanged
                RBRA    E_MOVE_AM_21, !Z        ; Jump if error
                CMP     R2, AM_BSS2             ; Verify R2 unchanged
                RBRA    E_MOVE_AM_22, !Z        ; Jump if error

                MOVE    @R3, R8                 ; Read from AM_BSS
                CMP     R8, 0x2345              ; Verify unchanged
                RBRA    E_MOVE_AM_23, !Z        ; Jump if error
                MOVE    @R4, R8                 ; Read from AM_BSS1
                CMP     R8, 0x2345              ; Verify correct value written
                RBRA    E_MOVE_AM_24, !Z        ; Jump if error
                RBRA    L_MOVE_AM_21, 1
E_MOVE_AM_21    HALT
E_MOVE_AM_22    HALT
E_MOVE_AM_23    HALT
E_MOVE_AM_24    HALT
L_MOVE_AM_21

; MOVE @R1, @R2++
; MOVE @R1, @--R2
L_MOVE_AM_30
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x3456, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x6543, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    R0, @R7                 ; Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1, @R2++              ; Copy @R1 to @R2 and increment R2

                CMP     R1, R4                  ; Verify R1 unchanged
                RBRA    E_MOVE_AM_31, !Z        ; Jump if error
                CMP     R2, R7                  ; Verify R2 incremented
                RBRA    E_MOVE_AM_32, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_33, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x3456              ; Verify correct value
                RBRA    E_MOVE_AM_34, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_345, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x3456              ; Verify correct value
                RBRA    E_MOVE_AM_35, !Z        ; Jump if error

                MOVE    0x6543, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    @R1, @--R2              ; Decrement R2 and copy @R1 to @R2

                CMP     R1, R4                  ; Verify R1 unchanged
                RBRA    E_MOVE_AM_36, !Z        ; Jump if error
                CMP     R2, R6                  ; Verify R2 decremented
                RBRA    E_MOVE_AM_37, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_38, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x6543              ; Verify correct value
                RBRA    E_MOVE_AM_39, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_395, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x6543              ; Verify correct value
                RBRA    E_MOVE_AM_399, !Z       ; Jump if error

                RBRA    L_MOVE_AM_31, 1
E_MOVE_AM_31    HALT
E_MOVE_AM_32    HALT
E_MOVE_AM_33    HALT
E_MOVE_AM_34    HALT
E_MOVE_AM_345   HALT
E_MOVE_AM_35    HALT
E_MOVE_AM_36    HALT
E_MOVE_AM_37    HALT
E_MOVE_AM_38    HALT
E_MOVE_AM_39    HALT
E_MOVE_AM_395   HALT
E_MOVE_AM_399   HALT
L_MOVE_AM_31

; MOVE @R1++, @R2
; MOVE @--R1, @R2
L_MOVE_AM_40
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x4567, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x7654, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    R0, @R7                 ; Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1++, @R2              ; Copy @R1 to @R2 and increment R1

                CMP     R1, R5                  ; Verify R1 incremented
                RBRA    E_MOVE_AM_41, !Z        ; Jump if error
                CMP     R2, R6                  ; Verify R2 unchanged
                RBRA    E_MOVE_AM_42, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_43, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x4567              ; Verify correct value
                RBRA    E_MOVE_AM_44, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_445, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x4567              ; Verify correct value
                RBRA    E_MOVE_AM_45, !Z        ; Jump if error

                MOVE    0x7654, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    @--R1, @R2              ; Decrement R1 and copy @R1 to @R2

                CMP     R1, R4                  ; Verify R1 decremented
                RBRA    E_MOVE_AM_46, !Z        ; Jump if error
                CMP     R2, R6                  ; Verify R2 unchanged
                RBRA    E_MOVE_AM_47, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_48, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x7654              ; Verify correct value
                RBRA    E_MOVE_AM_49, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_495, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x7654              ; Verify correct value
                RBRA    E_MOVE_AM_499, !Z       ; Jump if error

                RBRA    L_MOVE_AM_41, 1
E_MOVE_AM_41    HALT
E_MOVE_AM_42    HALT
E_MOVE_AM_43    HALT
E_MOVE_AM_44    HALT
E_MOVE_AM_445   HALT
E_MOVE_AM_45    HALT
E_MOVE_AM_46    HALT
E_MOVE_AM_47    HALT
E_MOVE_AM_48    HALT
E_MOVE_AM_49    HALT
E_MOVE_AM_495   HALT
E_MOVE_AM_499   HALT
L_MOVE_AM_41


; MOVE @R1++, @R2++
; MOVE @--R1, @--R2
L_MOVE_AM_50
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x5678, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x8765, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    R0, @R7                 ; Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1++, @R2++            ; Copy @R1 to @R2 and increment R1 and R2

                CMP     R1, R5                  ; Verify R1 incremented
                RBRA    E_MOVE_AM_51, !Z        ; Jump if error
                CMP     R2, R7                  ; Verify R2 incremented
                RBRA    E_MOVE_AM_52, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_53, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x5678              ; Verify correct value
                RBRA    E_MOVE_AM_54, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_545, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x5678              ; Verify correct value
                RBRA    E_MOVE_AM_55, !Z        ; Jump if error

                MOVE    0x8765, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    @--R1, @--R2            ; Decrement R1 and R2 and copy @R1 to @R2

                CMP     R1, R4                  ; Verify R1 decremented
                RBRA    E_MOVE_AM_56, !Z        ; Jump if error
                CMP     R2, R6                  ; Verify R2 decremented
                RBRA    E_MOVE_AM_57, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_58, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x8765              ; Verify correct value
                RBRA    E_MOVE_AM_59, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_595, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x8765              ; Verify correct value
                RBRA    E_MOVE_AM_599, !Z       ; Jump if error

                RBRA    L_MOVE_AM_51, 1
E_MOVE_AM_51    HALT
E_MOVE_AM_52    HALT
E_MOVE_AM_53    HALT
E_MOVE_AM_54    HALT
E_MOVE_AM_545   HALT
E_MOVE_AM_55    HALT
E_MOVE_AM_56    HALT
E_MOVE_AM_57    HALT
E_MOVE_AM_58    HALT
E_MOVE_AM_59    HALT
E_MOVE_AM_595   HALT
E_MOVE_AM_599   HALT
L_MOVE_AM_51

; MOVE @R1++, @--R2
; MOVE @--R1, @R2++

L_MOVE_AM_60
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x6789, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x9876, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    R0, @R7                 ; Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS3, R2
                MOVE    @R1++, @--R2            ; Decrement R2, copy @R1 to @R2 and increment R1

                CMP     R1, R5                  ; Verify R1 incremented
                RBRA    E_MOVE_AM_61, !Z        ; Jump if error
                CMP     R2, R6                  ; Verify R2 decremented
                RBRA    E_MOVE_AM_62, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_63, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x6789              ; Verify correct value
                RBRA    E_MOVE_AM_64, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_645, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x6789              ; Verify correct value
                RBRA    E_MOVE_AM_65, !Z        ; Jump if error

                MOVE    0x9876, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    @--R1, @R2++            ; Decrement R1 and copy @R1 to @R2 and increment R2

                CMP     R1, R4                  ; Verify R1 decremented
                RBRA    E_MOVE_AM_66, !Z        ; Jump if error
                CMP     R2, R7                  ; Verify R2 incremented
                RBRA    E_MOVE_AM_67, !Z        ; Jump if error

                MOVE    @R7, R0                 ; Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_68, !Z        ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x9876              ; Verify correct value
                RBRA    E_MOVE_AM_69, !Z        ; Jump if error
                MOVE    @R5, R0                 ; Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_695, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x9876              ; Verify correct value
                RBRA    E_MOVE_AM_699, !Z       ; Jump if error

                RBRA    L_MOVE_AM_61, 1
E_MOVE_AM_61    HALT
E_MOVE_AM_62    HALT
E_MOVE_AM_63    HALT
E_MOVE_AM_64    HALT
E_MOVE_AM_645   HALT
E_MOVE_AM_65    HALT
E_MOVE_AM_66    HALT
E_MOVE_AM_67    HALT
E_MOVE_AM_68    HALT
E_MOVE_AM_69    HALT
E_MOVE_AM_695   HALT
E_MOVE_AM_699   HALT
L_MOVE_AM_61


; ---------------------------------------------------------------------------
; Test the MOVE instruction with all addressing modes, where source and
; destination registers are the same

; MOVE @R1, R1
; MOVE R1, @R1

L_MOVE_AM2_00
                MOVE    AM_BSS, R4
                MOVE    0x3456, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS

                MOVE    AM_BSS, R1
                MOVE    @R1, R1                 ; Copy @R1 to R1

                CMP     R1, 0x3456              ; Verify correct value read
                RBRA    E_MOVE_AM2_01, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x3456              ; Verify correct value
                RBRA    E_MOVE_AM2_02, !Z       ; Jump if error

                MOVE    AM_BSS, R1
                MOVE    R1, @R1                 ; Copy R1 to @R1

                CMP     R1, AM_BSS              ; Verify R1 unchanged
                RBRA    E_MOVE_AM2_03, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, AM_BSS              ; Verify correct value
                RBRA    E_MOVE_AM2_04, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_01, 1
E_MOVE_AM2_01   HALT
E_MOVE_AM2_02   HALT
E_MOVE_AM2_03   HALT
E_MOVE_AM2_04   HALT
L_MOVE_AM2_01

; MOVE @--R1, R1
; MOVE R1, @R1++

L_MOVE_AM2_10
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x3456, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x6543, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1

                MOVE    AM_BSS1, R1
                MOVE    @--R1, R1               ; Decrement R1, and copy @R1 to R1

                CMP     R1, 0x3456              ; Verify correct value
                RBRA    E_MOVE_AM2_11, !Z       ; Jump if error

                MOVE    AM_BSS, R1
                MOVE    R1, @R1++               ; Copy R1 to @R1 and increment R1

                CMP     R1, AM_BSS1             ; Verify R1 incremented
                RBRA    E_MOVE_AM2_12, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, AM_BSS              ; Verify correct value
                RBRA    E_MOVE_AM2_13, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_11, 1
E_MOVE_AM2_11   HALT
E_MOVE_AM2_12   HALT
E_MOVE_AM2_13   HALT
L_MOVE_AM2_11

; MOVE @R1++, R1
; MOVE R1, @--R1

L_MOVE_AM2_20
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x4567, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x7654, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1

                MOVE    AM_BSS, R1
                MOVE    @R1++, R1               ; Copy @R1 to R1

                CMP     R1, 0x4567              ; Verify correct value
                RBRA    E_MOVE_AM2_21, !Z       ; Jump if error

                MOVE    AM_BSS1, R1
                MOVE    R1, @--R1               ; Copy R1 to @(R1-1) and decrement R1

                CMP     R1, AM_BSS              ; Verify R1 decremented
                RBRA    E_MOVE_AM2_22, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, AM_BSS1             ; Verify correct value
                RBRA    E_MOVE_AM2_23, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_21, 1
E_MOVE_AM2_21   HALT
E_MOVE_AM2_22   HALT
E_MOVE_AM2_23   HALT
L_MOVE_AM2_21

; MOVE @R1, @R1++
; MOVE @--R1, @R1

L_MOVE_AM2_30
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x5678, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x8765, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1

                MOVE    AM_BSS, R1
                MOVE    @R1, @R1++              ; Copy @R1 to @R1++

                CMP     R1, AM_BSS1             ; Verify R1 incremented
                RBRA    E_MOVE_AM2_31, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x8765              ; Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       ; Jump if error

                MOVE    AM_BSS1, R1
                MOVE    @--R1, @R1              ; Copy @--R1 to @R1

                CMP     R1, AM_BSS              ; Verify R1 decremented
                RBRA    E_MOVE_AM2_34, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x8765              ; Verify value unchanged
                RBRA    E_MOVE_AM2_36, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_31, 1
E_MOVE_AM2_31   HALT
E_MOVE_AM2_32   HALT
E_MOVE_AM2_33   HALT
E_MOVE_AM2_34   HALT
E_MOVE_AM2_35   HALT
E_MOVE_AM2_36   HALT
L_MOVE_AM2_31

; MOVE @R1, @--R1
; MOVE @R1++, @R1

L_MOVE_AM2_40
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x6789, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x9876, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1

                MOVE    AM_BSS1, R1
                MOVE    @R1, @--R1              ; Copy @R1 to @--R1

                CMP     R1, AM_BSS              ; Verify R1 decremented
                RBRA    E_MOVE_AM2_41, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x9876              ; Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x9876              ; Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       ; Jump if error

                MOVE    0x6789, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    AM_BSS, R1
                MOVE    @R1++, @R1              ; Copy @R1++ to @R1

                CMP     R1, AM_BSS1             ; Verify R1 incremented
                RBRA    E_MOVE_AM2_44, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x6789              ; Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x6789              ; Verify value unchanged
                RBRA    E_MOVE_AM2_46, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_41, 1
E_MOVE_AM2_41   HALT
E_MOVE_AM2_42   HALT
E_MOVE_AM2_43   HALT
E_MOVE_AM2_44   HALT
E_MOVE_AM2_45   HALT
E_MOVE_AM2_46   HALT
L_MOVE_AM2_41

; MOVE @R1++, @R1++
; MOVE @--R1, @--R1

L_MOVE_AM2_50
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    0x1234, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x4321, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    0x5678, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2

                MOVE    AM_BSS, R1
                MOVE    @R1++, @R1++            ; Copy @R1++ to @R1++

                CMP     R1, AM_BSS2             ; Verify R1 incremented twice
                RBRA    E_MOVE_AM2_51, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x1234              ; Verify value unchanged
                RBRA    E_MOVE_AM2_53, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x1234              ; Verify value correctly updated
                RBRA    E_MOVE_AM2_53, !Z       ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_54, !Z       ; Jump if error

                MOVE    0x4321, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    AM_BSS2, R1
                MOVE    @--R1, @--R1            ; Copy @--R1 to @--R1

                CMP     R1, AM_BSS              ; Verify R1 decremented twice
                RBRA    E_MOVE_AM2_55, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x4321              ; Verify value unchanged
                RBRA    E_MOVE_AM2_56, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x4321              ; Verify value unchanged
                RBRA    E_MOVE_AM2_57, !Z       ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_58, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_51, 1
E_MOVE_AM2_51   HALT
E_MOVE_AM2_52   HALT
E_MOVE_AM2_53   HALT
E_MOVE_AM2_54   HALT
E_MOVE_AM2_55   HALT
E_MOVE_AM2_56   HALT
E_MOVE_AM2_57   HALT
E_MOVE_AM2_58   HALT
L_MOVE_AM2_51

; MOVE @R1++, @--R1
; MOVE @--R1, @R1++

L_MOVE_AM2_60
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    0x1234, R0
                MOVE    R0, @R4                 ; Store dummy value into AM_BSS
                MOVE    0x4321, R0
                MOVE    R0, @R5                 ; Store dummy value into AM_BSS1
                MOVE    0x5678, R0
                MOVE    R0, @R6                 ; Store dummy value into AM_BSS2

                MOVE    AM_BSS1, R1
                MOVE    @R1++, @--R1            ; Copy @R1++ to @--R1

                CMP     R1, AM_BSS1             ; Verify R1 unchanged
                RBRA    E_MOVE_AM2_61, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x1234              ; Verify value unchanged
                RBRA    E_MOVE_AM2_62, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x4321              ; Verify value unchanged
                RBRA    E_MOVE_AM2_63, !Z       ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_64, !Z       ; Jump if error

                MOVE    AM_BSS1, R1
                MOVE    @--R1, @R1++            ; Copy @--R1 to @R1++

                CMP     R1, AM_BSS1             ; Verify R1 unchanged
                RBRA    E_MOVE_AM2_65, !Z       ; Jump if error
                MOVE    @R4, R0                 ; Read from AM_BSS
                CMP     R0, 0x1234              ; Verify value unchanged
                RBRA    E_MOVE_AM2_66, !Z       ; Jump if error
                MOVE    @R5, R0                 ; Read from AM_BSS1
                CMP     R0, 0x4321              ; Verify value unchanged
                RBRA    E_MOVE_AM2_67, !Z       ; Jump if error
                MOVE    @R6, R0                 ; Read from AM_BSS2
                CMP     R0, 0x5678              ; Verify value unchanged
                RBRA    E_MOVE_AM2_68, !Z       ; Jump if error

                RBRA    L_MOVE_AM2_61, 1
E_MOVE_AM2_61   HALT
E_MOVE_AM2_62   HALT
E_MOVE_AM2_63   HALT
E_MOVE_AM2_64   HALT
E_MOVE_AM2_65   HALT
E_MOVE_AM2_66   HALT
E_MOVE_AM2_67   HALT
E_MOVE_AM2_68   HALT
L_MOVE_AM2_61


; ---------------------------------------------------------------------------
; Test the SUB instruction with all pairs of addressing modes, where source
; and destination registers are different

; SUB R1, @R2
L_SUB_AM_000    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     R1, @R2
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_001, !Z        ; Jump if error
                CMP     R2, AM_DST1             ; Verify R2 unchanged
                RBRA    E_SUB_AM_002, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_003, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_004, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_005, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_006, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     AM_SRC1, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_007, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_008, !Z        ; Jump if error

                RBRA    L_SUB_AM_001, 1

AM_SRC0         .DW     0x0000
AM_SRC1         .DW     0x0000
AM_SRC2         .DW     0x0000
AM_DST0         .DW     0x0000
AM_DST1         .DW     0x0000
AM_DST2         .DW     0x0000

E_SUB_AM_001    HALT
E_SUB_AM_002    HALT
E_SUB_AM_003    HALT
E_SUB_AM_004    HALT
E_SUB_AM_005    HALT
E_SUB_AM_006    HALT
E_SUB_AM_007    HALT
E_SUB_AM_008    HALT
L_SUB_AM_001

; SUB R1, @R2++
L_SUB_AM_010    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     R1, @R2++
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_011, !Z        ; Jump if error
                CMP     R2, AM_DST2             ; Verify R2 incremented
                RBRA    E_SUB_AM_012, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_013, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_014, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_015, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_016, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     AM_SRC1, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_017, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_018, !Z        ; Jump if error

                RBRA    L_SUB_AM_011, 1

E_SUB_AM_011    HALT
E_SUB_AM_012    HALT
E_SUB_AM_013    HALT
E_SUB_AM_014    HALT
E_SUB_AM_015    HALT
E_SUB_AM_016    HALT
E_SUB_AM_017    HALT
E_SUB_AM_018    HALT
L_SUB_AM_011

; SUB R1, @--R2
L_SUB_AM_020    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     R1, @--R2
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_021, !Z        ; Jump if error
                CMP     R2, AM_DST0             ; Verify R2 decremented
                RBRA    E_SUB_AM_022, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_023, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_024, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_025, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x3210, R9
                SUB     AM_SRC1, R9
                CMP     R9, R8                  ; Verify AM_DST0 new value
                RBRA    E_SUB_AM_026, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_027, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_028, !Z        ; Jump if error

                RBRA    L_SUB_AM_021, 1

E_SUB_AM_021    HALT
E_SUB_AM_022    HALT
E_SUB_AM_023    HALT
E_SUB_AM_024    HALT
E_SUB_AM_025    HALT
E_SUB_AM_026    HALT
E_SUB_AM_027    HALT
E_SUB_AM_028    HALT
L_SUB_AM_021

; SUB @R1, R2
L_SUB_AM_030    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1, R2
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_031, !Z        ; Jump if error
                MOVE    AM_DST1, R9
                SUB     0x4567, R9
                CMP     R9, R2                  ; Verify R2 new value
                RBRA    E_SUB_AM_032, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_033, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_034, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_035, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_036, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_037, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_038, !Z        ; Jump if error

                RBRA    L_SUB_AM_031, 1

E_SUB_AM_031    HALT
E_SUB_AM_032    HALT
E_SUB_AM_033    HALT
E_SUB_AM_034    HALT
E_SUB_AM_035    HALT
E_SUB_AM_036    HALT
E_SUB_AM_037    HALT
E_SUB_AM_038    HALT
L_SUB_AM_031

; SUB @R1, @R2
L_SUB_AM_040    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1, @R2
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_041, !Z        ; Jump if error
                CMP     R2, AM_DST1             ; Verify R2 unchanged
                RBRA    E_SUB_AM_042, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_043, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_044, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_045, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_046, !Z        ; Jump if error
                MOVE    0x7654, R9
                SUB     0x4567, R9
                MOVE    @R0++, R8
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_047, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_048, !Z        ; Jump if error

                RBRA    L_SUB_AM_041, 1

E_SUB_AM_041    HALT
E_SUB_AM_042    HALT
E_SUB_AM_043    HALT
E_SUB_AM_044    HALT
E_SUB_AM_045    HALT
E_SUB_AM_046    HALT
E_SUB_AM_047    HALT
E_SUB_AM_048    HALT
L_SUB_AM_041

; SUB @R1, @R2++
L_SUB_AM_050    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1, @R2++
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_051, !Z        ; Jump if error
                CMP     R2, AM_DST2             ; Verify R2 incremented
                RBRA    E_SUB_AM_052, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_053, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_054, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_055, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_056, !Z        ; Jump if error
                MOVE    0x7654, R9
                SUB     0x4567, R9
                MOVE    @R0++, R8
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_057, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_058, !Z        ; Jump if error

                RBRA    L_SUB_AM_051, 1

E_SUB_AM_051    HALT
E_SUB_AM_052    HALT
E_SUB_AM_053    HALT
E_SUB_AM_054    HALT
E_SUB_AM_055    HALT
E_SUB_AM_056    HALT
E_SUB_AM_057    HALT
E_SUB_AM_058    HALT
L_SUB_AM_051

; SUB @R1, @--R2
L_SUB_AM_060    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1, @--R2
                CMP     R1, AM_SRC1             ; Verify R1 unchanged
                RBRA    E_SUB_AM_061, !Z        ; Jump if error
                CMP     R2, AM_DST0             ; Verify R2 decremented
                RBRA    E_SUB_AM_062, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_063, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_064, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_065, !Z        ; Jump if error
                MOVE    0x3210, R9
                SUB     0x4567, R9
                MOVE    @R0++, R8
                CMP     R9, R8                  ; Verify AM_DST0 new value
                RBRA    E_SUB_AM_066, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_067, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_068, !Z        ; Jump if error

                RBRA    L_SUB_AM_061, 1

E_SUB_AM_061    HALT
E_SUB_AM_062    HALT
E_SUB_AM_063    HALT
E_SUB_AM_064    HALT
E_SUB_AM_065    HALT
E_SUB_AM_066    HALT
E_SUB_AM_067    HALT
E_SUB_AM_068    HALT
L_SUB_AM_061


; SUB @R1++, R2
L_SUB_AM_070    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1++, R2
                CMP     AM_SRC2, R1             ; Verify R1 incremented
                RBRA    E_SUB_AM_071, !Z        ; Jump if error
                MOVE    AM_DST1, R9
                SUB     0x4567, R9
                CMP     R9, R2                  ; Verify R2 new value
                RBRA    E_SUB_AM_072, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_073, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_074, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_075, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_075, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_077, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_078, !Z        ; Jump if error

                RBRA    L_SUB_AM_071, 1

E_SUB_AM_071    HALT
E_SUB_AM_072    HALT
E_SUB_AM_073    HALT
E_SUB_AM_074    HALT
E_SUB_AM_075    HALT
E_SUB_AM_076    HALT
E_SUB_AM_077    HALT
E_SUB_AM_078    HALT
L_SUB_AM_071

; SUB @R1++, @R2
L_SUB_AM_080    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1++, @R2
                CMP     AM_SRC2, R1             ; Verify R1 incremented
                RBRA    E_SUB_AM_081, !Z        ; Jump if error
                CMP     AM_DST1, R2             ; Verify R2 unchanged
                RBRA    E_SUB_AM_082, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_083, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_084, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_085, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_085, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_087, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_088, !Z        ; Jump if error

                RBRA    L_SUB_AM_081, 1

E_SUB_AM_081    HALT
E_SUB_AM_082    HALT
E_SUB_AM_083    HALT
E_SUB_AM_084    HALT
E_SUB_AM_085    HALT
E_SUB_AM_086    HALT
E_SUB_AM_087    HALT
E_SUB_AM_088    HALT
L_SUB_AM_081

; SUB @R1++, @R2++
L_SUB_AM_090    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1++, @R2++
                CMP     AM_SRC2, R1             ; Verify R1 incremented
                RBRA    E_SUB_AM_091, !Z        ; Jump if error
                CMP     AM_DST2, R2             ; Verify R2 incremented
                RBRA    E_SUB_AM_092, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_093, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_094, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_095, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_095, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_097, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_098, !Z        ; Jump if error

                RBRA    L_SUB_AM_091, 1

E_SUB_AM_091    HALT
E_SUB_AM_092    HALT
E_SUB_AM_093    HALT
E_SUB_AM_094    HALT
E_SUB_AM_095    HALT
E_SUB_AM_096    HALT
E_SUB_AM_097    HALT
E_SUB_AM_098    HALT
L_SUB_AM_091

; SUB @R1++, @--R2
L_SUB_AM_100    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @R1++, @--R2
                CMP     AM_SRC2, R1             ; Verify R1 incremented
                RBRA    E_SUB_AM_101, !Z        ; Jump if error
                CMP     AM_DST0, R2             ; Verify R2 decremented
                RBRA    E_SUB_AM_102, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_103, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_104, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_105, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x3210, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM_DST0 new value
                RBRA    E_SUB_AM_106, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_107, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_108, !Z        ; Jump if error

                RBRA    L_SUB_AM_101, 1

E_SUB_AM_101    HALT
E_SUB_AM_102    HALT
E_SUB_AM_103    HALT
E_SUB_AM_104    HALT
E_SUB_AM_105    HALT
E_SUB_AM_106    HALT
E_SUB_AM_107    HALT
E_SUB_AM_108    HALT
L_SUB_AM_101

; SUB @--R1, R2
L_SUB_AM_110    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @--R1, R2
                CMP     AM_SRC0, R1             ; Verify R1 decremented
                RBRA    E_SUB_AM_111, !Z        ; Jump if error
                MOVE    AM_DST1, R9
                SUB     0x0123, R9
                CMP     R9, R2                  ; Verify R2 new value
                RBRA    E_SUB_AM_112, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_113, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_114, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_115, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_116, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_117, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_118, !Z        ; Jump if error

                RBRA    L_SUB_AM_111, 1

E_SUB_AM_111    HALT
E_SUB_AM_112    HALT
E_SUB_AM_113    HALT
E_SUB_AM_114    HALT
E_SUB_AM_115    HALT
E_SUB_AM_116    HALT
E_SUB_AM_117    HALT
E_SUB_AM_118    HALT
L_SUB_AM_111

; SUB @--R1, @R2
L_SUB_AM_120    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @--R1, @R2
                CMP     AM_SRC0, R1             ; Verify R1 decremented
                RBRA    E_SUB_AM_121, !Z        ; Jump if error
                CMP     AM_DST1, R2             ; Verify R2 unchanged
                RBRA    E_SUB_AM_122, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_123, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_124, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_125, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_126, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     0x0123, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_127, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_128, !Z        ; Jump if error

                RBRA    L_SUB_AM_121, 1

E_SUB_AM_121    HALT
E_SUB_AM_122    HALT
E_SUB_AM_123    HALT
E_SUB_AM_124    HALT
E_SUB_AM_125    HALT
E_SUB_AM_126    HALT
E_SUB_AM_127    HALT
E_SUB_AM_128    HALT
L_SUB_AM_121

; SUB @--R1, @R2++
L_SUB_AM_130    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @--R1, @R2++
                CMP     AM_SRC0, R1             ; Verify R1 decremented
                RBRA    E_SUB_AM_131, !Z        ; Jump if error
                CMP     AM_DST2, R2             ; Verify R2 incremented
                RBRA    E_SUB_AM_132, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_133, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_134, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_135, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x3210, R8              ; Verify AM_DST0 unchanged
                RBRA    E_SUB_AM_136, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x7654, R9
                SUB     0x0123, R9
                CMP     R9, R8                  ; Verify AM_DST1 new value
                RBRA    E_SUB_AM_137, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_138, !Z        ; Jump if error

                RBRA    L_SUB_AM_131, 1

E_SUB_AM_131    HALT
E_SUB_AM_132    HALT
E_SUB_AM_133    HALT
E_SUB_AM_134    HALT
E_SUB_AM_135    HALT
E_SUB_AM_136    HALT
E_SUB_AM_137    HALT
E_SUB_AM_138    HALT
L_SUB_AM_131

; SUB @--R1, @--R2
L_SUB_AM_140    ; Prepare test case
                MOVE    AM_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    0x3210, @R0++
                MOVE    0x7654, @R0++
                MOVE    0xBA98, @R0++
                MOVE    AM_SRC1, R1
                MOVE    AM_DST1, R2

                SUB     @--R1, @--R2
                CMP     AM_SRC0, R1             ; Verify R1 decremented
                RBRA    E_SUB_AM_141, !Z        ; Jump if error
                CMP     AM_DST0, R2             ; Verify R2 decremented
                RBRA    E_SUB_AM_142, !Z        ; Jump if error
                MOVE    AM_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM_SRC0 unchanged
                RBRA    E_SUB_AM_143, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM_SRC1 unchanged
                RBRA    E_SUB_AM_144, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM_SRC2 unchanged
                RBRA    E_SUB_AM_145, !Z        ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x3210, R9
                SUB     0x0123, R9
                CMP     R9, R8                  ; Verify AM_DST0 new value
                RBRA    E_SUB_AM_146, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0x7654, R8              ; Verify AM_DST1 unchanged
                RBRA    E_SUB_AM_147, !Z        ; Jump if error
                MOVE    @R0++, R8
                CMP     0xBA98, R8              ; Verify AM_DST2 unchanged
                RBRA    E_SUB_AM_148, !Z        ; Jump if error

                RBRA    L_SUB_AM_141, 1

E_SUB_AM_141    HALT
E_SUB_AM_142    HALT
E_SUB_AM_143    HALT
E_SUB_AM_144    HALT
E_SUB_AM_145    HALT
E_SUB_AM_146    HALT
E_SUB_AM_147    HALT
E_SUB_AM_148    HALT
L_SUB_AM_141


; ---------------------------------------------------------------------------
; Test the SUB instruction with all pairs of addressing modes, where source
; and destination registers are the same

; SUB R1, @R1
L_SUB_AM2_000   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     R1, @R1
                CMP     R1, AM2_SRC1            ; Verify R1 unchanged
                RBRA    E_SUB_AM2_001, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_002, !Z       ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x4567, R9
                SUB     AM2_SRC1, R9
                CMP     R9, R8                  ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_003, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_004, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_001, 1

AM2_SRC0        .DW     0x0000
AM2_SRC1        .DW     0x0000
AM2_SRC2        .DW     0x0000

E_SUB_AM2_001   HALT
E_SUB_AM2_002   HALT
E_SUB_AM2_003   HALT
E_SUB_AM2_004   HALT
L_SUB_AM2_001

; SUB R1, @R1++
L_SUB_AM2_010   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     R1, @R1++
                CMP     R1, AM2_SRC2            ; Verify R1 incremented
                RBRA    E_SUB_AM2_011, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_012, !Z       ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x4567, R9
                SUB     AM2_SRC1, R9
                CMP     R9, R8                  ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_013, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_014, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_011, 1

E_SUB_AM2_011   HALT
E_SUB_AM2_012   HALT
E_SUB_AM2_013   HALT
E_SUB_AM2_014   HALT
L_SUB_AM2_011

; SUB R1, @--R1
L_SUB_AM2_020   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     R1, @--R1
                CMP     R1, AM2_SRC0            ; Verify R1 decremented
                RBRA    E_SUB_AM2_021, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                MOVE    0x0123, R9
                SUB     AM2_SRC1, R9
                CMP     R9, R8                  ; Verify AM2_SRC0 new value
                RBRA    E_SUB_AM2_022, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_023, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_024, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_021, 1

E_SUB_AM2_021   HALT
E_SUB_AM2_022   HALT
E_SUB_AM2_023   HALT
E_SUB_AM2_024   HALT
L_SUB_AM2_021

; SUB @R1, R1
L_SUB_AM2_030   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1, R1
                MOVE    AM2_SRC1, R9
                SUB     0x4567, R9
                CMP     R9, R1                  ; Verify R1 new value
                RBRA    E_SUB_AM2_031, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_032, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_033, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_034, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_031, 1

E_SUB_AM2_031   HALT
E_SUB_AM2_032   HALT
E_SUB_AM2_033   HALT
E_SUB_AM2_034   HALT
L_SUB_AM2_031

; SUB @R1, @R1
L_SUB_AM2_040   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1, @R1
                CMP     AM2_SRC1, R1            ; Verify R1 unchanged
                RBRA    E_SUB_AM2_041, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_042, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x0000, R8              ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_043, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_044, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_041, 1

E_SUB_AM2_041   HALT
E_SUB_AM2_042   HALT
E_SUB_AM2_043   HALT
E_SUB_AM2_044   HALT
L_SUB_AM2_041

; SUB @R1, @R1++
L_SUB_AM2_050   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1, @R1++
                CMP     AM2_SRC2, R1            ; Verify R1 incremented
                RBRA    E_SUB_AM2_051, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_052, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x0000, R8              ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_053, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_054, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_051, 1

E_SUB_AM2_051   HALT
E_SUB_AM2_052   HALT
E_SUB_AM2_053   HALT
E_SUB_AM2_054   HALT
L_SUB_AM2_051

; SUB @R1, @--R1
L_SUB_AM2_060   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1, @--R1
                CMP     AM2_SRC0, R1            ; Verify R1 decremented
                RBRA    E_SUB_AM2_061, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                MOVE    0x0123, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM2_SRC0 new value
                RBRA    E_SUB_AM2_062, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_063, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_064, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_061, 1

E_SUB_AM2_061   HALT
E_SUB_AM2_062   HALT
E_SUB_AM2_063   HALT
E_SUB_AM2_064   HALT
L_SUB_AM2_061

; SUB @R1++, R1
L_SUB_AM2_070   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1++, R1
                MOVE    AM2_SRC2, R9
                SUB     0x4567, R9
                CMP     R9, R1                  ; Verify R1 new value
                RBRA    E_SUB_AM2_071, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_072, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_073, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_074, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_071, 1

E_SUB_AM2_071   HALT
E_SUB_AM2_072   HALT
E_SUB_AM2_073   HALT
E_SUB_AM2_074   HALT
L_SUB_AM2_071

; SUB @R1++, @R1
L_SUB_AM2_080   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1++, @R1
                CMP     AM2_SRC2, R1            ; Verify R1 incremented
                RBRA    E_SUB_AM2_081, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_082, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_083, !Z       ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x89AB, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM2_SRC2 new value
                RBRA    E_SUB_AM2_084, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_081, 1

E_SUB_AM2_081   HALT
E_SUB_AM2_082   HALT
E_SUB_AM2_083   HALT
E_SUB_AM2_084   HALT
L_SUB_AM2_081

; SUB @R1++, @R1++
L_SUB_AM2_090   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC0, R1

                SUB     @R1++, @R1++
                CMP     AM2_SRC2, R1            ; Verify R1 incremented twice
                RBRA    E_SUB_AM2_091, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_092, !Z       ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x4567, R9
                SUB     0x0123, R9
                CMP     R9, R8                  ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_093, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_094, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_091, 1

E_SUB_AM2_091   HALT
E_SUB_AM2_092   HALT
E_SUB_AM2_093   HALT
E_SUB_AM2_094   HALT
L_SUB_AM2_091

; SUB @R1++, @--R1
L_SUB_AM2_100   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @R1++, @--R1
                CMP     AM2_SRC1, R1            ; Verify R1 unchanged
                RBRA    E_SUB_AM2_101, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_102, !Z       ; Jump if error
                MOVE    @R0++, R8
                MOVE    0x4567, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM2_SRC1 new value
                RBRA    E_SUB_AM2_103, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_104, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_101, 1

E_SUB_AM2_101   HALT
E_SUB_AM2_102   HALT
E_SUB_AM2_103   HALT
E_SUB_AM2_104   HALT
L_SUB_AM2_101

; SUB @--R1, R1
L_SUB_AM2_110   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @--R1, R1
                MOVE    AM2_SRC0, R9
                SUB     0x0123, R9
                CMP     R9, R1                  ; Verify R1 new value
                RBRA    E_SUB_AM2_111, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0123, R8              ; Verify AM2_SRC0 unchanged
                RBRA    E_SUB_AM2_112, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_113, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_114, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_111, 1

E_SUB_AM2_111   HALT
E_SUB_AM2_112   HALT
E_SUB_AM2_113   HALT
E_SUB_AM2_114   HALT
L_SUB_AM2_111

; SUB @--R1, @R1
L_SUB_AM2_120   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @--R1, @R1
                CMP     AM2_SRC0, R1            ; Verify R1 decremented
                RBRA    E_SUB_AM2_121, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0000, R8              ; Verify AM2_SRC0 new value
                RBRA    E_SUB_AM2_122, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_123, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_124, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_121, 1

E_SUB_AM2_121   HALT
E_SUB_AM2_122   HALT
E_SUB_AM2_123   HALT
E_SUB_AM2_124   HALT
L_SUB_AM2_121

; SUB @--R1, @R1++
L_SUB_AM2_130   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC1, R1

                SUB     @--R1, @R1++
                CMP     AM2_SRC1, R1            ; Verify R1 unchanged
                RBRA    E_SUB_AM2_131, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                CMP     0x0000, R8              ; Verify AM2_SRC0 new value
                RBRA    E_SUB_AM2_132, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_133, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_134, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_131, 1

E_SUB_AM2_131   HALT
E_SUB_AM2_132   HALT
E_SUB_AM2_133   HALT
E_SUB_AM2_134   HALT
L_SUB_AM2_131

; SUB @--R1, @--R1
L_SUB_AM2_140   ; Prepare test case
                MOVE    AM2_SRC0, R0
                MOVE    0x0123, @R0++
                MOVE    0x4567, @R0++
                MOVE    0x89AB, @R0++
                MOVE    AM2_SRC2, R1

                SUB     @--R1, @--R1
                CMP     AM2_SRC0, R1            ; Verify R1 decremented twice
                RBRA    E_SUB_AM2_141, !Z       ; Jump if error
                MOVE    AM2_SRC0, R0
                MOVE    @R0++, R8
                MOVE    0x0123, R9
                SUB     0x4567, R9
                CMP     R9, R8                  ; Verify AM2_SRC0 new value
                RBRA    E_SUB_AM2_142, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x4567, R8              ; Verify AM2_SRC1 unchanged
                RBRA    E_SUB_AM2_143, !Z       ; Jump if error
                MOVE    @R0++, R8
                CMP     0x89AB, R8              ; Verify AM2_SRC2 unchanged
                RBRA    E_SUB_AM2_144, !Z       ; Jump if error
                MOVE    @R0++, R8

                RBRA    L_SUB_AM2_141, 1

E_SUB_AM2_141   HALT
E_SUB_AM2_142   HALT
E_SUB_AM2_143   HALT
E_SUB_AM2_144   HALT
L_SUB_AM2_141


; Everything worked as expected! We are done now.
EXIT            MOVE    OK, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

OK              .ASCII_W    "OK\n"

