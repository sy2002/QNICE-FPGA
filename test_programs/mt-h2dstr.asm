; Test the h2dstr routine of the Monitor
;
; done by sy2002 in October 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; read high word to R9
                MOVE    STR_HEX_HIGH, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                MOVE    R8, R9
                SYSCALL(crlf, 1)

                ; read low word to R8
                MOVE    STR_HEX_LOW, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                SYSCALL(crlf, 1)

                ; convert HI|LO=R9|R8 to string in R10
                ; R11 points to string without trailing spaces
                MOVE    STR_RESULT, R10
                SYSCALL(h2dstr, 1)

                ; print result
                MOVE    STR_DEC, R8
                SYSCALL(puts, 1)
                MOVE    R11, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)

STR_TITLE       .ASCII_P "h2dstr - Monitor string library test\n"
                .ASCII_P "done by sy2002 in October 2016\n"
                .ASCII_W "32bit unsigned hex to decimal string\n\n"
STR_HEX_HIGH    .ASCII_W "Enter high word: "
STR_HEX_LOW     .ASCII_W "Enter low word:  "
STR_DEC         .ASCII_W "Decimal:         "

STR_RESULT      .BLOCK 11
