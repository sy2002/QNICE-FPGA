; This is a small test program to test the new ISA for V1.6
; Specifically, we test the instructions INCRB and DECRB and HALT.
; See Issue #65.
;
; Before proceeding, make sure that you entered "source setenv.source" in
; your terminal, which is located in the "c" folder. This sets the path
; and the environment variables correctly.
;
; Enter this command to assemble, link and to create a QNICE .out file:
; qvasm vasm_test_isa_16.asm
;
; done by MJoergen in August 2020

.include "qnice-conv.vasm"
.include "monitor.vdef"

        MOVE        1, R14             ; Set register bank to zero

        MOVE        R14, R10           ; Verify register bank is zero
        SHR         8, R10
        CMP         0, R10
        RBRA        E1, !Z

        INCRB                          ; Increment register bank
        MOVE        R14, R10           ; Verify register bank is one
        SHR         8, R10
        CMP         1, R10
        RBRA        E2, !Z

        DECRB                          ; Decrement register bank
        MOVE        R14, R10           ; Verify register bank is zero
        AND         0x0100, R10
        CMP         0, R10
        RBRA        E3, !Z

        MOVE        #OK, R8
        SYSCALL     puts, 1

        MOVE        #EXPECT_HALT, R8
        SYSCALL     puts, 1

        HALT
        SYSCALL     exit, 1

E1:
E2:
E3:
        MOVE        #ERROR, R8
        SYSCALL     puts, 1
        SYSCALL     exit, 1

ERROR:
.word "An error occurred.\n", 0
OK:
.word "So far so good!\n", 0
EXPECT_HALT:
.word "Now we try to execute a halt!\n", 0

