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
;* STR$STRCHR seaches for the first occurrence of the character stored in R8 in a 
;* string pointed to by R9.
;*
;* R8: Pointer to the string
;* R9: Character to be searched
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
_STR$STRCHR_LOOP    CMP     0x0000, @R0         ; while (*string)
                    RBRA    _STR$STRCHR_EXIT, Z
                    CMP     R8, @R0             ; if (*string == R8)
                    RBRA    _STR$STRCHR_NEXT, !Z
                    MOVE    R0, R10
                    RBRA    _STR$STRCHR_EXIT, 1
_STR$STRCHR_NEXT    ADD     0x0001, R0          ; string++
                    RBRA    _STR$STRCHR_LOOP, 1
_STR$STRCHR_EXIT    DECRB
                    RET
