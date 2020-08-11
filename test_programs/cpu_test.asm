// Extended CPU test

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG    0x8000

// This is a comprehensive test suite of the QNICE processor.
// The QNICE processor has 18 different instructions, 4 different addressing
// modes, and 5 different status flags.
// Making an exhaustive test of all possible combinations of the three
// different paramterss is too big.
// Instead, this program tests:
// * All combinations of instructions and status flags.
// * All combinations of instructions and addressing modes.

// Status register (bits 7 - 0) of R14:
// - - V N Z C X 1

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


// Instructions:
// MOVE, ADD, ADDC, SUB, SUBC, SHL, SHR, SWAP
// NOT, AND, OR, XOR, CMP, res, HALT, BRA/SUB

// Instruction | Flags affected
//             | V | N | Z | C | X |
// MOVE        | . | * | * | . | * |
// ADD/SUB     | * | * | * | * | * |
// SHL         | . | . | . | * | . |
// SHR         | . | . | . | . | * |
// SWAP        | . | * | * | . | * |
// NOT         | . | * | * | . | * |
// AND/OR/XOR  | . | * | * | . | * |
// CMP         | * | * | * | . | . |
// BRA/SUB     | . | . | . | . | . |


// Addressing modes
// R0
// @R0
// @R0++
// @--R0

// We can't explicitly test the HALT instruction, so we must just assume that
// it works as expected.

// Tests in this file:
// UNC      : Test unconditional absolute and relative branches
// R14_ST   : Test that moving data into R14 sets the correct status bits
// MOVE_IMM : Test the MOVE immediate instruction, and the X, Z, and N-conditional branches
// MOVE_REG : Test the MOVE register instruction, and the X, Z, and N-conditional branches
// CMP_IMM  : Test compare with immediate value and Z-conditional absolute branch
// CMP_REG  : Test compare between two registers and Z-conditional relative branch
// REG_13   : Test all 13 registers can contain different values
// ADD      : Test the ADD instruction, and the status register
// MOVE_CV  : Test the MOVE instruction doesn't change C and V flags
// MOVE_MEM : Test the MOVE instruction to/from a memory address
// ADDC     : Test the ADDC instruction with and without carry
// SUB      : Test the SUB instruction
// SUBC     : Test the SUBC instruction with and without carry
// SHL      : Test the SHL instruction
// SHR      : Test the SHR instruction
// SWAP     : Test the SWAP instruction
// NOT      : Test the NOT instruction
// AND      : Test the AND instruction
// OR       : Test the OR instruction
// XOR      : Test the XOR instruction
// CMP      : Test the CMP instruction

// More tests to do:
// Test that PC is the same as R15
//


// ---------------------------------------------------------------------------
// Test unconditional absolute and relative branches.

L_UNC_0         ABRA    E_UNC_1, !1             // Verify "absolute branch never" is not taken.

                ABRA    L_UNC_1, 1              // Verify "absolute branch always" is taken.
                HALT

E_UNC_1         HALT

E_UNC_2         HALT

L_UNC_2         RBRA    L_UNC_3, 1              // Verify "relative branch always" is taken in the forward direction.
                HALT

L_UNC_1         RBRA    E_UNC_2, !1             // Verify "relative branch never" is not taken.
                RBRA    L_UNC_2, 1              // Verify "relative branch always" is taken in the backward direction.
                HALT

L_UNC_3


// ---------------------------------------------------------------------------
// Test that moving data into R14 sets the correct status bits

L_R14_ST_00     MOVE    0x00FF, R14                // Set all bits in the status register
                RBRA    E_R14_ST_01, !V            // Verify "relative branch nonoverflow" is not taken.
                RBRA    L_R14_ST_01, V             // Verify "relative branch overflow" is taken.
                HALT
E_R14_ST_01     HALT
L_R14_ST_01
                RBRA    E_R14_ST_02, !N            // Verify "relative branch nonnegative" is not taken.
                RBRA    L_R14_ST_02, N             // Verify "relative branch negative" is taken.
                HALT
E_R14_ST_02     HALT
L_R14_ST_02
                RBRA    E_R14_ST_03, !Z            // Verify "relative branch nonzero" is not taken.
                RBRA    L_R14_ST_03, Z             // Verify "relative branch zero" is taken.
                HALT
E_R14_ST_03     HALT
L_R14_ST_03
                RBRA    E_R14_ST_04, !C            // Verify "relative branch noncarry" is not taken.
                RBRA    L_R14_ST_04, C             // Verify "relative branch carry" is taken.
                HALT
E_R14_ST_04     HALT
L_R14_ST_04
                RBRA    E_R14_ST_05, !X            // Verify "relative branch nonX" is not taken.
                RBRA    L_R14_ST_05, X             // Verify "relative branch X" is taken.
                HALT
E_R14_ST_05     HALT
L_R14_ST_05
                RBRA    E_R14_ST_06, !1            // Verify "relative branch never" is not taken.
                RBRA    L_R14_ST_06, 1             // Verify "relative branch always" is taken.
                HALT
E_R14_ST_06     HALT
L_R14_ST_06

L_R14_ST_10     MOVE    0x0000, R14                // Clear all bits in the status register
                RBRA    E_R14_ST_11, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_R14_ST_11, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_R14_ST_11     HALT
L_R14_ST_11
                RBRA    E_R14_ST_12, N             // Verify "relative branch negative" is not taken.
                RBRA    L_R14_ST_12, !N            // Verify "relative branch nonnegative" is taken.
                HALT
E_R14_ST_12     HALT
L_R14_ST_12
                RBRA    E_R14_ST_13, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_R14_ST_13, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_R14_ST_13     HALT
L_R14_ST_13
                RBRA    E_R14_ST_14, C             // Verify "relative branch carry" is not taken.
                RBRA    L_R14_ST_14, !C            // Verify "relative branch noncarry" is taken.
                HALT
E_R14_ST_14     HALT
L_R14_ST_14
                RBRA    E_R14_ST_15, X             // Verify "relative branch X" is not taken.
                RBRA    L_R14_ST_15, !X            // Verify "relative branch nonX" is taken.
                HALT
E_R14_ST_15     HALT
L_R14_ST_15
                RBRA    E_R14_ST_16, !1            // Verify "relative branch never" is not taken.
                RBRA    L_R14_ST_16, 1             // Verify "relative branch always" is taken.
                HALT
E_R14_ST_16     HALT
L_R14_ST_16



// ---------------------------------------------------------------------------
// Test the MOVE immediate instruction, and the X, Z, and N-conditional branches

L_MOVE_IMM_00   MOVE    0x1234, R0
                ABRA    E_MOVE_IMM_01, Z        // Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_01, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_01   HALT
L_MOVE_IMM_01
                ABRA    E_MOVE_IMM_02, N        // Verify "absolute branch negative" is not taken.
                ABRA    L_MOVE_IMM_02, !N       // Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_IMM_02   HALT
L_MOVE_IMM_02
                ABRA    E_MOVE_IMM_03, X        // Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_03, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_03   HALT
L_MOVE_IMM_03
                ABRA    E_MOVE_IMM_04, !1       // Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_04, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_04   HALT
L_MOVE_IMM_04


L_MOVE_IMM_10   MOVE    0x0000, R0
                ABRA    E_MOVE_IMM_11, !Z       // Verify "absolute branch nonzero" is not taken.
                ABRA    L_MOVE_IMM_11, Z        // Verify "absolute branch zero" is taken.
                HALT
E_MOVE_IMM_11   HALT
L_MOVE_IMM_11
                ABRA    E_MOVE_IMM_12, N        // Verify "absolute branch negative" is not taken.
                ABRA    L_MOVE_IMM_12, !N       // Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_IMM_12   HALT
L_MOVE_IMM_12
                ABRA    E_MOVE_IMM_13, X        // Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_13, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_13   HALT
L_MOVE_IMM_13
                ABRA    E_MOVE_IMM_14, !1       // Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_14, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_14   HALT
L_MOVE_IMM_14


L_MOVE_IMM_20   MOVE    0xFEDC, R0
                ABRA    E_MOVE_IMM_21, Z        // Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_21, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_21   HALT
