;
;;=======================================================================================
;; The collection of UART related functions starts here.
;;=======================================================================================
;
;
;***************************************************************************************
;* UART$PUTCHAR writes a single character to the serial line.
;*
;* R8: Contains the character to be printed
;
;* The contents of R8 are being preserved during the run of this function.
;***************************************************************************************
;
UART$PUTCHAR    INCRB                       ; Get a new register page
                MOVE IO$UART_SRA, R0        ; R0: address of status register                
                MOVE IO$UART_THRA, R1       ; R1: address of transmit register
_UART$PUTC_WAIT MOVE @R0, R2                ; read status register
                AND 0x0002, R2              ; ready to transmit?
                RBRA _UART$PUTC_WAIT, Z     ; loop until ready
                MOVE R8, @R1                ; Print character
                DECRB                       ; Restore the old page
                RET

;
;***************************************************************************************
;* UART$GETCHAR reads a character from the first UART in the system.
;*
;* R8 will contain the character read in its lower eight bits.
;***************************************************************************************
;
UART$GETCHAR    INCRB
                MOVE    IO$UART_SRA, R0     ; R0 contains the address of the status register
                MOVE    IO$UART_RHRA, R1    ; R1 contains the address of the receiver reg.
_UART$GETC_LOOP MOVE    @R0, R2             ; Read status register
                AND     0x0001, R2          ; Only bit 0 is of interest
                RBRA    _UART$GETC_LOOP, Z  ; Loop until a character has been received
                MOVE    @R1, R8             ; Get the character from the receiver register
                DECRB
                RET

