;
;;=======================================================================================
;; qtransfer client side (tools/qtransfer.c needs to run on the host)
;;=======================================================================================
;
;
;***************************************************************************************
;* QTRANSFER$START starts the qtransfer client to receive data from the host.
;*
;* Important: The client is not meant to be used as a subroutine. The reason
;* is, that in the standard use case, the client is using ABRA to start the
;* application that has beed loaded. So the Monitor needs to RBRA or ABRA into
;* the client and the client will use SYSCALL(exit, 1) to end.
;***************************************************************************************
;
QTRANSFER$START MOVE    QSTR_TITLE, R8
                SYSCALL(puts, 1)

                ; R12 = receive buffer: create space on the stack
                ; (we cannot use R11, because mulu changes R11)
                SUB     QVAR_BUF_WORDS, SP
                MOVE    SP, R12                  

                ; R4 = burst buffer: create space on the stack
                SUB     QBURST_WORDS, SP
                MOVE    SP, R4

                ; wait until START is received
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    QREAD_UART, 1
                MOVE    QSTR_START, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _QSENDACK, Z
                MOVE    QSTR_ERR_START, R8
                SYSCALL(puts, 1)
                RBRA    _QTRANSFER_END, 1

                ; send ACK
_QSENDACK       MOVE    QSTR_OK, R8
                SYSCALL(puts, 1)
                MOVE    QSTR_ACK, R8
                RSUB    QWRITE_UART, 1
                MOVE    QSTR_PROGRESS, R8
                SYSCALL(puts, 1)

                ; (<burst> x (<address><data>\n))<crc>\n
                ; all values are 16bit hex values where each one is
                ; transmitted as a 4 character ASCII string
_QRX_LOOP       MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    QREAD_UART, 1

                ; "END" ends the transmission
                MOVE    QSTR_END, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _QRX_DONE, Z

                ; receive burst length and store it in R0
                RSUB    QHEXSTR2I, 1
                MOVE    R9, R0                  ; R0 = burst length
                MOVE    R0, R2                  ; R2 = backup burst length
                MOVE    R4, R1                  ; R1 = start of burst buf.

                ; receive one burst
_QRX_BURST      MOVE    R1, R8                  ; QREAD_UART reads to this..
                RSUB    QREAD_UART, 1           ; ..gliding address
                SUB     1, R0                   ; one less element in burst
                RBRA    _QRX_CRC, Z             ; current burst done!
                ADD     8, R1                   ; make room for next element
                RBRA    _QRX_BURST, 1           ; next element of burst

                ; receive CRC of current burst and check it
_QRX_CRC        SUB     QCRC_BUF_WORDS, SP      ; reserve stack memory for CRC
                MOVE    SP, R8                  ; R8 = buffer for QREAD_UART
                RSUB    QREAD_UART, 1           ; receive CRC from host
                RSUB    QHEXSTR2I, 1            ; convert to number
                MOVE    R9, R3                  ; R3 = received CRC
                ADD     QCRC_BUF_WORDS, SP      ; free stack memory

                MOVE    R2, R8                  ; CRC is calculated over a..
                MOVE    8, R9                   ; ..buffer of size R2*8
                SYSCALL(mulu, 1)                
                MOVE    R10, R9                 ; R9 = burst size * 8
                MOVE    R4, R8                  ; R8 = start of burst buffer
                RSUB    QCALC_CRC16, 1

                CMP     R10, R3                 ; received CRC == calc. CRC?
                RBRA    _QCRC_OK, Z             ; yes

                ; CRC ERROR: Send error to UART, output error string, then end
                MOVE    QSTR_CRCERR, R8
                RSUB    QWRITE_UART, 1
                MOVE    QSTR_ERR_CRC, R8
                SYSCALL(puts, 1)
                RBRA    _QTRANSFER_END, 1

                ; "ACK" to sender
_QCRC_OK        MOVE    QSTR_ACK, R8
                RSUB    QWRITE_UART, 1

                ; write to memory
                MOVE    R2, R0                  ; R0 = burst length
                MOVE    R4, R1                  ; R1 = start of burst buffer