L_MOVE_IMM_21
                ABRA    E_MOVE_IMM_22, !N       // Verify "absolute branch nonnegative" is not taken.
                ABRA    L_MOVE_IMM_22, N        // Verify "absolute branch negative" is taken.
                HALT
E_MOVE_IMM_22   HALT
L_MOVE_IMM_22
                ABRA    E_MOVE_IMM_23, X        // Verify "absolute branch X" is not taken.
                ABRA    L_MOVE_IMM_23, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_IMM_23   HALT
L_MOVE_IMM_23
                ABRA    E_MOVE_IMM_24, !1       // Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_24, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_24   HALT
L_MOVE_IMM_24


L_MOVE_IMM_30   MOVE    0xFFFF, R0
                ABRA    E_MOVE_IMM_31, Z        // Verify "absolute branch zero" is not taken.
                ABRA    L_MOVE_IMM_31, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_IMM_31   HALT
L_MOVE_IMM_31
                ABRA    E_MOVE_IMM_32, !N       // Verify "absolute branch nonnegative" is not taken.
                ABRA    L_MOVE_IMM_32, N        // Verify "absolute branch negative" is taken.
                HALT
E_MOVE_IMM_32   HALT
L_MOVE_IMM_32
                ABRA    E_MOVE_IMM_33, !X       // Verify "absolute branch nonX" is not taken.
                ABRA    L_MOVE_IMM_33, X        // Verify "absolute branch X" is taken.
                HALT
E_MOVE_IMM_33   HALT
L_MOVE_IMM_33
                ABRA    E_MOVE_IMM_34, !1       // Verify "absolute branch never" is not taken.
                ABRA    L_MOVE_IMM_34, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_IMM_34   HALT
L_MOVE_IMM_34


// ---------------------------------------------------------------------------
// Test the MOVE register instruction, and the X, Z, and N-conditional branches

L_MOVE_REG_00   MOVE    0x1234, R1
                MOVE    0x0000, R2
                MOVE    0xFEDC, R3
                MOVE    0xFFFF, R4

                MOVE    R1, R0
                RBRA    E_MOVE_REG_01, Z        // Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_01, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_01   HALT
L_MOVE_REG_01
                RBRA    E_MOVE_REG_02, N        // Verify "absolute branch negative" is not taken.
                RBRA    L_MOVE_REG_02, !N       // Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_REG_02   HALT
L_MOVE_REG_02
                RBRA    E_MOVE_REG_03, X        // Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_03, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_03   HALT
L_MOVE_REG_03
                RBRA    E_MOVE_REG_04, !1       // Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_04, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_04   HALT
L_MOVE_REG_04


L_MOVE_REG_10   MOVE    R2, R0
                RBRA    E_MOVE_REG_11, !Z       // Verify "absolute branch nonzero" is not taken.
                RBRA    L_MOVE_REG_11, Z        // Verify "absolute branch zero" is taken.
                HALT
E_MOVE_REG_11   HALT
L_MOVE_REG_11
                RBRA    E_MOVE_REG_12, N        // Verify "absolute branch negative" is not taken.
                RBRA    L_MOVE_REG_12, !N       // Verify "absolute branch nonnegative" is taken.
                HALT
E_MOVE_REG_12   HALT
L_MOVE_REG_12
                RBRA    E_MOVE_REG_13, X        // Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_13, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_13   HALT
L_MOVE_REG_13
                RBRA    E_MOVE_REG_14, !1       // Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_14, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_14   HALT
L_MOVE_REG_14


L_MOVE_REG_20   MOVE    R3, R0
                RBRA    E_MOVE_REG_21, Z        // Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_21, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_21   HALT
L_MOVE_REG_21
                RBRA    E_MOVE_REG_22, !N       // Verify "absolute branch nonnegative" is not taken.
                RBRA    L_MOVE_REG_22, N        // Verify "absolute branch negative" is taken.
                HALT
E_MOVE_REG_22   HALT
L_MOVE_REG_22
                RBRA    E_MOVE_REG_23, X        // Verify "absolute branch X" is not taken.
                RBRA    L_MOVE_REG_23, !X       // Verify "absolute branch nonX" is taken.
                HALT
E_MOVE_REG_23   HALT
L_MOVE_REG_23
                RBRA    E_MOVE_REG_24, !1       // Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_24, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_24   HALT
L_MOVE_REG_24


L_MOVE_REG_30   MOVE    R4, R0
                RBRA    E_MOVE_REG_31, Z        // Verify "absolute branch zero" is not taken.
                RBRA    L_MOVE_REG_31, !Z       // Verify "absolute branch nonzero" is taken.
                HALT
E_MOVE_REG_31   HALT
L_MOVE_REG_31
                RBRA    E_MOVE_REG_32, !N       // Verify "absolute branch nonnegative" is not taken.
                RBRA    L_MOVE_REG_32, N        // Verify "absolute branch negative" is taken.
                HALT
E_MOVE_REG_32   HALT
L_MOVE_REG_32
                RBRA    E_MOVE_REG_33, !X       // Verify "absolute branch nonX" is not taken.
                RBRA    L_MOVE_REG_33, X        // Verify "absolute branch X" is taken.
                HALT
E_MOVE_REG_33   HALT
L_MOVE_REG_33
                RBRA    E_MOVE_REG_34, !1       // Verify "absolute branch never" is not taken.
                RBRA    L_MOVE_REG_34, 1        // Verify "absolute branch always" is taken.
                HALT
E_MOVE_REG_34   HALT
L_MOVE_REG_34


// ---------------------------------------------------------------------------
// Test compare with immediate value and Z-conditional absolute branch

L_CMP_IMM_0     MOVE    0x1234, R0
                MOVE    0x4321, R1

// Compare R0 with correct value.
                CMP     0x1234, R0
                ABRA    E_CMP_IMM_1, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_1, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_1     HALT
L_CMP_IMM_1
                CMP     R0, 0x1234
                ABRA    E_CMP_IMM_2, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_2, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_2     HALT
L_CMP_IMM_2

// Compare R1 with correct value.
                CMP     0x4321, R1
                ABRA    E_CMP_IMM_3, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_3, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_3     HALT
L_CMP_IMM_3
                CMP     R1, 0x4321
                ABRA    E_CMP_IMM_4, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_4, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_4     HALT
L_CMP_IMM_4

// Compare R1 with incorrect value.
                CMP     0x1234, R1
                ABRA    E_CMP_IMM_5, Z          // Verify "absolute branch zero" is not taken.
                ABRA    L_CMP_IMM_5, !Z         // Verify "absolute branch nonzero" is taken.
                HALT
E_CMP_IMM_5     HALT
L_CMP_IMM_5
                CMP     R1, 0x1234
                ABRA    E_CMP_IMM_6, Z          // Verify "absolute branch zero" is not taken.
                ABRA    L_CMP_IMM_6, !Z         // Verify "absolute branch nonzero" is taken.
                HALT
E_CMP_IMM_6     HALT
L_CMP_IMM_6
                MOVE    R0, R1
// Compare R1 with correct value.
                CMP     0x1234, R1
                ABRA    E_CMP_IMM_7, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_7, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_7     HALT
L_CMP_IMM_7
                CMP     R1, 0x1234
                ABRA    E_CMP_IMM_8, !Z         // Verify "absolute branch nonzero" is not taken.
                ABRA    L_CMP_IMM_8, Z          // Verify "absolute branch zero" is taken.
                HALT
E_CMP_IMM_8     HALT
L_CMP_IMM_8


// ---------------------------------------------------------------------------
// Test compare between two registers and Z-conditional relative branch

L_CMP_REG_0     MOVE    0x1234, R0
                MOVE    0x4321, R1

// Compare registers with different values.
                CMP     R0, R1
                RBRA    E_CMP_REG_1, Z          // Verify "relative branch zero" is not taken.
                RBRA    L_CMP_REG_1, !Z         // Verify "relative branch nonzero" is taken.
                HALT
E_CMP_REG_1     HALT
L_CMP_REG_1
                CMP     R1, R0
                RBRA    E_CMP_REG_2, Z          // Verify "relative branch zero" is not taken.
                RBRA    L_CMP_REG_2, !Z         // Verify "relative branch nonzero" is taken.
                HALT
