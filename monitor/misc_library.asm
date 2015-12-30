;
;;=======================================================================================
;; Miscellaneous functions which did not fit in any other library file.
;;=======================================================================================
;

;
;***************************************************************************************
;* MISC$WAIT
;*
;* Waits for several milliseconds, controlled by R8. This is just a stupid wait loop
;* as we as of now do not have hardware timers and interrupts.
;*
;* R8: Contains delay value
;***************************************************************************************
;
MISC$WAIT       INCRB
_MISC$WAIT_1    MOVE    R8, R8
                RBRA    _MISC$WAIT_END, Z       ; Finished, when R8 == 0
                MOVE    0x0100, R0
_MISC$WAIT_2    SUB     0x0001, R0
                RBRA    _MISC$WAIT_2, !Z
                SUB     0x0001, R8
                RBRA    _MISC$WAIT_1, 1
_MISC$WAIT_END  DECRB
                RET

;
;***************************************************************************************
;* MISC$TIL
;*
;* Show a four nibble hex value on the TIL-display
;*
;* R8: Contains the value to be displayed
;***************************************************************************************
;
MISC$TIL        INCRB
                MOVE    IO$TIL_DISPLAY, R0
                MOVE    R8, @R0
                DECRB
                RET
