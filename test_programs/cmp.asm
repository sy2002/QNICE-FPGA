; Various CMP tests including register outputs with including
; borderline cases pos/neg
; done by vaxman and sy2002 in May 2016

#include "../dist_kit/monitor.def"
#include "../dist_kit/sysdef.asm"

                .ORG 0x8000

                ; RESULT MUST BE 0x0009
                CMP     0x0010, 0x0010
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0001
                CMP     0x0009, 0x0010
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0031
                CMP     0x0011, 0x0010
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0021
                CMP     0x0010, 0x9000
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0011
                CMP     0x9000, 0x0010
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0009
                CMP     0x9000, 0x9000
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0001
                CMP     0x8FFF, 0x9000
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0031
                CMP     0x9001, 0x9000
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)