E_CMP_REG_2     HALT
L_CMP_REG_2
                MOVE    R1, R0

// Compare registers with equal values.
                CMP     R0, R1
                RBRA    E_CMP_REG_3, !Z         // Verify "relative branch nonzero" is not taken.
                RBRA    L_CMP_REG_3, Z          // Verify "relative branch zero" is taken.
                HALT
E_CMP_REG_3     HALT
L_CMP_REG_3
                CMP     R1, R0
                RBRA    E_CMP_REG_4, !Z         // Verify "relative branch nonzero" is not taken.
                RBRA    L_CMP_REG_4, Z          // Verify "relative branch zero" is taken.
                HALT
E_CMP_REG_4     HALT
L_CMP_REG_4


// REG_13   : Test all 13 registers can contain different values
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


// ---------------------------------------------------------------------------
// Test the ADD instruction, and the status register
// Addition                 | V | N | Z | C | X | 1 |
// 0x1234 + 0x4321 = 0x5555 | 0 | 0 | 0 | 0 | 0 | 1 | ADD_0
// 0x8765 + 0x9876 = 0x1FDB | 1 | 0 | 0 | 1 | 0 | 1 | ADD_1
// 0x1234 + 0x9876 = 0xAAAA | 0 | 1 | 0 | 0 | 0 | 1 | ADD_2
// 0xFEDC + 0xEDCB = 0xECA7 | 0 | 1 | 0 | 1 | 0 | 1 | ADD_3
// 0xFEDC + 0x0123 = 0xFFFF | 0 | 1 | 0 | 0 | 1 | 1 | ADD_4
// 0xFEDC + 0x0124 = 0x0000 | 0 | 0 | 1 | 1 | 0 | 1 | ADD_5
// 0x7654 + 0x6543 = 0xDB97 | 1 | 1 | 0 | 0 | 0 | 1 | ADD_6

// Addition                 | V | N | Z | C | X | 1 |
// 0x1234 + 0x4321 = 0x5555 | 0 | 0 | 0 | 0 | 0 | 1 | ADD_0

                MOVE    0x0000, R14             // Clear status register

L_ADD_00        MOVE    0x1234, R0
                ADD     0x4321, R0

                RBRA    E_ADD_01, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_01, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_01        HALT
L_ADD_01
                RBRA    E_ADD_02, N             // Verify "relative branch negative" is not taken.
                RBRA    L_ADD_02, !N            // Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_02        HALT
L_ADD_02
                RBRA    E_ADD_03, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_03, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_03        HALT
L_ADD_03
                RBRA    E_ADD_04, C             // Verify "relative branch carry" is not taken.
                RBRA    L_ADD_04, !C            // Verify "relative branch noncarry" is taken.
                HALT
E_ADD_04        HALT
L_ADD_04
                RBRA    E_ADD_05, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_05, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_05        HALT
L_ADD_05
                RBRA    E_ADD_06, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_06, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_06        HALT
L_ADD_06
                MOVE    R14, R1                 // Verify status register: --000001
                CMP     0x0001, R1
                RBRA    E_ADD_07, !Z
                RBRA    L_ADD_07, Z
                HALT
E_ADD_07        HALT
L_ADD_07
                CMP     0x5555, R0              // Verify result
                RBRA    E_ADD_08, !Z
                RBRA    L_ADD_08, Z
                HALT
E_ADD_08        HALT
L_ADD_08


// Addition                 | V | N | Z | C | X | 1 |
// 0x8765 + 0x9876 = 0x1FDB | 1 | 0 | 0 | 1 | 0 | 1 | ADD_1
L_ADD_10        MOVE    0x8765, R0
                ADD     0x9876, R0

                RBRA    E_ADD_11, !V            // Verify "relative branch nonoverflow" is not taken.
                RBRA    L_ADD_11, V             // Verify "relative branch overflow" is taken.
                HALT
E_ADD_11        HALT
L_ADD_11
                RBRA    E_ADD_12, N             // Verify "relative branch negative" is not taken.
                RBRA    L_ADD_12, !N            // Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_12        HALT
L_ADD_12
                RBRA    E_ADD_13, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_13, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_13        HALT
L_ADD_13
                RBRA    E_ADD_14, !C            // Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_14, C             // Verify "relative branch carry" is taken.
                HALT
E_ADD_14        HALT
L_ADD_14
                RBRA    E_ADD_15, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_15, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_15        HALT
L_ADD_15
                RBRA    E_ADD_16, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_16, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_16        HALT
L_ADD_16
                MOVE    R14, R1                 // Verify status register: --100101
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


// Addition                 | V | N | Z | C | X | 1 |
// 0x1234 + 0x9876 = 0xAAAA | 0 | 1 | 0 | 0 | 0 | 1 | ADD_2
L_ADD_20        MOVE    0x1234, R0
                ADD     0x9876, R0

                RBRA    E_ADD_21, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_21, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_21        HALT
L_ADD_21
                RBRA    E_ADD_22, !N            // Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_22, N             // Verify "relative branch negative" is taken.
                HALT
E_ADD_22        HALT
L_ADD_22
                RBRA    E_ADD_23, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_23, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_23        HALT
L_ADD_23
                RBRA    E_ADD_24, C             // Verify "relative branch carry" is not taken.
                RBRA    L_ADD_24, !C            // Verify "relative branch noncarry" is taken.
                HALT
E_ADD_24        HALT
L_ADD_24
                RBRA    E_ADD_25, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_25, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_25        HALT
L_ADD_25
                RBRA    E_ADD_26, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_26, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_26        HALT
L_ADD_26
                MOVE    R14, R1                 // Verify status register: --010001
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


// Addition                 | V | N | Z | C | X | 1 |
// 0xFEDC + 0xEDCB = 0xECA7 | 0 | 1 | 0 | 1 | 0 | 1 | ADD_3
L_ADD_30        MOVE    0xFEDC, R0
                ADD     0xEDCB, R0

                RBRA    E_ADD_31, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_31, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_31        HALT
L_ADD_31
                RBRA    E_ADD_32, !N            // Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_32, N             // Verify "relative branch negative" is taken.
                HALT
E_ADD_32        HALT
L_ADD_32
                RBRA    E_ADD_33, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_33, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_33        HALT
L_ADD_33
                RBRA    E_ADD_34, !C            // Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_34, C             // Verify "relative branch carry" is taken.
                HALT
E_ADD_34        HALT
L_ADD_34
                RBRA    E_ADD_35, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_35, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_35        HALT
L_ADD_35
                RBRA    E_ADD_36, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_36, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_36        HALT
L_ADD_36
                MOVE    R14, R1                 // Verify status register: --010101
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


// Addition                 | V | N | Z | C | X | 1 |
// 0xFEDC + 0x0123 = 0xFFFF | 0 | 1 | 0 | 0 | 1 | 1 | ADD_4
L_ADD_40        MOVE    0xFEDC, R0
                ADD     0x0123, R0

                RBRA    E_ADD_41, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_41, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_41        HALT
L_ADD_41
                RBRA    E_ADD_42, !N            // Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_42, N             // Verify "relative branch negative" is taken.
                HALT
E_ADD_42        HALT
L_ADD_42
                RBRA    E_ADD_43, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_43, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_43        HALT
L_ADD_43
                RBRA    E_ADD_44, C             // Verify "relative branch carry" is not taken.
                RBRA    L_ADD_44, !C            // Verify "relative branch noncarry" is taken.
                HALT
E_ADD_44        HALT
L_ADD_44
                RBRA    E_ADD_45, !X            // Verify "relative branch nonX" is not taken.
                RBRA    L_ADD_45, X             // Verify "relative branch X" is taken.
                HALT
E_ADD_45        HALT
L_ADD_45
                RBRA    E_ADD_46, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_46, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_46        HALT
L_ADD_46
                MOVE    R14, R1                 // Verify status register: --010011
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


// Addition                 | V | N | Z | C | X | 1 |
// 0xFEDC + 0x0124 = 0x0000 | 0 | 0 | 1 | 1 | 0 | 1 | ADD_5
L_ADD_50        MOVE    0xFEDC, R0
                ADD     0x0124, R0

                RBRA    E_ADD_51, V             // Verify "relative branch overflow" is not taken.
                RBRA    L_ADD_51, !V            // Verify "relative branch nonoverflow" is taken.
                HALT
