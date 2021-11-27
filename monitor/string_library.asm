;
;;=======================================================================================
;; The collection of string related functions starts here
;;=======================================================================================
;
;***************************************************************************************
;* CHR$TO_UPPER expects a character to be converted to upper case in R8
;***************************************************************************************
;
CHR$TO_UPPER            INCRB
                        MOVE    R8, R0                  ; Save character
                        SUB     'a', R0                 ; Less than 'a'?
                        RBRA    _CHR$TO_UPPER_EXIT, N   ; Yes - nothing to do
                        MOVE    'z', R0                 ; Check if greater than 'z'
                        SUB     R8, R0
                        RBRA    _CHR$TO_UPPER_EXIT, N   ; Yes - nothing to do
                        SUB     'a', R8                 ; Perform the conversion
                        ADD     'A', R8
_CHR$TO_UPPER_EXIT      DECRB
                        RET
;
;***************************************************************************************
;* CHR$TO_LOWER expects a character to be converted to lower case in R8
;***************************************************************************************
;
CHR$TO_LOWER            INCRB
                        CMP     R8, '@'                 ; Is it "@" or less than that?
                        RBRA    _CHR$TO_LOWER_EXIT, !N  ; Yes: nothing to do
                        CMP     R8, 'Z'                 ; Is it greater than 'Z'
                        RBRA    _CHR$TO_LOWER_EXIT, N   ; Yes: nothing to do
                        ADD     0x0020, R8              ; Perform the conversion
_CHR$TO_LOWER_EXIT      DECRB
                        RET
;
;***************************************************************************************
;* STR$TO_UPPER expects the address of a string to be converted to upper case in R8
;***************************************************************************************
;
STR$TO_UPPER            INCRB                       ; Get a new scratch register page
                        MOVE R8, R0                 ; Do not destroy parameters
_STR$TO_UPPER_LOOP      MOVE @R0, R1                ; Null terminator found?
                        RBRA _STR$TO_UPPER_END, Z   ; Yes - that is it
                        MOVE R1, R2
                        SUB 'a', R2                 ; Less than 'a'?
                        RBRA _STR$TO_UPPER_NEXT, N  ; Yes
                        MOVE 'z', R2                ; Greater than 'z'?
                        SUB R1, R2
                        RBRA _STR$TO_UPPER_NEXT, N  ; Yes
                        SUB 'a', R1                 ; Now convert the LC char to UC
                        ADD 'A', R1
                        MOVE R1, @R0                ; Store it back into the string
_STR$TO_UPPER_NEXT      ADD 0x001, R0
                        RBRA _STR$TO_UPPER_LOOP, 1  ; Process next character
_STR$TO_UPPER_END       DECRB                       ; Restore old register page
                        RET
;
;***************************************************************************************
;* STR$LEN expects the address of a string in R8 and returns its length in R9
;***************************************************************************************
;
STR$LEN          INCRB                     ; Get a new scratch register page
                 MOVE R8, R0               ; Do not work with the original pointer
                 MOVE 0xFFFF, R9           ; R9 = -1
_STR$LEN_LOOP    ADD 0x0001, R9            ; One character found
                 MOVE @R0++, R1            ; Was it the terminating null word?
                 RBRA _STR$LEN_LOOP, !Z    ; No?
                 DECRB
                 RET
;
;***************************************************************************************
;* STR$CHOMP removes a trailing LF/CR from a string pointed to by R8
;***************************************************************************************
;
STR$CHOMP        INCRB                    ; Get a new register page
                 MOVE R8, R0              ; Save the start address of the string
                 MOVE R9, R1              ; R9 will be used later
                 MOVE R8, R2              ; R2 will be used as a working pointer
                 RSUB STR$LEN, 1          ; Determine the length of the string
                 MOVE R9, R9              ; Is the string empty?
                 RBRA _STR$CHOMP_EXIT, Z  ; Yes
                 ADD R9, R2               ; R2 now points to the last string character
                 MOVE @--R2, R3           ; Get a character
                 SUB 0x000D, R3           ; Is it a CR (we are working from right!)
                 RBRA _STR$CHOMP_1, !Z    ; No, so nothing to do so far
                 MOVE 0x0000, @R2         ; Yes, replace it with a null word
                 SUB 0x0001, R2           ; Proceed to second last character
_STR$CHOMP_1     MOVE @R2, R3             ; Now test for a line feed
                 SUB 0x000A, R3
                 RBRA _STR$CHOMP_EXIT, !Z ; Nothing to do
                 MOVE 0x0000, @R2         ; Replace the LF with a null word
_STR$CHOMP_EXIT  MOVE R1, R9              ; Restore R9
                 DECRB                    ; Restore register bank
                 RET
