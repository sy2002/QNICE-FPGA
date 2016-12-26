; EAE - Extended Arithmetic Element test
; assumes that each EAE calculation is done combinatorically, i.e. that
; there is no need to wait for the 'busy' signal of the EAE
; done by sy2002 in May 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000
                
                ; EAE registers
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    IO$EAE_OPERAND_1, R1
                MOVE    IO$EAE_RESULT_LO, R2
                MOVE    IO$EAE_RESULT_HI, R3
                MOVE    IO$EAE_CSR, R4

                ; unsigned: 0x91D9 x 0x2CB1 = 0x19762309
                MOVE    0x91D9, @R0
                MOVE    0x2CB1, @R1
                MOVE    EAE$MULU, @R4
                MOVE    @R3, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; signed: decimal -13.422 x 50 = -671.100 = 0xFFF5C284  
                MOVE    -13422, @R0
                MOVE    50, @R1
                MOVE    EAE$MULS, @R4
                MOVE    @R3, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; unsigned: 0x2309 / 0x0076 = 0x004C and modulo is 0x0001
                ; so the printed output is 004C0001
                MOVE    0x2309, @R0
                MOVE    0x0076, @R1
                MOVE    EAE$DIVU, @R4
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R3, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; signed: decimal -32.009 / 16 = -2.000 = modulo is 9
                ; so the printed output is F8300007
                MOVE    -32009, @R0
                MOVE    16, @R1
                MOVE    EAE$DIVS, @R4
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R3, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)