E_ADD_51        HALT
L_ADD_51
                RBRA    E_ADD_52, N             // Verify "relative branch negative" is not taken.
                RBRA    L_ADD_52, !N            // Verify "relative branch nonnegative" is taken.
                HALT
E_ADD_52        HALT
L_ADD_52
                RBRA    E_ADD_53, !Z            // Verify "relative branch nonzero" is not taken.
                RBRA    L_ADD_53, Z             // Verify "relative branch zero" is taken.
                HALT
E_ADD_53        HALT
L_ADD_53
                RBRA    E_ADD_54, !C            // Verify "relative branch noncarry" is not taken.
                RBRA    L_ADD_54, C             // Verify "relative branch carry" is taken.
                HALT
E_ADD_54        HALT
L_ADD_54
                RBRA    E_ADD_55, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_55, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_55        HALT
L_ADD_55
                RBRA    E_ADD_56, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_56, 1             // Verify "relative branch always" is taken.
                HALT
E_ADD_56        HALT
L_ADD_56
                MOVE    R14, R1                 // Verify status register: --001101
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


// Addition                 | V | N | Z | C | X | 1 |
// 0x7654 + 0x6543 = 0xDB97 | 1 | 1 | 0 | 0 | 0 | 1 | ADD_6
L_ADD_60        MOVE    0x7654, R0
                ADD     0x6543, R0

                RBRA    E_ADD_61, !V            // Verify "relative branch nonoverflow" is not taken.
                RBRA    L_ADD_61, V             // Verify "relative branch overflow" is taken.
                HALT
E_ADD_61        HALT
L_ADD_61
                RBRA    E_ADD_62, !N            // Verify "relative branch nonnegative" is not taken.
                RBRA    L_ADD_62, N             // Verify "relative branch negative" is taken.
                HALT
E_ADD_62        HALT
L_ADD_62
                RBRA    E_ADD_63, Z             // Verify "relative branch zero" is not taken.
                RBRA    L_ADD_63, !Z            // Verify "relative branch nonzero" is taken.
                HALT
E_ADD_63        HALT
L_ADD_63
                RBRA    E_ADD_64, C             // Verify "relative branch carry" is not taken.
                RBRA    L_ADD_64, !C            // Verify "relative branch noncarry" is taken.
                HALT
E_ADD_64        HALT
L_ADD_64
                RBRA    E_ADD_65, X             // Verify "relative branch X" is not taken.
                RBRA    L_ADD_65, !X            // Verify "relative branch nonX" is taken.
                HALT
E_ADD_65        HALT
L_ADD_65
                RBRA    E_ADD_66, !1            // Verify "relative branch never" is not taken.
                RBRA    L_ADD_66 1              // Verify "relative branch always" is taken.
                HALT
E_ADD_66        HALT
L_ADD_66
                MOVE    R14, R1                 // Verify status register: --110001
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


// ---------------------------------------------------------------------------
// Test the MOVE instruction doesn't change C and V flags.
L_MOVE_CV_00    MOVE    0x0000, R14             // Clear all bits in the status register

                MOVE    0x0000, R0              // Perform a MOVE instruction
                RBRA    E_MOVE_CV_01, V         // Verify "relative branch overflow" is not taken.
                RBRA    L_MOVE_CV_01, !V        // Verify "relative branch nonoverflow" is taken.
                HALT
E_MOVE_CV_01    HALT
L_MOVE_CV_01
                RBRA    E_MOVE_CV_02, C         // Verify "relative branch carry" is not taken.
                RBRA    L_MOVE_CV_02, !C        // Verify "relative branch noncarry" is taken.
                HALT
E_MOVE_CV_02    HALT
L_MOVE_CV_02

L_MOVE_CV_10    MOVE    0x00FF, R14             // Set all bits in the status register

                MOVE    0x0000, R0              // Perform a MOVE instruction
                RBRA    E_MOVE_CV_11, !V        // Verify "relative branch nonoverflow" is not taken.
                RBRA    L_MOVE_CV_11, V         // Verify "relative branch overflow" is taken.
                HALT
E_MOVE_CV_11    HALT
L_MOVE_CV_11
                RBRA    E_MOVE_CV_12, !C        // Verify "relative branch noncarry" is not taken.
                RBRA    L_MOVE_CV_12, C         // Verify "relative branch carry" is taken.
                HALT
E_MOVE_CV_12    HALT
L_MOVE_CV_12


// ---------------------------------------------------------------------------
// MOVE_MEM : Test the MOVE instruction to/from a memory address.

L_MOVE_MEM_00   MOVE    VAL1234, R0
                MOVE    VAL4321, R1
                MOVE    BSS0, R2
                MOVE    BSS1, R3
                MOVE    @R0, R4                 // Now R4 contains 0x1234
                MOVE    @R1, R5                 // Now R5 contains 0x4321

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

                MOVE    R4, @R2                 // Now BSS0 contains 0x1234
                MOVE    R5, @R3                 // Now BSS1 contains 0x4321

                CMP     R4, 0x1234              // R4 still contains 0x1234
                RBRA    E_MOVE_MEM_03, !Z
                RBRA    L_MOVE_MEM_03, Z
                HALT
E_MOVE_MEM_03   HALT
L_MOVE_MEM_03
                CMP     R5, 0x4321              // R5 still contains 0x4321
                RBRA    E_MOVE_MEM_04, !Z
                RBRA    L_MOVE_MEM_04, Z
                HALT
E_MOVE_MEM_04   HALT
L_MOVE_MEM_04

                MOVE    @R2, R5                 // Now R5 contains 0x1234
                MOVE    @R3, R4                 // Now R4 contains 0x4321

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


// ---------------------------------------------------------------------------
// Test the ADDC instruction

L_ADDC_00       MOVE    STIM_ADDC, R8
L_ADDC_01       MOVE    @R8, R0                 // First operand
                RBRA    L_ADDC_02, Z            // End of test
                ADD     0x0001, R8
                MOVE    @R8, R1                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                ADDC    R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_ADDC_01, !Z           // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the SUB instruction

L_SUB_00        MOVE    STIM_SUB, R8
L_SUB_01        MOVE    @R8, R1                 // First operand
                RBRA    L_SUB_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                SUB     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_SUB_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
                RBRA    L_SUB_01, Z
                HALT
E_SUB_01        HALT

STIM_SUB        .DW     0x5678, 0x4321, ST______, 0x1357, ST______
                .DW     0x5678, 0x5678, ST____C_, 0x0000, ST___Z__
                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST__N_CX
                .DW     0x5678, 0x89AB, ST____C_, 0xCCCD, ST_VN_C_
                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
                .DW     0x89AB, 0x4321, ST____C_, 0x468A, ST_V____

                .DW     0x0000

L_SUB_02


// ---------------------------------------------------------------------------
// Test the SUBC instruction

L_SUBC_00       MOVE    STIM_SUBC, R8
L_SUBC_01       MOVE    @R8, R1                 // First operand
                RBRA    L_SUBC_02, Z            // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                SUBC    R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_SUBC_01, !Z           // Jump if error
                CMP     R9, R4                  // Verify expected status
                RBRA    L_SUBC_01, Z
                HALT
E_SUBC_01       HALT

STIM_SUBC       .DW     0x5678, 0x4321, ST______, 0x1357, ST______
                .DW     0x5678, 0x5678, ST______, 0x0000, ST___Z__
                .DW     0x5678, 0x5679, ST______, 0xFFFF, ST__N_CX
                .DW     0x5678, 0x89AB, ST______, 0xCCCD, ST_VN_C_
                .DW     0x5678, 0xFEDC, ST______, 0x579C, ST____C_
                .DW     0x89AB, 0x4321, ST______, 0x468A, ST_V____

                .DW     0x5678, 0x4321, ST____C_, 0x1356, ST______
                .DW     0x5678, 0x5678, ST____C_, 0xFFFF, ST__N_CX
                .DW     0x5678, 0x5677, ST____C_, 0x0000, ST___Z__
                .DW     0x5678, 0x89AB, ST____C_, 0xCCCC, ST_VN_C_
                .DW     0x5678, 0xFEDC, ST____C_, 0x579B, ST____C_
                .DW     0x89AB, 0x4321, ST____C_, 0x4689, ST_V____

                .DW     0x0000

