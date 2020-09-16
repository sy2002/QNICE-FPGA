;
;;=======================================================================================
;; Miscellaneous functions which did not fit in any other library file.
;;=======================================================================================
;

;
;***************************************************************************************
;* MISC$ENTER
;*
;* Meant to be used in conjunction with MISC$LEAVE as a frame for subroutines:
;* Increases the register bank, then saves the upper work registers R8..R12
;* and then increases the register bank again
;***************************************************************************************
;
MISC$ENTER      INCRB
                MOVE    R8,  R0
                MOVE    R9,  R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4
                INCRB
                RET
;
;***************************************************************************************
;* MISC$LEAVE
;*
;* Meant to be used in conjunction with MISC$ENTER as a frame for subroutines:
;* Decreases the register bank, then restores the upper work registers R8..R12
;* and then decreases the register bank again
;***************************************************************************************
;
MISC$LEAVE      DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12
                DECRB
                RET
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
;* MISC$EXIT
;*
;* Exit a program and return to the QNICE monitor
;***************************************************************************************
;
MISC$EXIT       ADD     0x0001, SP              ; Just out of paranoia
                RSUB    _VGA$INIT_PAL, 1        ; classic green/black look
                RSUB    _VGA$DEFAULT_FONT, 1    ; activate default font
                RBRA    QMON$WARMSTART, 1
