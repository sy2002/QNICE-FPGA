;
;;=======================================================================================
;; The collection of USB-keyboard related functions starts here.
;;=======================================================================================
;
;
;***************************************************************************************
;* KBD$GETCHAR reads a character from the USB-keyboard.
;*
;* R8 will contain the character read in its lower eight bits and
;* special keys in the upper 8 bits (mutually exclusive)
;***************************************************************************************
;
KBD$GETCHAR     INCRB
                MOVE    IO$KBD_STATE, R0    ; R0 contains the address of the status register
                MOVE    IO$KBD_DATA, R1     ; R1 contains the address of the receiver reg.
_KBD$GETC_LOOP  MOVE    @R0, R2             ; Read status register
                AND     KBD$NEW_ANY, R2     ; Bit 1: new special key, Bit 0: new ASCII
                RBRA    _KBD$GETC_LOOP, Z   ; Loop until a character has been received
                MOVE    @R1, R8             ; Get the character from the receiver register
                DECRB
                RET
