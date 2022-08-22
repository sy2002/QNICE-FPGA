;
;;=============================================================================
;; The collection of SD Card related functions starts here
;;=============================================================================
;
;
;*****************************************************************************
;* SD$RESET resets the SD Card
;*
;* R8: 0, if everything went OK, otherwise the error code
;*****************************************************************************
;
SD$RESET        INCRB
                MOVE    IO$SD_CSR, R0                
                MOVE    SD$CMD_RESET, @R0
                RSUB    SD$WAIT_BUSY, 1
                DECRB
                RET
;
;*****************************************************************************
;* SD$READ_BLOCK reads a 512 byte block from the SD Card
;*
;* INPUT:  R8/R9 = LO/HI words of the 32-bit block address
;* OUTPUT: R8 = 0 (no error), or error code
;*
;* The read data is stored inside the 512 byte buffer of the the SD controller 
;* that can then be accessed via SD$READ_BYTE/SD$WRITE_BYTE.
;*
;* IMPORTANT: 512-byte block addressing is used always, i.e. independent of
;* the SD Card type. Address #0 means 0..511, address #1 means 512..1023, ..
;*****************************************************************************
;
SD$READ_BLOCK   INCRB

                MOVE    R8, R1                  ; save R8 due to WAIT_BUSY

                RSUB    SD$WAIT_BUSY, 1         ; wait to be ready
                CMP     R8, 0                   ; error?
                RBRA    _SD$RB_END, !Z          ; yes: return

                MOVE    IO$SD_ADDR_LO, R0       ; lo word of 32-bit address
                MOVE    R1, @R0
                MOVE    IO$SD_ADDR_HI, R0       ; hi word of 32-bit address
                MOVE    R9, @R0
                MOVE    IO$SD_CSR, R0
                MOVE    SD$CMD_READ, @R0        ; issue block read command
                RSUB    SD$WAIT_BUSY, 1         ; wait until finished

_SD$RB_END      DECRB
                RET
;
;*****************************************************************************
;* SD$WRITE_BLOCK writes a 512 byte block to the SD Card
;*
;* INPUT:  R8/R9 = LO/HI words of the 32-bit block address
;* OUTPUT: R8 = 0 (no error), or error code
;*
;* The data to be written is stored inside the 512 byte buffer of the the
;* SD controller that can then be accessed via SSD$READ_BYTE/SD$WRITE_BYTE.
;*
;* IMPORTANT: 512-byte block addressing is used always, i.e. independent of
;* the SD Card type. Address #0 means 0..511, address #1 means 512..1023, ..
;*****************************************************************************
;
SD$WRITE_BLOCK  INCRB

                MOVE    R8, R1                  ; save R8 due to WAIT_BUSY

                RSUB    SD$WAIT_BUSY, 1         ; wait to be ready
                CMP     R8, 0                   ; error?
                RBRA    _SD$WB_END, !Z          ; yes: return

                MOVE    IO$SD_ADDR_LO, R0       ; lo word of 32-bit address
                MOVE    R1, @R0
                MOVE    IO$SD_ADDR_HI, R0       ; hi word of 32-bit address
                MOVE    R9, @R0
                MOVE    IO$SD_CSR, R0
                MOVE    SD$CMD_WRITE, @R0       ; issue block write command
                RSUB    SD$WAIT_BUSY, 1         ; wait until finished

_SD$WB_END      DECRB
                RET
;
;*****************************************************************************
;* SD$READ_BYTE reads a byte from the read buffer memory of the controller
;*
;* INPUT:  R8 = address between 0 .. 511
;* OUTPUT: R8 = byte
;*
;* No boundary checks are performed.
;*****************************************************************************
;
SD$READ_BYTE    INCRB

                MOVE    IO$SD_DATA_POS, R0
                MOVE    R8, @R0
                MOVE    IO$SD_DATA, R0
                MOVE    @R0, R8

                DECRB
                RET
;
;*****************************************************************************
;* SD$WRITE_BYTE writes a byte to the write memory buffer of the controller
;*
;* INPUT:  R8 = address between 0 .. 511
;*         R9 = byte to be written
;* OUTPUT: none
;*
;* No boundary checks are performed.
;*****************************************************************************
;
SD$WRITE_BYTE   INCRB

                MOVE    IO$SD_DATA_POS, R0
                MOVE    R8, @R0
                MOVE    IO$SD_DATA, R0
                MOVE    R9, @R0

                DECRB
                RET
;
;*****************************************************************************
;* SD$WAIT_BUSY waits, while the SD Card is executing any command
;*
;* R8: 0, if everything went OK, otherwise the error code
;*
;* Side effect: Starts the cycle counter (if it was stopped), but does not
;* reset the value, so that other countings are not influenced. 
;*****************************************************************************
;
SD$WAIT_BUSY    INCRB

                ; Make sure that the cycle counter is running for being
                ; able to measure the timeout. Do not reset it, but find
                ; the target value via addition (wrap around is OK), so that
                ; other running cycle counting processes are not disturbed
                ; by this
                MOVE    IO$CYC_STATE, R0        ; make sure, the cycle counter
                OR      CYC$RUN, @R0            ; is running
                MOVE    IO$CYC_MID, R3
                MOVE    @R3, R7
                ADD     SD$TIMEOUT_MID, R7

                ; check busy status of SD card and timeout
                MOVE    IO$SD_CSR, R0           ; SD Card Command & Status
                MOVE    IO$SD_ERROR, R2         ; SD Card Errors
_SD$WAIT_BUSY_L MOVE    @R3, R1                 ; check for timeout
                CMP     R1, R7                  ; timeout reached
                RBRA    _SD$WAIT_TO, Z          ; yes: return timeout
                MOVE    @R0, R1                 ; read CSR register       
                AND     SD$BIT_BUSY, R1         ; check busy flag
                RBRA    _SD$WAIT_BUSY_L, !Z     ; loop if busy flag is set
                XOR     R8, R8                  ; assume no error, but did an
                MOVE    @R0, R1                 ; read CSR register
                AND     SD$BIT_ERROR, R1        ; error flag?
                RBRA    _SD$WAIT_END, Z         ; no error
_SD$WAIT_ERR    MOVE    @R2, R8                 ; return error value
                RBRA    _SD$WAIT_END, 1

_SD$WAIT_TO     MOVE    SD$ERR_TIMEOUT, R8
_SD$WAIT_END    DECRB
                RET  
