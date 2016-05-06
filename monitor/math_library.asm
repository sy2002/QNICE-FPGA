;
;;=============================================================================
;; The collection of math related functions starts here
;;=============================================================================
;
;******************************************************************************
;*
;* MTH$MULS performs a signed 16 x 16 multiplication of the form 
;* R11(H)/R10(L) = R8 * R9. It is merely an interface to the EAE.
;*
;******************************************************************************
;
MTH$MULS        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$MULS, @R0
_MTH$MULS_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$MULS_BUSY, !Z  ; Still busy, wait...
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
;
;******************************************************************************
;*
;* MTH$MULU performs an unsigned 16 x 16 multiplication of the form 
;* R11(H)/R10(L) = R8 * R9. It is merely an interface to the EAE.
;*
;******************************************************************************
;
MTH$MULU        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$MULU, @R0
_MTH$MULU_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$MULU_BUSY, !Z  ; Still busy, wait...
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