;
;***************************************************************************************
;* STR$CMP compares two strings
;*
;* R8: Pointer to the first string (S0),
;* R9: Pointer to the second string (S1),
;*
;* R10: negative if (S0 < S1), zero if (S0 == S1), positive if (S0 > S1)
;
;* The contents of R8 and R9 are being preserved during the run of this function
;***************************************************************************************
;
STR$CMP         INCRB                       ; Get a new register page
                MOVE R8, R0                 ; Save arguments
                MOVE R9, R1
_STR$CMP_LOOP   MOVE @R0, R10               ; while (*s1 == *s2++)
                MOVE @R1++, R2
                SUB R10, R2
                RBRA _STR$CMP_END, !Z
                MOVE @R0++, R10             ; if (*s1++ == 0)
                RBRA _STR$CMP_EXIT, Z       ;   return 0;
                RBRA _STR$CMP_LOOP, 1       ; end-of-while-loop
_STR$CMP_END    MOVE @--R1, R2              ; return (*s1 - (--*s2));
                SUB R2, R10
_STR$CMP_EXIT   DECRB                       ; Restore previous register page
                RET
;
;***************************************************************************************
;* STR$CPY copies a zero-terminated string to a destination
;*
;* R8: Pointer to the string to be copied
;* R9: Pointer to the destination
;***************************************************************************************
;
STR$CPY             INCRB
                    MOVE    R8, R0
                    MOVE    R9, R1
_STR$CPY_LOOP       MOVE    @R0++, @R1++
                    RBRA    _STR$CPY_LOOP, !Z
                    DECRB
                    RET
;
;***************************************************************************************
;* STR$STRSTR finds the first occurence of the substring in the string
;*
;* R8: Pointer to the string to be searched
;* R9: Pointer to the substring to be found
;* R10: Zero, if substring is not found else pointer to first occurence
;***************************************************************************************
;
STR$STRSTR          INCRB
                    MOVE    R8, R0                  ; current search ptr inside string
                    MOVE    R0, R1                  ; potential start point of substring
_STR$STRSTR_NEXT    MOVE    R9, R2                  ; current search ptr inside substring
_STR$STRSTR_ITER    CMP     @R0++, @R2++            ; are the two actual chars idendical?                    
                    RBRA    _STR$STRSTR_ID, Z       ; yes
                    ADD     1, R1                   ; no: start +1 in source string and ..
                    MOVE    R1, R0                  ; .. try again, unless we reached ..
                    CMP     @R0, 0                  ; .. the end of the source string
                    RBRA    _STR$STRSTR_NEXT, !Z
                    MOVE    0, R10
                    RBRA    _STR$STRSTR_RET, 1

_STR$STRSTR_ID      CMP     @R2, 0                  ; did we reach the end of the substring?
                    RBRA    _STR$STRSTR_FOUND, Z    ; yes: substring was found
                    RBRA    _STR$STRSTR_ITER, 1

_STR$STRSTR_FOUND   MOVE    R1, R10
_STR$STRSTR_RET     DECRB
                    RET
;
;***************************************************************************************
;* STR$STRCHR seaches for the first occurrence of the character stored in R8 in a 
;* string pointed to by R9.
;*
;* R8: Character to be searched
;* R9: Pointer to the string
;*
;* R10: Zero if the character has not been found, otherwise it contains a pointer
;*      to the first occurrence of the character in the string
;
;* The contents of R8 and R9 are being preserved during the run of this function
;***************************************************************************************
;
STR$STRCHR          INCRB
                    MOVE    R9, R0
                    XOR     R10, R10
_STR$STRCHR_LOOP    CMP     R10, @R0            ; while (*string)
                    RBRA    _STR$STRCHR_EXIT, Z
                    CMP     R8, @R0++           ; if (*string == R8)
                    RBRA    _STR$STRCHR_LOOP, !Z
                    MOVE    R0, R10
                    SUB     0x0001, R10
_STR$STRCHR_EXIT    DECRB
                    RET
;
;***************************************************************************************
;* STR$SPLIT splits a string into substrings using a delimiter char
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
;***************************************************************************************
;
STR$SPLIT       INCRB

                MOVE    @SP++, R0               ; save return address and
                                                ; delete it by adding 1

                ; find the end of the string, R1 will point to it
                MOVE    1, R2
                MOVE    R8, R1
_STR$SPLIT_FE   CMP     @R1, 0
                RBRA    _STR$SPLIT_FE2, Z
                ADD     R2, R1
                RBRA    _STR$SPLIT_FE, 1

_STR$SPLIT_FE2  MOVE    R1, R2                  ; R2 = end of current substr
                XOR     R6, R6                  ; R6 = amount of strings
                XOR     R7, R7                  ; R7 = amount of words for R9

                ; skip empty string
                CMP     R8, R1
                RBRA    _STR$SPLIT_END, Z

                ; find the first occurrence of the delimiter
