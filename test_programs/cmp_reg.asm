; Various CMP tests including register outputs with including
; borderline cases pos/neg
; done by vaxman and sy2002 in May 2016

#include "../dist_kit/monitor.def"
#include "../dist_kit/sysdef.asm"

                .ORG 0x8000

                ; RESULT MUST BE 0x0009
                MOVE    0x0010, R0
                MOVE    0x0010, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0001
                MOVE    0x0009, R0
                MOVE    0x0010, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0031
                MOVE    0x0011, R0
                MOVE    0x0010, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0021
                MOVE    0x0010, R0
                MOVE    0x9000, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0011
                MOVE    0x9000, R0
                MOVE    0x0010, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0009
                MOVE    0x9000, R0
                MOVE    0x9000, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0001
                MOVE    0x8FFF, R0
                MOVE    0x9000, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; RESULT MUST BE 0x0031
                MOVE    0x9001, R0
                MOVE    0x9000, R1
                CMP     R0, R1
                MOVE    SR, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)
