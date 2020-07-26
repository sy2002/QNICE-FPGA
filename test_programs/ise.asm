; Test program for reproducing "The ISE vs. Vivado riddle" as described on
; GitHub here:
;
; What this program does: Reset the hardware cycle counter (which is increased
; at each clock cycle - as the time of making 50 MHu) and the hardware
; instruction counter (which is increased at each new instruction fetch).
;
; Both counters can be used together to measure the MIPS throughput of
; QNICE-FPGA, for example by running the two performance test programs
; "test_programs/mandel_perf_test.asm" and 
; "test_programs/q-tris_perf_test.asm": Both versions of these demos will
; output the amount of cycles and the amount of instructions after they end.
;
; What is expected as an output is something like this:
;
;   Amount of cycles used:            000000000041
;   Amount of instructions performed: 000000000012
;
; These values are hexadecimal values.
;
; done by sy2002 in July 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"                

                .ORG    0x8000

                ; start the counters (reset also starts them)
                MOVE    IO$CYC_STATE, R0    ; reset hw cycle counter
                MOVE    1, @R0
                MOVE    IO$INS_STATE, R0    ; reset hw instruction counter
                MOVE    1, @R0

                ; do some work
                MOVE    1, R1
                MOVE    2, R2
                MOVE    3, R3
                MOVE    4, R4
                XOR     R1, R1
                ADD     R1, R2
                XOR     R3, R2
                SUB     R4, R2
                NOP
                NOP
                NOP
                MOVE    5, R5
                MOVE    6, R6
                ADD     R6, R4

                ; stop the counters
                MOVE    IO$CYC_STATE, R0
                MOVE    0, @R0
                MOVE    IO$INS_STATE, R0
                MOVE    0, @R0

                ; output cycle counter
                MOVE    STR_CYC, R8
                SYSCALL(puts, 1)
                MOVE    IO$CYC_HI, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output hi word of 48bit counter
                MOVE    IO$CYC_MID, R1
                MOVE    @R1, R8 
                SYSCALL(puthex, 1)          ; output mid word of 48bit counter
                MOVE    IO$CYC_LO, R1
                MOVE    @R1, R8
                SYSCALL(puthex, 1)          ; output lo word of 48bit counter                
                SYSCALL(crlf, 1)

                ; output instruction counter
                MOVE    STR_INS, R8
                SYSCALL(puts, 1)
                MOVE    IO$INS_HI, R1
                MOVE    @R1, R8
                SYSCALL(puthex, 1)          ; output hi word of 48bit counter
                MOVE    IO$INS_MID, R1
                MOVE    @R1, R8
                SYSCALL(puthex, 1)          ; output mid word of 48bit counter
                MOVE    IO$INS_LO, R1
                MOVE    @R1, R8
                SYSCALL(puthex, 1)          ; output lo word of 48bit counter

                SYSCALL(crlf, 1)
                SYSCALL(exit, 1)

STR_CYC        .ASCII_W "Amount of cycles used:            "
STR_INS        .ASCII_W "Amount if instructions performed: "
