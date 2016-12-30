; Test the strcmp routine of the Monitor
;
; done by sy2002 in December 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    STR_INPUT1, R8
                SYSCALL(puts, 1)
                MOVE    STRING1, R8
                SYSCALL(gets, 1)
                SYSCALL(crlf, 1)

                MOVE    STR_INPUT2, R8
                SYSCALL(puts, 1)
                MOVE    STRING2, R8
                SYSCALL(gets, 1)
                SYSCALL(crlf, 1)

                MOVE    STRING1, R8
                MOVE    STRING2, R9
                SYSCALL(strcmp, 1)

                MOVE    STR_RESULT, R8
                SYSCALL(puts, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf,1)

                CMP     R10, 0
                RBRA    TEST_LT, !Z
                MOVE    STR_EQ, R8
                RBRA    END, 1

TEST_LT         CMP     R10, 0
                RBRA    IS_GT, V
                MOVE    STR_LT, R8
                RBRA    END, 1

IS_GT           MOVE    STR_GT, R8
                RBRA    END, 1

END             SYSCALL(puts, 1)
                SYSCALL(exit, 1)

STR_TITLE       .ASCII_P "strcmp - Monitor string library test\n"
                .ASCII_W "done by sy2002 in December 2016\n"
STR_INPUT1      .ASCII_W "Enter string #1: "
STR_INPUT2      .ASCII_W "Enter string #2: "
STR_RESULT      .ASCII_W "strcmp(string #1, string#2) = "
STR_CONCLUSION  .ASCII_W "Conclusion: "
STR_EQ          .ASCII_W "string #1 == string #2\n"
STR_LT          .ASCII_W "string #1 < string #2\n"
STR_GT          .ASCII_W "string #1 > string #2\n"

STRING1         .BLOCK 200
STRING2         .BLOCK 200
