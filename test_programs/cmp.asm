; Various CMP tests including register outputs with including
; borderline cases pos/neg
; done by vaxman and sy2002 in May 2016

#include "../dist_kit/monitor.def"
#include "../dist_kit/sysdef.asm"

                .ORG 0x8000

                MOVE    0x10, R0

                ; should output 0x0001
                CMPU    0xF, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0009
                CMPU    0x10, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0033
                CMPU    0x11, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0x9000, R0

                ; should output 0x0011
                CMPU    0x11, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0021
                CMPU    0x8FFF, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0029
                CMPU    0x9000, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0013
                CMPU    0x9001, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)


                ; Signed...

                ; should output 0x0001
                CMPS    0xF, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0009
                CMPS    0x10, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0033
                CMPS    0x11, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0x9000, R0

                ; should output 0x0011
                CMPS    0x11, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0021
                CMPS    0x8FFF, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0029
                CMPS    0x9000, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; should output 0x0013
                CMPS    0x9001, R0
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)
