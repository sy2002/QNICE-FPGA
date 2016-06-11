; SD Card and FAT32 development testbed
; contains reusable functions
; done by sy2002 in June 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; Reset SD Card
                MOVE    STR_RESET, R8
                SYSCALL(puts, 1)
                RSUB    SD$RESET, 1
                RSUB    ERR_CHECK, 1
                MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                SYSCALL(crlf, 1)
                
                ; SD registers
                MOVE    IO$SD_ADDR_LO, R0
                MOVE    IO$SD_ADDR_HI, R1
                MOVE    IO$SD_DATA_POS, R2
                MOVE    IO$SD_DATA, R3
                MOVE    IO$SD_ERROR, R4
                MOVE    IO$SD_CSR, R5

                ; perform register write/read-back checks
                MOVE    STR_REGCHK_T, R8
                SYSCALL(puts, 1)
                MOVE    0, R11                  ; deactivate do not write mode
                MOVE    R0, R8                  ; check ADDR_LO
                MOVE    0x2309, R9
                MOVE    STR_REGCHK_AL, R10
                RSUB    REG_CHECK, 1
                MOVE    R1, R8                  ; check ADDR_HI
                MOVE    0xABA0, R9
                MOVE    STR_REGCHK_AH, R10
                RSUB    REG_CHECK, 1
                MOVE    R2, R8                  ; check DATA_POS
                MOVE    0x4505, R9
                MOVE    STR_REGCHK_DP, R10
                RSUB    REG_CHECK, 1
                MOVE    R3, R8                  ; check DATA
                MOVE    0x0076, R9              ; (is an 8-bit register)
                MOVE    STR_REGCHK_DTA, R10
                RSUB    REG_CHECK, 1
                MOVE    1, R11                  ; activate do not write mode
                MOVE    R4, R8                  ; ERROR is read only
                MOVE    0x0000, R9              ; and must be zero
                MOVE    STR_REGCHK_ER, R10
                RSUB    REG_CHECK, 1
                MOVE    R5, R8                  ; CSR status bits
                MOVE    0x0000, R9              ; must be zero
                MOVE    STR_REGCHK_CS, R10
                RSUB    REG_CHECK, 1

                ; allow interactive dumps of arbitrary addresses
_IA_DUMP        MOVE    STR_IA_TITLE, R8
                SYSCALL(puts, 1)
                MOVE    STR_IA_HIGH, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                MOVE    R8, R1                  ; block addr hi word
                SYSCALL(crlf, 1)
                MOVE    STR_IA_LOW, R8
                SYSCALL(puts, 1)
                SYSCALL(gethex, 1)
                MOVE    R8, R0                  ; block read addr lo word
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)

                ; read 512 bytes from given address
                ; address must be a multiple of 512, otherwise the system
                ; will automatically "round it down" to the next 512 block
                MOVE    R0, R8
                MOVE    R1, R9
                RSUB    SD$READ_BLOCK, 1
                RSUB    ERR_CHECK, 1

                ; output the 512 bytes of the buffer
                MOVE    0, R6
_OUTPUT_LOOP    MOVE    R6, R8                  ; read byte at position R6...
                RSUB    SD$READ_BYTE, 1         ; ...from buffer
                SYSCALL(puthex, 1)              ; output hex value
                MOVE    STR_SPACE2, R8          ; output two separating spaces
                SYSCALL(puts, 1)
                ADD     1, R6                   ; next byte
                MOVE    R6, R8                  ; if bytecount mod 16 is zero,
                MOVE    16, R9                  ; i.e. if a line has 16 hex
                SYSCALL(divu, 1)                ; numbers, then output a
                CMP     0, R11                  ; CR/LF so that the output
                RBRA    _OUTPUT_LOOP_1, !Z      ; is nicely formatted
                SYSCALL(crlf, 1)
_OUTPUT_LOOP_1  CMP     512, R6
                RBRA    _OUTPUT_LOOP, !Z
                SYSCALL(crlf, 1)

                ; check if the user like to dump another buffer
                MOVE STR_IA_AGAIN, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
                SYSCALL(crlf, 1)
                CMP     'y', R8
                RBRA    _IA_DUMP, Z

                ; back to monitor
                SYSCALL(exit, 1)