L_SUBC_02


// ---------------------------------------------------------------------------
// Test the SHL instruction

L_SHL_00        MOVE    STIM_SHL, R8
L_SHL_01        MOVE    @R8, R1                 // First operand
                RBRA    L_SHL_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                SHL     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_SHL_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
                RBRA    L_SHL_01, Z
                HALT
E_SHL_01        HALT

STIM_SHL
// X = 0, all other flags = 0
                .DW     0x5678, 0x0000, ST______, 0x5678, ST______
                .DW     0x5678, 0x0001, ST______, 0xACF0, ST______
                .DW     0x5678, 0x0002, ST______, 0x59E0, ST____C_
                .DW     0x5678, 0x0003, ST______, 0xB3C0, ST______
                .DW     0x5678, 0x0004, ST______, 0x6780, ST____C_
                .DW     0x5678, 0x0005, ST______, 0xCF00, ST______
                .DW     0x5678, 0x000F, ST______, 0x0000, ST______
                .DW     0xFFFF, 0x000F, ST______, 0x8000, ST____C_
                .DW     0xFFFF, 0x0010, ST______, 0x0000, ST____C_
                .DW     0xFFFF, 0x0011, ST______, 0x0000, ST______
                .DW     0xFFFF, 0x8000, ST______, 0x0000, ST______
                .DW     0xFFFF, 0xFFF0, ST______, 0x0000, ST______
                .DW     0xFFFF, 0xFFF8, ST______, 0x0000, ST______
                .DW     0xFFFF, 0xFFFC, ST______, 0x0000, ST______
                .DW     0xFFFF, 0xFFFE, ST______, 0x0000, ST______
                .DW     0xFFFF, 0xFFFF, ST______, 0x0000, ST______

// X = 0, all other flags = 1
                .DW     0x5678, 0x0000, ST_VNZC_, 0x5678, ST_VNZC_   // C is unchanged when shifting zero bits
                .DW     0x5678, 0x0001, ST_VNZC_, 0xACF0, ST_VNZ__
                .DW     0x5678, 0x0002, ST_VNZC_, 0x59E0, ST_VNZC_
                .DW     0x5678, 0x0003, ST_VNZC_, 0xB3C0, ST_VNZ__
                .DW     0x5678, 0x0004, ST_VNZC_, 0x6780, ST_VNZC_
                .DW     0x5678, 0x0005, ST_VNZC_, 0xCF00, ST_VNZ__
                .DW     0x5678, 0x000F, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0x000F, ST_VNZC_, 0x8000, ST_VNZC_
                .DW     0xFFFF, 0x0010, ST_VNZC_, 0x0000, ST_VNZC_
                .DW     0xFFFF, 0x0011, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0x8000, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0xFFF0, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0xFFF8, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0xFFFC, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0xFFFE, ST_VNZC_, 0x0000, ST_VNZ__
                .DW     0xFFFF, 0xFFFF, ST_VNZC_, 0x0000, ST_VNZ__

// X = 1, all other flags = 0
                .DW     0x5678, 0x0000, ST_____X, 0x5678, ST_____X
                .DW     0x5678, 0x0001, ST_____X, 0xACF1, ST_____X
                .DW     0x5678, 0x0002, ST_____X, 0x59E3, ST____CX
                .DW     0x5678, 0x0003, ST_____X, 0xB3C7, ST_____X
                .DW     0x5678, 0x0004, ST_____X, 0x678F, ST____CX
                .DW     0x5678, 0x0005, ST_____X, 0xCF1F, ST_____X
                .DW     0x5678, 0x000F, ST_____X, 0x7FFF, ST_____X
                .DW     0xFFFF, 0x000F, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0x0010, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0x0011, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0x8000, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0xFFF0, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0xFFF8, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0xFFFC, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0xFFFE, ST_____X, 0xFFFF, ST____CX
                .DW     0xFFFF, 0xFFFF, ST_____X, 0xFFFF, ST____CX

// X = 1, all other flags = 1
                .DW     0x5678, 0x0000, ST_VNZCX, 0x5678, ST_VNZCX   // C is unchanged when shifting zero bits
                .DW     0x5678, 0x0001, ST_VNZCX, 0xACF1, ST_VNZ_X
                .DW     0x5678, 0x0002, ST_VNZCX, 0x59E3, ST_VNZCX
                .DW     0x5678, 0x0003, ST_VNZCX, 0xB3C7, ST_VNZ_X
                .DW     0x5678, 0x0004, ST_VNZCX, 0x678F, ST_VNZCX
                .DW     0x5678, 0x0005, ST_VNZCX, 0xCF1F, ST_VNZ_X
                .DW     0x5678, 0x000F, ST_VNZCX, 0x7FFF, ST_VNZ_X
                .DW     0xFFFF, 0x000F, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0x0010, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0x0011, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0x8000, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0xFFF0, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0xFFF8, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0xFFFC, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0xFFFE, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0xFFFF, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VNZCX

                .DW     0x0000

L_SHL_02


// ---------------------------------------------------------------------------
// Test the SHR instruction

L_SHR_00        MOVE    STIM_SHR, R8
L_SHR_01        MOVE    @R8, R1                 // First operand
                RBRA    L_SHR_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                SHR     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_SHR_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
                RBRA    L_SHR_01, Z
                HALT
E_SHR_01        HALT

STIM_SHR
// C = 0, all other flags = 0
                .DW     0x8765, 0x0000, ST______, 0x8765, ST______
                .DW     0x8765, 0x0001, ST______, 0x43B2, ST_____X
                .DW     0x8765, 0x0002, ST______, 0x21D9, ST______
                .DW     0x8765, 0x0003, ST______, 0x10EC, ST_____X
                .DW     0x8765, 0x0004, ST______, 0x0876, ST______
                .DW     0x8765, 0x0005, ST______, 0x043B, ST______
                .DW     0x8765, 0x000F, ST______, 0x0001, ST______
                .DW     0x8765, 0x0010, ST______, 0x0000, ST_____X
                .DW     0x8765, 0x0011, ST______, 0x0000, ST______
                .DW     0x8765, 0x8000, ST______, 0x0000, ST______
                .DW     0x8765, 0xFFF0, ST______, 0x0000, ST______
                .DW     0x8765, 0xFFF8, ST______, 0x0000, ST______
                .DW     0x8765, 0xFFFC, ST______, 0x0000, ST______
                .DW     0x8765, 0xFFFE, ST______, 0x0000, ST______
                .DW     0x8765, 0xFFFF, ST______, 0x0000, ST______
// C = 0, all other flags = 1
                .DW     0x8765, 0x0000, ST_VNZ_X, 0x8765, ST_VNZ_X    // X is unchanged when shifting zero bits
                .DW     0x8765, 0x0001, ST_VNZ_X, 0x43B2, ST_VNZ_X
                .DW     0x8765, 0x0002, ST_VNZ_X, 0x21D9, ST_VNZ__
                .DW     0x8765, 0x0003, ST_VNZ_X, 0x10EC, ST_VNZ_X
                .DW     0x8765, 0x0004, ST_VNZ_X, 0x0876, ST_VNZ__
                .DW     0x8765, 0x0005, ST_VNZ_X, 0x043B, ST_VNZ__
                .DW     0x8765, 0x000F, ST_VNZ_X, 0x0001, ST_VNZ__
                .DW     0x8765, 0x0010, ST_VNZ_X, 0x0000, ST_VNZ_X
                .DW     0x8765, 0x0011, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0x8000, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0xFFF0, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0xFFF8, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0xFFFC, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0xFFFE, ST_VNZ_X, 0x0000, ST_VNZ__
                .DW     0x8765, 0xFFFF, ST_VNZ_X, 0x0000, ST_VNZ__
