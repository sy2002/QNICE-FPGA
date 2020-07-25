#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"                

                .ORG    0x8000

                ;MOVE    IO$CYC_STATE, R0    ; reset hw cycle counter
                ;MOVE    1, @R0
                ;MOVE    IO$INS_STATE, R0    ; reset hw instruction counter
                ;MOVE    1, @R0

                ; output cycle counter

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
