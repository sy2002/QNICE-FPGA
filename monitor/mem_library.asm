;
;;=============================================================================
;; The collection of memory related functions starts here
;;=============================================================================
;
;******************************************************************************
;* MEM$FILL fills a block of memory running from the address stored in R8.
;* R9 contains the number of words to be written. R10 contains the value to
;* be stored in the memory area.
;******************************************************************************
MEM$FILL        INCRB
                MOVE    R8, R0
                MOVE    R9, R1
_MEM$FILL_LOOP  MOVE    R1, R1              ; Zero length left?
                RBRA    _MEM$FILL_EXIT, Z   ; Yes, done...
                MOVE    R10, @R0++
                SUB     0x0001, R1
                RBRA    _MEM$FILL_LOOP, 1
_MEM$FILL_EXIT  DECRB
                RET
;
;******************************************************************************
;* MEM$MOVE moves the memory area starting at the address contained in R8 
;* to the area starting at the address contained in R9. R10 contains the
;* number of words to be moved.
;******************************************************************************
;
MEM$MOVE        INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
_MEM$MOVE_LOOP  MOVE    R2, R2              ; Zero length left?
                RBRA    _MEM$MOVE_EXIT, Z   ; Yes, done...
                MOVE    @R0++, @R1++
                SUB     0x0001, R2
                RBRA    _MEM$MOVE_LOOP, 1
_MEM$MOVE_EXIT  DECRB
                RET