// C = 1, all other flags = 0
                .DW     0x8765, 0x0000, ST____C_, 0x8765, ST____C_
                .DW     0x8765, 0x0001, ST____C_, 0xC3B2, ST____CX
                .DW     0x8765, 0x0002, ST____C_, 0xE1D9, ST____C_
                .DW     0x8765, 0x0003, ST____C_, 0xF0EC, ST____CX
                .DW     0x8765, 0x0004, ST____C_, 0xF876, ST____C_
                .DW     0x8765, 0x0005, ST____C_, 0xFC3B, ST____C_
                .DW     0x8765, 0x000F, ST____C_, 0xFFFF, ST____C_
                .DW     0x8765, 0x0010, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0x0011, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0x8000, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0xFFF0, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0xFFF8, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0xFFFC, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0xFFFE, ST____C_, 0xFFFF, ST____CX
                .DW     0x8765, 0xFFFF, ST____C_, 0xFFFF, ST____CX
// C = 1, all other flags = 1
                .DW     0x8765, 0x0000, ST_VNZCX, 0x8765, ST_VNZCX   // X is unchanged when shifting zero bits
                .DW     0x8765, 0x0001, ST_VNZCX, 0xC3B2, ST_VNZCX
                .DW     0x8765, 0x0002, ST_VNZCX, 0xE1D9, ST_VNZC_
                .DW     0x8765, 0x0003, ST_VNZCX, 0xF0EC, ST_VNZCX
                .DW     0x8765, 0x0004, ST_VNZCX, 0xF876, ST_VNZC_
                .DW     0x8765, 0x0005, ST_VNZCX, 0xFC3B, ST_VNZC_
                .DW     0x8765, 0x000F, ST_VNZCX, 0xFFFF, ST_VNZC_
                .DW     0x8765, 0x0010, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0x0011, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0x8000, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0xFFF0, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0xFFF8, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0xFFFC, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0xFFFE, ST_VNZCX, 0xFFFF, ST_VNZCX
                .DW     0x8765, 0xFFFF, ST_VNZCX, 0xFFFF, ST_VNZCX

                .DW     0x0000

L_SHR_02


// ---------------------------------------------------------------------------
// Test the SWAP instruction

L_SWAP_00       MOVE    STIM_SWAP, R8
L_SWAP_01       MOVE    @R8, R0                 // First operand
                CMP     0x1111, R0
                RBRA    L_SWAP_02, Z            // End of test
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                SWAP    R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_SWAP_01, !Z           // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the NOT instruction

L_NOT_00        MOVE    STIM_NOT, R8
L_NOT_01        MOVE    @R8, R0                 // First operand
                CMP     0x1111, R0
                RBRA    L_NOT_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                NOT     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_NOT_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the AND instruction

L_AND_00        MOVE    STIM_AND, R8
L_AND_01        MOVE    @R8, R1                 // First operand
                CMP     0x1111, R1
                RBRA    L_AND_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                AND     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_AND_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the OR instruction

L_OR_00         MOVE    STIM_OR, R8
L_OR_01         MOVE    @R8, R1                 // First operand
                CMP     0x1111, R1
                RBRA    L_OR_02, Z              // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                OR      R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_OR_01, !Z             // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the XOR instruction

L_XOR_00        MOVE    STIM_XOR, R8
L_XOR_01        MOVE    @R8, R1                 // First operand
                CMP     0x1111, R1
                RBRA    L_XOR_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                XOR     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_XOR_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
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


// ---------------------------------------------------------------------------
// Test the CMP instruction

L_CMP_00        MOVE    STIM_CMP, R8
L_CMP_01        MOVE    @R8, R1                 // First operand
                CMP     0x1111, R1
                RBRA    L_CMP_02, Z             // End of test
                ADD     0x0001, R8
                MOVE    @R8, R0                 // Second operand
                ADD     0x0001, R8
                MOVE    @R8, R2                 // Carry input
                ADD     0x0001, R8
                MOVE    @R8, R3                 // Expected result
                ADD     0x0001, R8
                MOVE    @R8, R4                 // Expected status
                ADD     0x0001, R8

                MOVE    R2, R14                 // Set carry input
                CMP     R0, R1
                MOVE    R14, R9                 // Copy status
                CMP     R1, R3                  // Verify expected result
                RBRA    E_CMP_01, !Z            // Jump if error
                CMP     R9, R4                  // Verify expected status
                RBRA    L_CMP_01, Z
                HALT
E_CMP_01        HALT

STIM_CMP        .DW     0x5678, 0x4321, ST______, 0x5678, ST______
                .DW     0x4321, 0x5678, ST______, 0x4321, ST_VN___
                .DW     0x4321, 0xF678, ST______, 0x4321, ST__N___
                .DW     0xF678, 0x4321, ST______, 0xF678, ST_V____
                .DW     0x7777, 0x7777, ST______, 0x7777, ST___Z__
                .DW     0x8888, 0x8888, ST______, 0x8888, ST___Z__

                .DW     0x5678, 0x4321, ST_VNZCX, 0x5678, ST____CX
                .DW     0x4321, 0x5678, ST_VNZCX, 0x4321, ST_VN_CX
                .DW     0x4321, 0xF678, ST_VNZCX, 0x4321, ST__N_CX
                .DW     0xF678, 0x4321, ST_VNZCX, 0xF678, ST_V__CX
                .DW     0x7777, 0x7777, ST_VNZCX, 0x7777, ST___ZCX
                .DW     0x8888, 0x8888, ST_VNZCX, 0x8888, ST___ZCX

                .DW     0x1111

L_CMP_02


// ---------------------------------------------------------------------------
// Test the MOVE instruction with all addressing modes

// MOVE R1, @R2
// MOVE @R2, R1
// MOVE @R2++, R1
// MOVE @--R2, R1
L_MOVE_AM_00    MOVE    0x1234, R1
                MOVE    AM_BSS, R2
                MOVE    R1, @R2                 // Store R1 into @R2
                CMP     R1, 0x1234              // Verify R1 unchanged
                RBRA    E_MOVE_AM_01, !Z        // Jump if error
                CMP     R2, AM_BSS              // Verify R2 unchanged
                RBRA    E_MOVE_AM_02, !Z        // Jump if error

                MOVE    0x0000, R1              // Clear R1
                MOVE    @R2, R1                 // Read R1 from @R2
                CMP     R1, 0x1234              // Verify correct value read
                RBRA    E_MOVE_AM_03, !Z        // Jump if error
                CMP     R2, AM_BSS              // Verify R2 unchanged
                RBRA    E_MOVE_AM_04, !Z        // Jump if error

                MOVE    0x0000, R1              // Clear R1
                MOVE    @R2++, R1               // Read R1 from @R2 and increment R2
                CMP     R1, 0x1234              // Verify correct value read
                RBRA    E_MOVE_AM_05, !Z        // Jump if error
                CMP     R2, AM_BSS1             // Verify R2 incremented
                RBRA    E_MOVE_AM_06, !Z        // Jump if error

                MOVE    0x0000, R1              // Clear R1
                MOVE    @--R2, R1               // Decrement R2 and read R1 from @R2
                CMP     R1, 0x1234              // Verify correct value read
                RBRA    E_MOVE_AM_07, !Z        // Jump if error
                CMP     R2, AM_BSS              // Verify R2 decremented
                RBRA    E_MOVE_AM_08, !Z        // Jump if error

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