_QWRITE_LOOP    MOVE    R1, R8                  ; convert hex string address
                RSUB    QHEXSTR2I, 1
                MOVE    R9, R5                  ; R5 = target address

                ADD     4, R1                   ; next hex string address
                MOVE    R1, R8                  ; convert hex string data
                RSUB    QHEXSTR2I, 1
                ADD     4, R1                   ; next hex string address

                MOVE    R9, @R5                 ; R9 = data to be written
                SUB     1, R0                   ; burst over?
                RBRA    _QWRITE_LOOP, !Z        ; no: continue to fill memory
                RBRA    _QRX_LOOP, 1            ; yes: next RX iteration


_QRX_DONE       MOVE    QSTR_DONE, R8
                SYSCALL(puts, 1)

                ; show start address of transmitted program/data
                MOVE    QSTR_START_ADDR, R8
                SYSCALL(puts, 1)
                MOVE    QSTR_16SPACES, R8
                SYSCALL(puts, 1)
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    QREAD_UART, 1
                RSUB    QHEXSTR2I, 1
                MOVE    R9, R8
                MOVE    R8, R6                  ; R6 = start addr. for running
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; show overall size of transmitted program/data
                MOVE    QSTR_LENGTH, R8
                SYSCALL(puts, 1)
                MOVE    QSTR_16SPACES, R8
                SYSCALL(puts, 1)
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    QREAD_UART, 1
                RSUB    QHEXSTR2I, 1
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; offer to start/run the program
                MOVE    QSTR_RUN, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
                SYSCALL(chr2upper, 1)
                CMP     'R', R8
                RBRA    _QTRANSFER_END, !Z

                ; run the program
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)
                ADD     QBURST_WORDS, SP        ; free memory on the stack
                ADD     QVAR_BUF_WORDS, SP
                RSUB    _VGA$FACTORY_PAL, 1     ; factory default vga palette                
                ABRA    R6, 1                   ; run the program

_QTRANSFER_END  ADD     QBURST_WORDS, SP        ; free memory on the stack
                ADD     QVAR_BUF_WORDS, SP
                SYSCALL(exit, 1)

;=============================================================================
; CRC16 Calculation and hex conversion
;=============================================================================

; Function QCALC_CRC16
; Input:   R8 = buffer
;          R9 = buffer size
; Output: R10 = 16-bit CRC

; uint16_t calc_crc(char* buffer, unsigned int size)
; {
;     const uint16_t mask = 0xA001;
;     uint16_t crc = 0xFFFF;
;     int i = 0;
;     while (i < size)
;     {
;         crc ^= *buffer;
;         crc = (crc & 1) ? (crc >> 1) ^ mask : crc >> 1;
;         buffer++;        
;         i++;
;     }
;     return crc;
; }

QCALC_CRC16     INCRB

                MOVE    0xFFFF, R0              ; R0 = CRC
                MOVE    0xA001, R1              ; R1 = mask
                MOVE    R8, R2                  ; R2 = buffer pointer
                XOR     R3, R3                  ; R3 = i

_QCCRC16_LOOP   XOR     @R2++, R0               ; crc ^= *buffer

                AND     0xFFFB, SR              ; prepare SHR: clear carry
                SHR     1, R0                   ; crc >> 1
                RBRA    _QCCRC16_NOXOR, !X      ; crc & 1 == 0? no mask!
                XOR     R1, R0                  ; crc ^= mask

_QCCRC16_NOXOR  ADD     1, R3
                CMP     R3, R9
                RBRA    _QCCRC16_LOOP, !Z

                MOVE    R0, R10
                DECRB
                RET

; Function QHEXSTR2I: Interprets 4 ASCII characters as a hexadecimal value
;                    and converts it into a number
; Input:  R8 =  pointer to 4 ASCII characters
; Output: R9 =  integer
QHEXSTR2I       INCRB

                MOVE    R8, R0                  ; save R8
                MOVE    R10, R5                 ; save R10
                MOVE    R0, R1                  ; R1 iterates the input
                MOVE    4, R2                   ; loop counter
                XOR     R3, R3                  ; result