; Register check subroutine: Expects the to be written and read-back
; register in R8, the value in R9 and the name string in R10
; R11: if 1 then no write is performed, only the read-back. This is needed
; for the CSR register as writing to it performs an action. It is also
; advisable for the ERROR register as you cannot write to it
REG_CHECK       INCRB
                MOVE    R8, R0

                ; print "checking <register name>"
                MOVE    STR_REGCHK_R, R8
                SYSCALL(puts, 1)
                MOVE    R10, R8
                SYSCALL(puts, 1)

                CMP     R11, 1
                RBRA    REG_CHECK_DW, Z

                ; write SD card register, read it back and test the value
                MOVE    R9, @R0                 ; write to the register
REG_CHECK_DW    MOVE    @R0, R1                 ; read it back
                CMP     R1, R9                  ; check if the read val is ok
                RBRA    REG_CHECK_OK, Z         ; jump if OK
                MOVE    STR_FAILED, R8          ; print FAILED, if not OK...
                SYSCALL(puts, 1)
                MOVE    R1, R8
                SYSCALL(puthex, 1)              ; ...and show the wrong value
                RBRA    REG_CHECK_CNT, 1
REG_CHECK_OK    MOVE    STR_OK, R8              ; print OK, if OK
                SYSCALL(puts, 1)
REG_CHECK_CNT   SYSCALL(crlf, 1)

                DECRB
                RET

; Error check subroutine: If R8 is nonzero, then the error code is printed
; and then the program is terminated
ERR_CHECK       INCRB

                CMP     R8, 0                   ; if no error: return
                RBRA    _ERR_CHECK_END, Z

                MOVE    R8, R9                  ; save error code
                MOVE    STR_ERR_END, R8         ; print error string
                SYSCALL(puts, 1)
                MOVE    R9, R8                  ; print error code
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                DECRB                           ; terminate execution
                SYSCALL(exit, 1)

_ERR_CHECK_END  DECRB
                RET

STR_TITLE       .ASCII_W "SD Card development testbed\n===========================\n\n"
STR_OK          .ASCII_W "OK"
STR_FAILED      .ASCII_W "FAILED: "
STR_SPACE2      .ASCII_W "  "
STR_RESET       .ASCII_W "Resetting SD Card: "
STR_REGCHK_T    .ASCII_W "Register write and read-back:\n"
STR_REGCHK_R    .ASCII_W "    checking "
STR_REGCHK_AL   .ASCII_W "ADDR_LO: "
STR_REGCHK_AH   .ASCII_W "ADDR_HI: "
STR_REGCHK_DP   .ASCII_W "DATA_POS: "
STR_REGCHK_DTA  .ASCII_W "DATA: "
STR_REGCHK_ER   .ASCII_W "ERROR: "
STR_REGCHK_CS   .ASCII_W "CSR: "
STR_IA_TITLE    .ASCII_W "Read 512 byte block from SD card and output it:\n"
STR_IA_HIGH     .ASCII_W "    Address HIGH word: "
STR_IA_LOW      .ASCII_W "    Address LOW word:  "
STR_IA_AGAIN    .ASCII_W "Enter 'y' for reading another block: "
STR_ERR_END     .ASCII_W "\nTERMINATED DUE TO FATAL ERROR: "

;=============================================================================
;=============================================================================
;
; REUSABLE CONSTANT DEFINITIONS AND FUNCTIONS START HERE
;
;=============================================================================
;=============================================================================

;
;*****************************************************************************
;* SD$RESET resets the SD Card.
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
;* SD$READ_BLOCK reads a 512 byte block from the SD Card. 
;*
;* Input: R8/R9 = LO/HI words of the 32-bit read address
;* Output: R8 = 0 (no error), or error code
;*
;* The read data is stored inside 512 byte buffer of the the SD controller 
;* memory that can then be accessed via SD$READ_BYTE.
;*
;* IMPORTANT: The 32-bit read address must be a multiple of 512, otherwise it
;* will be automatically "down rounded" to the nearest 512 byte block.
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
;* SD$READ_BYTE reads a byte from the read buffer memory of the controller.
;*
;* Input: R8 = address between 0 .. 511
;* Output: R8 = byte
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
;* SD$WAIT_BUSY waits, while the SD Card is executing any command.
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
                MOVE    @R2, R8                 ; return error value
                RBRA    _SD$WAIT_END, 1

_SD$WAIT_TO     MOVE    SD$ERR_TIMEOUT, R8
_SD$WAIT_END    DECRB
                RET  

