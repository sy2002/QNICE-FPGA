; QNICE CRC16 safeguarded data transfer tool
; Use case: If you don't have a RTS/CTS protected serial line, then this tool
; ensures the data integrety via CRC16
; done by sy2002 in May 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0xE000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; wait until START is received
                RSUB    READ_UART, 1
                MOVE    VAR_BUFFER, R8
                MOVE    STR_START, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _SENDACK, Z
                MOVE    STR_ERR_NOSTART, R8
                SYSCALL(puts, 1)
                RBRA    _END, 1

                ; send ACK
_SENDACK        MOVE    STR_OK, R8
                SYSCALL(puts, 1)
                MOVE    STR_ACK, R8
                RSUB    WRITE_UART, 1
                MOVE    STR_PROGRESS, R8
                SYSCALL(puts, 1)

                ; each data frame consists of 13 characters; all numbers are
                ; transmitted as 4 character hex numbers in ASCII:
                ; <address><data><crc>\n
_RX_LOOP        RSUB    READ_UART, 1

                ; "END" ends the transmission
                MOVE    VAR_BUFFER, R8
                MOVE    STR_END, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _RX_DONE, Z

                ; calculate CRC for the first 8 chars
                MOVE    8, R9
                RSUB    CALC_CRC16, 1

                ; compare calculated CRC in R10 with transmitted CRC in R9
                ADD     8, R8
                RSUB    HEXSTR2I, 1
                CMP     R9, R10
                RBRA    _CRC_OK, Z

                ; TODO: What happens if CRC is not OK
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                MOVE    R10, R8
                SYSCALL(puthex, 1)                

                MOVE    STR_CRCERR, R8
                RSUB    WRITE_UART, 1
                MOVE    STR_ERR_CRC, R8
                SYSCALL(puts, 1)
                RBRA    _END, 1

                ; "ACK" to sender
_CRC_OK         MOVE    STR_ACK, R8
                RSUB    WRITE_UART, 1

                ; store data in memory
                MOVE    VAR_BUFFER, R8
                RSUB    HEXSTR2I, 1
                MOVE    R9, R0                  ; R0 = address where to write
                ADD     4, R8
                RSUB    HEXSTR2I, 1             ; R9 = data to be written
                MOVE    R9, @R0                 ; store data in memory

                RBRA    _RX_LOOP, 1

                ; todo: test .out file on SD card: does it work?
                ; todo: clear input buffer after each loop to ensure,
                ; that corrupt input leads to CRC errors
                ; todo: handle CRC errors

                ; todo: optimize start address
                ; check if something would overwrite this code and
                ; prevent it

_RX_DONE        MOVE    STR_DONE, R8
                SYSCALL(puts, 1)

_END            SYSCALL(exit, 1)

;=============================================================================
; CRC16 Calculation and hex conversion
;=============================================================================

; Function CALC_CRC
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

CALC_CRC16      INCRB

                MOVE    0xFFFF, R0              ; R0 = CRC
                MOVE    0xA001, R1              ; R1 = mask
                MOVE    R8, R2                  ; R2 = buffer pointer
                XOR     R3, R3                  ; R3 = i

_CCRC16_LOOP    XOR     @R2++, R0               ; crc ^= *buffer

                MOVE    R0, R4 
                AND     0xFFFB, SR              ; prepare SHR: clear carry
                SHR     1, R0                   ; crc >> 1
                AND     1, R4
                RBRA    _CCRC16_NOXOR, Z        ; crc & 1 == 0? no mask!
                XOR     R1, R0                  ; crc ^= mask

_CCRC16_NOXOR   ADD     1, R3
                CMP     R3, R9
                RBRA    _CCRC16_LOOP, !Z

                MOVE    R0, R10
                DECRB
                RET

; Function HEXSTR2I: Interprets 4 ASCII characters as a hexadecimal value
;                    and converts it into a number
; Input:  R8 =  pointer to 4 ASCII characters
; Output: R9 =  integer
HEXSTR2I        INCRB

                MOVE    R8, R0                  ; save R8
                MOVE    R10, R5                 ; save R10
                MOVE    R0, R1                  ; R1 iterates the input
                MOVE    4, R2                   ; loop counter
                XOR     R3, R3                  ; result

_H2SI_NXT_NIB   MOVE    @R1++, R8               ; next character
                MOVE    STR_HEX_NIBBLES, R9
                SYSCALL(strchr, 1)
                CMP     0, R10                  ; illegal character?
                RBRA    _HS2I_ILLEGAL, Z

                SUB     R9, R10                 ; R10 = hex nibble: 0..15
                SHL     4, R3                   ; old value one nibble left
                ADD     R10, R3                 ; add next value
                SUB     1, R2                   ; one less iteration
                RBRA    _H2SI_NXT_NIB, !Z       ; iterate!
                MOVE    R3, R9                  ; return value is in R9
                RBRA    _HS2I_END, 1

_HS2I_ILLEGAL   XOR     R9, R9
                RBRA    _HS2I_END, 1

_HS2I_END       MOVE    R0, R8
                MOVE    R5, R10
                DECRB
                RET


;=============================================================================
; UART Functions
;=============================================================================

; Function READ_UART: Reads into zero terminated buffer "VAR_BUFFER"
; Output: R8 =  amount of data words read
READ_UART       INCRB
                XOR     R1, R1                  ; 0 is default return value

                ; read until \n
                MOVE    VAR_BUFFER, R0
_RUA_NEXT_CHAR  RSUB    UART$GETCHAR, 1
                CMP     0x000A, R8                
                RBRA    _RUA_READ_END, Z
                MOVE    R8, @R0++
                ADD     1, R1
                RBRA    _RUA_NEXT_CHAR, 1
_RUA_READ_END   MOVE    0, @R0                  ; add string zero terminator

_END_RUA        MOVE    R1, R8
                DECRB
                RET

; Function WRITE_UART: send zero terminated buffer including the zero
; Input:
; R8 = Zero terminated buffer
WRITE_UART      INCRB
                MOVE    R8, R1
                MOVE    R1, R0

_WUA_NEXT_CHAR  MOVE    @R0++, R8
                RSUB    UART$PUTCHAR, 1
                CMP     0, @R0
                RBRA    _WUA_NEXT_CHAR, !Z
                XOR     R8, R8
                RSUB    UART$PUTCHAR, 1

                MOVE    R1, R8
                DECRB
                RET

; contains UART$GETCHAR and UART$PUTCHAR: we need this low level functions
; because we want to circumvent stdin/stdout and go directly to the UART
#include "../monitor/uart_library.asm"

;=============================================================================
; String constants and variables
;=============================================================================

STR_TITLE       .ASCII_W "QTransfer:\n  Waiting for serial connection   "
STR_OK          .ASCII_W "OK!\n"
STR_PROGRESS    .ASCII_W "  Data transfer in progress...    "
STR_DONE        .ASCII_W "Done!\n"

STR_ERR_NOSTART .ASCII_P "\nError: Wrong protocol. (Are you running "
                .ASCII_W "qtransfer.c on your host?)\n"
STR_ERR_CRC     .ASCII_W "\nError: CRC\n"

STR_START       .ASCII_W "START"
STR_END         .ASCII_W "END"
STR_ACK         .ASCII_W "ACK"
STR_CRCERR      .ASCII_W "CRCERR"

STR_HEX_NIBBLES .ASCII_W "0123456789ABCDEF"

VAR_BUFFER      .BLOCK 21