_QH2SI_NXT_NIB  MOVE    @R1++, R8               ; next character
                MOVE    IO$HEX_NIBBLES, R9      ; .ASCII_W "0123456789ABCDEF"
                SYSCALL(strchr, 1)
                CMP     0, R10                  ; illegal character?
                RBRA    _QHS2I_ILLEGAL, Z

                SUB     R9, R10                 ; R10 = hex nibble: 0..15
                AND     0xFFFD, SR              ; clear X (shift in '0')                
                SHL     4, R3                   ; old value one nibble left
                ADD     R10, R3                 ; add next value
                SUB     1, R2                   ; one less iteration
                RBRA    _QH2SI_NXT_NIB, !Z      ; iterate!
                MOVE    R3, R9                  ; return value is in R9
                RBRA    _QHS2I_END, 1

_QHS2I_ILLEGAL  XOR     R9, R9
                RBRA    _QHS2I_END, 1

_QHS2I_END      MOVE    R0, R8
                MOVE    R5, R10
                DECRB
                RET


;=============================================================================
; UART Functions
;=============================================================================

; Function QREAD_UART: Reads into zero terminated buffer at R8
; Output: R9 =  amount of data words read
QREAD_UART      INCRB
                MOVE    R8, R3                  ; save R8
                XOR     R1, R1                  ; 0 is default return value

                ; read until \n
                MOVE    R8, R0
_QRUA_NEXT_CHAR RSUB    UART$GETCHAR, 1
                CMP     0x000A, R8                
                RBRA    _QRUA_READ_END, Z
                MOVE    R8, @R0++
                ADD     1, R1
                RBRA    _QRUA_NEXT_CHAR, 1
_QRUA_READ_END  MOVE    0, @R0                  ; add string zero terminator

_QEND_RUA       MOVE    R3, R8                  ; restore R8
                MOVE    R1, R9                  ; return number of words read
                DECRB
                RET

; Function QWRITE_UART: send zero terminated buffer including the zero
; Input:
; R8 = Zero terminated buffer
QWRITE_UART     INCRB
                MOVE    R8, R1
                MOVE    R1, R0

_QWUA_NEXT_CHR  MOVE    @R0++, R8
                RSUB    UART$PUTCHAR, 1
                CMP     0, @R0
                RBRA    _QWUA_NEXT_CHR, !Z
                XOR     R8, R8
                RSUB    UART$PUTCHAR, 1

                MOVE    R1, R8
                DECRB
                RET


;=============================================================================
; Constants and variables
;=============================================================================

QBURST_WORDS    .EQU 241                        ; 8 * BURST_SIZE + 1
QVAR_BUF_WORDS  .EQU 9
QCRC_BUF_WORDS  .EQU 5

QSTR_TITLE      .ASCII_W "QTransfer:\n  Waiting for serial connection   "
QSTR_OK         .ASCII_W "OK!\n"
QSTR_PROGRESS   .ASCII_W "  Data transfer in progress...    "
QSTR_DONE       .ASCII_W "Done!\n"
QSTR_START_ADDR .ASCII_W "  Start address:  "
QSTR_LENGTH     .ASCII_W "  Length in words:"
QSTR_16SPACES   .ASCII_W "                "
QSTR_RUN        .ASCII_W "Press R to run and any other key to exit"

QSTR_ERR_START  .ASCII_P "\nError: Wrong protocol. (Are you running "
                .ASCII_W "qtransfer.c on your host?)\n"
QSTR_ERR_CRC    .ASCII_W "CRC Error!\n"

QSTR_START      .ASCII_W "START"
QSTR_END        .ASCII_W "END"
QSTR_ACK        .ASCII_W "ACK"
QSTR_CRCERR     .ASCII_W "CRCERR"