// MOVE R1, @R2++
// MOVE R1, @--R2
L_MOVE_AM_10
                MOVE    0x1234, R1
                MOVE    AM_BSS, R3
                MOVE    AM_BSS1, R4
                MOVE    R1, @R3                 // Store dummy value into @R3
                MOVE    R1, @R4                 // Store dummy value into @R4

                MOVE    0x4321, R0
                MOVE    AM_BSS, R2

                MOVE    R0, @R2++               // Store R0 into @R2 and increment R2
                CMP     R0, 0x4321              // Verify R0 unchanged
                RBRA    E_MOVE_AM_11, !Z        // Jump if error
                CMP     R2, AM_BSS1             // Verify R2 incremented
                RBRA    E_MOVE_AM_12, !Z        // Jump if error

                MOVE    @R3, R8                 // Read back value stored in @R3
                CMP     R8, R0                  // Verify value was correctly written
                RBRA    E_MOVE_AM_13, !Z        // Jump if error

                MOVE    @R4, R8                 // Read back value stored in @R4
                CMP     R8, R1                  // Verify value was unchanged
                RBRA    E_MOVE_AM_14, !Z        // Jump if error

                MOVE    0x5678, R0
                MOVE    R0, @--R2               // Decrement R2 and store R0 into @R2
                CMP     R0, 0x5678              // Verify R0 unchanged
                RBRA    E_MOVE_AM_15, !Z        // Jump if error
                CMP     R2, AM_BSS              // Verify R2 decremented
                RBRA    E_MOVE_AM_16, !Z        // Jump if error

                MOVE    @R3, R8                 // Read back value stored in @R3
                CMP     R8, R0                  // Verify value was correctly written
                RBRA    E_MOVE_AM_17, !Z        // Jump if error

                MOVE    @R4, R8                 // Read back value stored in @R4
                CMP     R8, R1                  // Verify value was unchanged
                RBRA    E_MOVE_AM_18, !Z        // Jump if error

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

// MOVE @R1, @R2
L_MOVE_AM_20
                MOVE    0x2345, R0
                MOVE    AM_BSS, R3
                MOVE    R0, @R3                 // Store dummy value into @R3
                MOVE    0x5432, R0
                MOVE    AM_BSS2, R4
                MOVE    R0, @R4                 // Store dummy value into @R4

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2

                MOVE    @R1, @R2                // Copy @R1 to @R2

                CMP     R1, AM_BSS              // Verify R1 unchanged
                RBRA    E_MOVE_AM_21, !Z        // Jump if error
                CMP     R2, AM_BSS2             // Verify R2 unchanged
                RBRA    E_MOVE_AM_22, !Z        // Jump if error

                MOVE    @R3, R8                 // Read from AM_BSS
                CMP     R8, 0x2345              // Verify unchanged
                RBRA    E_MOVE_AM_23, !Z        // Jump if error
                MOVE    @R4, R8                 // Read from AM_BSS1
                CMP     R8, 0x2345              // Verify correct value written
                RBRA    E_MOVE_AM_24, !Z        // Jump if error
                RBRA    L_MOVE_AM_21, 1
E_MOVE_AM_21    HALT
E_MOVE_AM_22    HALT
E_MOVE_AM_23    HALT
E_MOVE_AM_24    HALT
L_MOVE_AM_21

// MOVE @R1, @R2++
// MOVE @R1, @--R2
L_MOVE_AM_30
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x3456, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x6543, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    R0, @R7                 // Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1, @R2++              // Copy @R1 to @R2 and increment R2

                CMP     R1, R4                  // Verify R1 unchanged
                RBRA    E_MOVE_AM_31, !Z        // Jump if error
                CMP     R2, R7                  // Verify R2 incremented
                RBRA    E_MOVE_AM_32, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_33, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x3456              // Verify correct value
                RBRA    E_MOVE_AM_34, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_345, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x3456              // Verify correct value
                RBRA    E_MOVE_AM_35, !Z        // Jump if error

                MOVE    0x6543, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    @R1, @--R2              // Decrement R2 and copy @R1 to @R2

                CMP     R1, R4                  // Verify R1 unchanged
                RBRA    E_MOVE_AM_36, !Z        // Jump if error
                CMP     R2, R6                  // Verify R2 decremented
                RBRA    E_MOVE_AM_37, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_38, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x6543              // Verify correct value
                RBRA    E_MOVE_AM_39, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_395, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x6543              // Verify correct value
                RBRA    E_MOVE_AM_399, !Z       // Jump if error

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

// MOVE @R1++, @R2
// MOVE @--R1, @R2
L_MOVE_AM_40
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x4567, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x7654, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    R0, @R7                 // Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1++, @R2              // Copy @R1 to @R2 and increment R1

                CMP     R1, R5                  // Verify R1 incremented
                RBRA    E_MOVE_AM_41, !Z        // Jump if error
                CMP     R2, R6                  // Verify R2 unchanged
                RBRA    E_MOVE_AM_42, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_43, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x4567              // Verify correct value
                RBRA    E_MOVE_AM_44, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_445, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x4567              // Verify correct value
                RBRA    E_MOVE_AM_45, !Z        // Jump if error

                MOVE    0x7654, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    @--R1, @R2              // Decrement R1 and copy @R1 to @R2

                CMP     R1, R4                  // Verify R1 decremented
                RBRA    E_MOVE_AM_46, !Z        // Jump if error
                CMP     R2, R6                  // Verify R2 unchanged
                RBRA    E_MOVE_AM_47, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_48, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x7654              // Verify correct value
                RBRA    E_MOVE_AM_49, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_495, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x7654              // Verify correct value
                RBRA    E_MOVE_AM_499, !Z       // Jump if error

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


// MOVE @R1++, @R2++
// MOVE @--R1, @--R2
L_MOVE_AM_50
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x5678, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x8765, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    R0, @R7                 // Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS2, R2
                MOVE    @R1++, @R2++            // Copy @R1 to @R2 and increment R1 and R2

                CMP     R1, R5                  // Verify R1 incremented
                RBRA    E_MOVE_AM_51, !Z        // Jump if error
                CMP     R2, R7                  // Verify R2 incremented
                RBRA    E_MOVE_AM_52, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_53, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x5678              // Verify correct value
                RBRA    E_MOVE_AM_54, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_545, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x5678              // Verify correct value
                RBRA    E_MOVE_AM_55, !Z        // Jump if error

                MOVE    0x8765, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    @--R1, @--R2            // Decrement R1 and R2 and copy @R1 to @R2

                CMP     R1, R4                  // Verify R1 decremented
                RBRA    E_MOVE_AM_56, !Z        // Jump if error
                CMP     R2, R6                  // Verify R2 decremented
                RBRA    E_MOVE_AM_57, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_58, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x8765              // Verify correct value
                RBRA    E_MOVE_AM_59, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_595, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x8765              // Verify correct value
                RBRA    E_MOVE_AM_599, !Z       // Jump if error

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

// MOVE @R1++, @--R2
// MOVE @--R1, @R2++

L_MOVE_AM_60
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    AM_BSS3, R7
                MOVE    0x6789, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x9876, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2
                MOVE    0x0000, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    R0, @R7                 // Store dummy value into AM_BSS3

                MOVE    AM_BSS, R1
                MOVE    AM_BSS3, R2
                MOVE    @R1++, @--R2            // Decrement R2, copy @R1 to @R2 and increment R1

                CMP     R1, R5                  // Verify R1 incremented
                RBRA    E_MOVE_AM_61, !Z        // Jump if error
                CMP     R2, R6                  // Verify R2 decremented
                RBRA    E_MOVE_AM_62, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_63, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x6789              // Verify correct value
                RBRA    E_MOVE_AM_64, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_645, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x6789              // Verify correct value
                RBRA    E_MOVE_AM_65, !Z        // Jump if error

                MOVE    0x9876, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    @--R1, @R2++            // Decrement R1 and copy @R1 to @R2 and increment R2

                CMP     R1, R4                  // Verify R1 decremented
                RBRA    E_MOVE_AM_66, !Z        // Jump if error
                CMP     R2, R7                  // Verify R2 incremented
                RBRA    E_MOVE_AM_67, !Z        // Jump if error

                MOVE    @R7, R0                 // Verify AM_BSS3 unchanged
                RBRA    E_MOVE_AM_68, !Z        // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x9876              // Verify correct value
                RBRA    E_MOVE_AM_69, !Z        // Jump if error
                MOVE    @R5, R0                 // Verify AM_BSS1 unchanged
                RBRA    E_MOVE_AM_695, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x9876              // Verify correct value
                RBRA    E_MOVE_AM_699, !Z       // Jump if error

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


// ---------------------------------------------------------------------------
// Test the MOVE instruction with all addressing modes, where source and
// destination registers are the same

// MOVE @R1, R1
// MOVE R1, @R1

