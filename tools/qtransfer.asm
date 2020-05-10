; QNICE CRC16 safeguarded data transfer tool
; Use case: If you don't have a RTS/CTS protected serial line, then this tool
; ensures the data integrety via CRC16
; done by sy2002 in May 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0xE000

                MOVE    STR_TITLE, R8           ; print title
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
_SENDACK        MOVE    STR_ACK, R8
                RSUB    WRITE_UART, 1

                ; DEBUG: Check CRC16 of "ACK"
                MOVE    3, R9
                RSUB    CALC_CRC16, 1
                MOVE    R10, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; receive 21 characters:
                ; <addr 0x0000> <value> <crc> = 3*6 + 2 spaces + 1 zero term.

                ; todo: optimize start address
                ; check if something would overwrite this code and
                ; prevent it

_END            SYSCALL(exit, 1)

;=============================================================================
; CRC16 Calculation
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

STR_TITLE       .ASCII_W "QTransfer: Waiting for serial connection\n"

STR_ERR_NOSTART .ASCII_P "Error: Wrong protocol. (Are you running qtransfer.c"
                .ASCII_W " on your host?)\n"

STR_START       .ASCII_W "START"
STR_ACK         .ASCII_W "ACK"

VAR_BUFFER      .BLOCK 21
