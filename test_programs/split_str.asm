; Split string function development testbed
; 
; The split function is a reusable function for the string library of
; the monitor. It splits a string into substrings using a delimiter character.
;
; Contains a reusable function, e.g. for the string library of the monitor.
; originally developed for the FAT32 implementation
;
; done by sy2002 in July 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; read string
                MOVE    STRBUFFER, R0                
                MOVE    STR_STRING, R8
                SYSCALL(puts, 1)                
INPUT_LOOP      SYSCALL(getc, 1)
                SYSCALL(putc, 1)
                CMP     R8, 0x000D              ; accept CR as line end
                RBRA    INPUT_END, Z
                CMP     R8, 0x000A              ; accept LF as line end
                RBRA    INPUT_END, Z
                MOVE    R8, @R0++               ; store character
                RBRA    INPUT_LOOP, 1
INPUT_END       MOVE    0, @R0                  ; add zero terminator
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
                ;MOVE    R7, R9
                MOVE    0, R9
                MOVE    STRBUFFER, R8
                RSUB    SPLIT, 1
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
                .ASCII_P "Split string development testbed - done by sy2002 in July 2016\n"
                .ASCII_W "==============================================================\n\n"

STR_STRING      .ASCII_W "Enter a string: "
STR_DELIMITER   .ASCII_W "Enter a delimiter: "
STR_SUBSTRINGS  .ASCII_W "Substrings found: "
STR_SUBSTR      .ASCII_W "Substring #"
STR_SUBSTRLEN   .ASCII_W " Length: "
STR_SUBSTRSTART .ASCII_W ": "
STR_STACK_BEGIN .ASCII_W "SP before: "
STR_STACK_AFTER .ASCII_W "SP after: "

;=============================================================================
; REUSABLE CODE STARTS HERE
;=============================================================================
;
;*****************************************************************************
;* SPLIT splits a string into substrings using a delimiter char
;*
;* Returns the substrings on the stack, i.e. after being done, you need to
;* add the amount of words returned in R9 to the stack pointer to clean
;* it up again and not leaving "memory leaks".
;*
;* The memory layout of the returned area is:
;* <size of string incl. zero terminator><string><zero terminator>
;*
;* The strings are returned in positive order, i.e. you just need to add
;* the length of the previous string to the returned string pointer
;* (i.e. stack pointer) to jump to the next substring from left to right.
;*
;* INPUT:  R8: pointer to zero terminated string
;*         R9: delimiter char
;* OUTPUT: SP: stack pointer pointer to the first string
;*         R8: amount of strings
;*         R9: amount of words to add to the stack pointer to restore it
;*****************************************************************************
;
SPLIT           INCRB

                MOVE    @SP++, R0               ; save return address and
                                                ; delete it by adding 1

                ; find the end of the string, R1 will point to it
                MOVE    1, R2
                MOVE    R8, R1
_SPLIT_FE       CMP     @R1, 0
                RBRA    _SPLIT_FE2, Z
                ADD     R2, R1
                RBRA    _SPLIT_FE, 1

_SPLIT_FE2      MOVE    R1, R2                  ; R2 = end of current substr
                XOR     R6, R6                  ; R6 = amount of strings
                XOR     R7, R7                  ; R7 = amount of words for R9

                ; skip empty string
                CMP     R8, R1
                RBRA    _SPLIT_ES_END, Z

                ; find the first occurrence of the delimiter
_SPLIT_FD       CMP     @--R1, R9               ; check for delimiter, mv left
                RBRA    _SPLIT_SS, Z            ; yes, delimiter found
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _SPLIT_SS, Z
                RBRA    _SPLIT_FD, 1                

                ; copy substring on the stack, if it is at least one
                ; non-delimiter character
_SPLIT_SS       MOVE    R2, R3
                SUB     R1, R3                  ; length of substring w/o zero
                CMP     R3, 1                   ; only one character?
                RBRA    _SPLIT_SSB, !Z          ; no: go on
                CMP     @R1, R9                 ; only one char and char=delim
                RBRA    _SPLIT_SS_SKP, Z        ; yes: skip
_SPLIT_SSB      ADD     1, R6                   ; one more string                
                SUB     R3, SP                  ; reserve memory on the stack
                SUB     2, SP                   ; size word & zero terminator
                ADD     R3, R7                  ; adjust amount of words ..
                ADD     2, R7                   ; .. equally to stack usage
                CMP     @R1, R9                 ; first char delimiter?
                RBRA    _SPLIT_SS_BGN, !Z       ; no: go on
                ADD     1, SP                   ; yes: adjust stack usage ..
                SUB     1, R7                   ; .. and word counter ..
                SUB     1, R3                   ; .. and reduce length ..
                ADD     1, R1                   ; .. and change start
_SPLIT_SS_BGN   MOVE    R1, R4                  ; R4 = cur. char of substring
                MOVE    SP, R5                  ; R5 = target memory of char
                MOVE    R3, @R5                 ; save size w/o zero term.
                ADD     1, @R5++                ; adjust for zero term.
_SPLIT_SS_CPY   MOVE    @R4++, @R5++            ; copy char
                SUB     1, R3                   ; R3 = amount to be copied
                RBRA    _SPLIT_SS_CPY, !Z
                MOVE    0, @R5                  ; add zero terminator

_SPLIT_SS_SKP   MOVE    R1, R2                  ; current index = new end
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _SPLIT_FD, !Z

_SPLIT_ES_END   MOVE    R6, R8                  ; return amount of strings
                MOVE    R7, R9                  ; return amount of bytes

                MOVE    R0, @--SP               ; put return address on stack

                DECRB
                RET

;=============================================================================
; REUSABLE CODE ENDS HERE
;=============================================================================

STRBUFFER       .BLOCK 1