L_MOVE_AM2_00
                MOVE    AM_BSS, R4
                MOVE    0x3456, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS

                MOVE    AM_BSS, R1
                MOVE    @R1, R1                 // Copy @R1 to R1

                CMP     R1, 0x3456              // Verify correct value read
                RBRA    E_MOVE_AM2_01, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x3456              // Verify correct value
                RBRA    E_MOVE_AM2_02, !Z       // Jump if error

                MOVE    AM_BSS, R1
                MOVE    R1, @R1                 // Copy R1 to @R1

                CMP     R1, AM_BSS              // Verify R1 unchanged
                RBRA    E_MOVE_AM2_03, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, AM_BSS              // Verify correct value
                RBRA    E_MOVE_AM2_04, !Z       // Jump if error

                RBRA    L_MOVE_AM2_01, 1
E_MOVE_AM2_01   HALT
E_MOVE_AM2_02   HALT
E_MOVE_AM2_03   HALT
E_MOVE_AM2_04   HALT
L_MOVE_AM2_01

// MOVE @--R1, R1
// MOVE R1, @R1++

L_MOVE_AM2_10
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x3456, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x6543, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1

                MOVE    AM_BSS1, R1
                MOVE    @--R1, R1               // Decrement R1, and copy @R1 to R1

                CMP     R1, 0x3456              // Verify correct value
                RBRA    E_MOVE_AM2_11, !Z       // Jump if error

                MOVE    AM_BSS, R1
                MOVE    R1, @R1++               // Copy R1 to @R1 and increment R1

                CMP     R1, AM_BSS1             // Verify R1 incremented
                RBRA    E_MOVE_AM2_12, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, AM_BSS              // Verify correct value
                RBRA    E_MOVE_AM2_13, !Z       // Jump if error

                RBRA    L_MOVE_AM2_11, 1
E_MOVE_AM2_11   HALT
E_MOVE_AM2_12   HALT
E_MOVE_AM2_13   HALT
L_MOVE_AM2_11

// MOVE @R1++, R1
// MOVE R1, @--R1

L_MOVE_AM2_20
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x4567, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x7654, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1

                MOVE    AM_BSS, R1
                MOVE    @R1++, R1               // Copy @R1 to R1

                CMP     R1, 0x4567              // Verify correct value
                RBRA    E_MOVE_AM2_21, !Z       // Jump if error

                MOVE    AM_BSS1, R1
                MOVE    R1, @--R1               // Copy R1 to @(R1-1) and decrement R1

                CMP     R1, AM_BSS              // Verify R1 decremented
                RBRA    E_MOVE_AM2_22, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, AM_BSS1             // Verify correct value
                RBRA    E_MOVE_AM2_23, !Z       // Jump if error

                RBRA    L_MOVE_AM2_21, 1
E_MOVE_AM2_21   HALT
E_MOVE_AM2_22   HALT
E_MOVE_AM2_23   HALT
L_MOVE_AM2_21

// MOVE @R1, @R1++
// MOVE @--R1, @R1

L_MOVE_AM2_30
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x5678, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x8765, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1

                MOVE    AM_BSS, R1
                MOVE    @R1, @R1++              // Copy @R1 to @R1++

                CMP     R1, AM_BSS1             // Verify R1 incremented
                RBRA    E_MOVE_AM2_31, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x8765              // Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       // Jump if error

                MOVE    AM_BSS1, R1
                MOVE    @--R1, @R1              // Copy @--R1 to @R1

                CMP     R1, AM_BSS              // Verify R1 decremented
                RBRA    E_MOVE_AM2_34, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_33, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x8765              // Verify value unchanged
                RBRA    E_MOVE_AM2_36, !Z       // Jump if error

                RBRA    L_MOVE_AM2_31, 1
E_MOVE_AM2_31   HALT
E_MOVE_AM2_32   HALT
E_MOVE_AM2_33   HALT
E_MOVE_AM2_34   HALT
E_MOVE_AM2_35   HALT
E_MOVE_AM2_36   HALT
L_MOVE_AM2_31

// MOVE @R1, @--R1
// MOVE @R1++, @R1

L_MOVE_AM2_40
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    0x6789, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x9876, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1

                MOVE    AM_BSS1, R1
                MOVE    @R1, @--R1              // Copy @R1 to @--R1

                CMP     R1, AM_BSS              // Verify R1 decremented
                RBRA    E_MOVE_AM2_41, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x9876              // Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x9876              // Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       // Jump if error

                MOVE    0x6789, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    AM_BSS, R1
                MOVE    @R1++, @R1              // Copy @R1++ to @R1

                CMP     R1, AM_BSS1             // Verify R1 incremented
                RBRA    E_MOVE_AM2_44, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x6789              // Verify value unchanged
                RBRA    E_MOVE_AM2_43, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x6789              // Verify value unchanged
                RBRA    E_MOVE_AM2_46, !Z       // Jump if error

                RBRA    L_MOVE_AM2_41, 1
E_MOVE_AM2_41   HALT
E_MOVE_AM2_42   HALT
E_MOVE_AM2_43   HALT
E_MOVE_AM2_44   HALT
E_MOVE_AM2_45   HALT
E_MOVE_AM2_46   HALT
L_MOVE_AM2_41

// MOVE @R1++, @R1++
// MOVE @--R1, @--R1

L_MOVE_AM2_50
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    0x1234, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x4321, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    0x5678, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2

                MOVE    AM_BSS, R1
                MOVE    @R1++, @R1++            // Copy @R1++ to @R1++

                CMP     R1, AM_BSS2             // Verify R1 incremented twice
                RBRA    E_MOVE_AM2_51, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x1234              // Verify value unchanged
                RBRA    E_MOVE_AM2_53, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x1234              // Verify value correctly updated
                RBRA    E_MOVE_AM2_53, !Z       // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_54, !Z       // Jump if error

                MOVE    0x4321, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    AM_BSS2, R1
                MOVE    @--R1, @--R1            // Copy @--R1 to @--R1

                CMP     R1, AM_BSS              // Verify R1 decremented twice
                RBRA    E_MOVE_AM2_55, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x4321              // Verify value unchanged
                RBRA    E_MOVE_AM2_56, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x4321              // Verify value unchanged
                RBRA    E_MOVE_AM2_57, !Z       // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_58, !Z       // Jump if error

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

// MOVE @R1++, @--R1
// MOVE @--R1, @R1++

L_MOVE_AM2_60
                MOVE    AM_BSS, R4
                MOVE    AM_BSS1, R5
                MOVE    AM_BSS2, R6
                MOVE    0x1234, R0
                MOVE    R0, @R4                 // Store dummy value into AM_BSS
                MOVE    0x4321, R0
                MOVE    R0, @R5                 // Store dummy value into AM_BSS1
                MOVE    0x5678, R0
                MOVE    R0, @R6                 // Store dummy value into AM_BSS2

                MOVE    AM_BSS1, R1
                MOVE    @R1++, @--R1            // Copy @R1++ to @--R1

                CMP     R1, AM_BSS1             // Verify R1 unchanged
                RBRA    E_MOVE_AM2_61, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x1234              // Verify value unchanged
                RBRA    E_MOVE_AM2_62, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x4321              // Verify value unchanged
                RBRA    E_MOVE_AM2_63, !Z       // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_64, !Z       // Jump if error

                MOVE    AM_BSS1, R1
                MOVE    @--R1, @R1++            // Copy @--R1 to @R1++

                CMP     R1, AM_BSS1             // Verify R1 unchanged
                RBRA    E_MOVE_AM2_65, !Z       // Jump if error
                MOVE    @R4, R0                 // Read from AM_BSS
                CMP     R0, 0x1234              // Verify value unchanged
                RBRA    E_MOVE_AM2_66, !Z       // Jump if error
                MOVE    @R5, R0                 // Read from AM_BSS1
                CMP     R0, 0x4321              // Verify value unchanged
                RBRA    E_MOVE_AM2_67, !Z       // Jump if error
                MOVE    @R6, R0                 // Read from AM_BSS2
                CMP     R0, 0x5678              // Verify value unchanged
                RBRA    E_MOVE_AM2_68, !Z       // Jump if error

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



// Everything worked as expected! We are done now.
EXIT            MOVE    OK, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

OK              .ASCII_W    "OK\n"



// The OLD version of cpu_test is here for now. TBD: Remove


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