_STR$SPLIT_FD   CMP     @--R1, R9               ; check for delimiter, mv left
                RBRA    _STR$SPLIT_SS, Z        ; yes, delimiter found
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _STR$SPLIT_SS, Z
                RBRA    _STR$SPLIT_FD, 1                

                ; copy substring on the stack, if it is at least one
                ; non-delimiter character
_STR$SPLIT_SS   MOVE    R2, R3
                SUB     R1, R3                  ; length of substring w/o zero
                CMP     R3, 1                   ; only one character?
                RBRA    _STR$SPLIT_SSB, !Z      ; no: go on
                CMP     @R1, R9                 ; only one char and char=delim
                RBRA    _STR$SPLIT_SSSK, Z      ; yes: skip
_STR$SPLIT_SSB  ADD     1, R6                   ; one more string                
                SUB     R3, SP                  ; reserve memory on the stack
                SUB     2, SP                   ; size word & zero terminator
                ADD     R3, R7                  ; adjust amount of words ..
                ADD     2, R7                   ; .. equally to stack usage
                CMP     @R1, R9                 ; first char delimiter?
                RBRA    _STR$SPLIT_SSBG, !Z     ; no: go on
                ADD     1, SP                   ; yes: adjust stack usage ..
                SUB     1, R7                   ; .. and word counter ..
                SUB     1, R3                   ; .. and reduce length ..
                ADD     1, R1                   ; .. and change start
_STR$SPLIT_SSBG MOVE    R1, R4                  ; R4 = cur. char of substring
                MOVE    SP, R5                  ; R5 = target memory of char
                MOVE    R3, @R5                 ; save size w/o zero term.
                ADD     1, @R5++                ; adjust for zero term.
_STR$SPLIT_SSCP MOVE    @R4++, @R5++            ; copy char
                SUB     1, R3                   ; R3 = amount to be copied
                RBRA    _STR$SPLIT_SSCP, !Z
                MOVE    0, @R5                  ; add zero terminator

_STR$SPLIT_SSSK MOVE    R1, R2                  ; current index = new end
                CMP     R1, R8                  ; beginning of string reached?
                RBRA    _STR$SPLIT_FD, !Z

_STR$SPLIT_END  MOVE    R6, R8                  ; return amount of strings
                MOVE    R7, R9                  ; return amount of bytes

                MOVE    R0, @--SP               ; put return address on stack

                DECRB
                RET                
;
;***************************************************************************************
;* STR$H2D converts a 32bit value to a decimal representation in ASCII;
;* leading zeros are replaced by spaces (ASCII 0x20); zero terminator is added
;*
;* INPUT:  R8/R9   = LO/HI of the 32bit value
;*         R10     = pointer to a free memory area that is 11 words long
;* OUTPUT: R10     = the function fills the given memory space with the
;*                   decimal representation and adds a zero terminator
;*                   this includes leading white spaces
;*         R11     = pointer to string without leading white spaces
;*         R12     = amount of digits/characters that the actual number has,
;*                   without the leading spaces
;***************************************************************************************
;
STR$H2D         INCRB

                MOVE    R8, R0                  ; save original values
                MOVE    R9, R1
                MOVE    R10, R2

                MOVE    R10, R3                 ; R3: working pointer
                XOR     R4, R4                  ; R4: digit counter

                ; add zero terminator
                ADD     10, R3
                MOVE    0, @R3

                ; extract decimals by repeatedly dividing the 32bit value
                ; by 10; the modulus is the decimal that is converted to
                ; ASCII by adding the ASCII code of zero which is 0x0030
                XOR     R11, R11                ; high word = 0
_STR$H2D_ML     MOVE    10, R10                 ; divide by 10
                RSUB    MTH$DIVU32, 1           ; perform division
                ADD     0x0030, R10             ; R10 = digit => ASCII conv.
                MOVE    R10, @--R3              ; store digit
                ADD     1, R4                   ; increase digit counter
                CMP     R8, 0                   ; quotient = 0? (are we done?)
                RBRA    _STR$H2D_TS, Z          ; yes: add trailing spaces                
                RBRA    _STR$H2D_ML, 1          ; next digit, R8/R9 has result

_STR$H2D_TS     CMP     R3, R2                  ; working pntr = memory start
                RBRA    _STR$H2D_DONE, Z        ; yes: then done
                MOVE    0x0020, @--R3           ; no: add trailing space
                RBRA    _STR$H2D_TS, 1          ; next digit

_STR$H2D_DONE   MOVE    R0, R8                  ; restore original values
                MOVE    R1, R9
                MOVE    R2, R10

                MOVE    R10, R11                ; return pointer to string ..
                MOVE    10, R7                  ; .. without white spaces
                SUB     R4, R7
                ADD     R7, R11

                MOVE    R4, R12                 ; return digit counter             
                DECRB
                RET
