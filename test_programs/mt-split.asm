; Test the split routine of the Monitor
; derived from the original code from split_str.asm
;
; done by sy2002 in Octiber 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; read string
                MOVE    STR_STRING, R8
                SYSCALL(puts, 1)
                MOVE    STRBUFFER, R8
                SYSCALL(gets, 1)
                SYSCALL(crlf, 1)

                ; read delimiter
                MOVE    STR_DELIMITER, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
                SYSCALL(putc, 1)
                SYSCALL(crlf, 1)
                MOVE    R8, R7

                ; stack pointer before
                MOVE    STR_STACK_BEGIN, R8
                SYSCALL(puts, 1)
                MOVE    SP, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; split string and output amount of substrings
                MOVE    R7, R9
                MOVE    STRBUFFER, R8
                SYSCALL(split, 1)
                MOVE    R8, R7                  ; R7 = amount of substrings
                MOVE    STR_SUBSTRINGS, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8                
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; save SP
                MOVE    SP, R1                  ; R1 = SP after split call

                ; no substrings at all (pure delimiter string)
                CMP     R7, 0
                RBRA    RESTORE_STACK, Z

                ; output substrings
                MOVE    1, R0                   ; R0 = string counter
NEXT_SUBSTR     MOVE    STR_SUBSTR, R8
                SYSCALL(puts, 1)
                MOVE    R0, R8
                SYSCALL(puthex, 1)
                MOVE    STR_SUBSTRLEN, R8
                SYSCALL(puts, 1)
                MOVE    @SP++, R8
                MOVE    R8, R6                  ; R6 = substring length
                SYSCALL(puthex, 1)
                MOVE    STR_SUBSTRSTART, R8
                SYSCALL(puts, 1)
                MOVE    SP, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                ADD     R6, SP                  ; next string in memory frame
                ADD     1, R0                   ; increase string counter
                SUB     1, R7                   ; decrease substring amount
                RBRA    NEXT_SUBSTR, !Z

                ; restore stack pointer
RESTORE_STACK   MOVE    R1, SP
                ADD     R9, SP

                ; stack pointer after
                MOVE    STR_STACK_AFTER, R8
                SYSCALL(puts, 1)                
                MOVE    SP, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                SYSCALL(exit, 1)


STR_TITLE       .ASCII_P "\n"
                .ASCII_P "split - Monitor string library test - done by sy2002 in October 2016\n"
                .ASCII_W "====================================================================\n\n"

STR_STRING      .ASCII_W "Enter a string: "
STR_DELIMITER   .ASCII_W "Enter a delimiter: "
STR_SUBSTRINGS  .ASCII_W "Substrings found: "
STR_SUBSTR      .ASCII_W "Substring #"
STR_SUBSTRLEN   .ASCII_W " Length: "
STR_SUBSTRSTART .ASCII_W ": "
STR_STACK_BEGIN .ASCII_W "SP before: "
STR_STACK_AFTER .ASCII_W "SP after: "

STRBUFFER       .BLOCK 1
