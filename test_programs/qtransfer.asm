; Development testbed for the QTransfer feature of the Monitor
;
; QNICE CRC16 safeguarded data transfer tool
;
; Use case: If you do not have a RTS/CTS protected serial line on your
; hardware, then this tool ensures the data integrety via CRC16
;
; qtransfer.c contains more details
;
; initially done as a stand-alone tool by sy2002 in May 2020
; converted into a part of the Monitor by sy2002 in September 2020

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0xE000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; R12 = receive buffer: create space on the stack
                ; (we cannot use R11, because mulu changes R11)
                SUB     VAR_BUF_WORDS, SP
                MOVE    SP, R12                  

                ; R4 = burst buffer: create space on the stack
                SUB     BURST_WORDS, SP
                MOVE    SP, R4

                ; wait until START is received
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    READ_UART, 1
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

                ; (<burst> x (<address><data>\n))<crc>\n
                ; all values are 16bit hex values where each one is
                ; transmitted as a 4 character ASCII string
_RX_LOOP        MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    READ_UART, 1

                ; "END" ends the transmission
                MOVE    STR_END, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _RX_DONE, Z

                ; receive burst length and store it in R0
                RSUB    HEXSTR2I, 1
                MOVE    R9, R0                  ; R0 = burst length
                MOVE    R0, R2                  ; R2 = backup burst length
                MOVE    R4, R1                  ; R1 = start of burst buf.

                ; receive one burst
_RX_BURST       MOVE    R1, R8                  ; READ_UART reads to this..
                RSUB    READ_UART, 1            ; ..gliding address
                SUB     1, R0                   ; one less element in burst
                RBRA    _RX_CRC, Z              ; current burst done!
                ADD     8, R1                   ; make room for next element
                RBRA    _RX_BURST, 1            ; next element of burst

                ; receive CRC of current burst and check it
_RX_CRC         SUB     CRC_BUF_WORDS, SP       ; reserve stack memory for CRC
                MOVE    SP, R8                  ; R8 = buffer for READ_UART
                RSUB    READ_UART, 1            ; receive CRC from host
                RSUB    HEXSTR2I, 1             ; convert to number
                MOVE    R9, R3                  ; R3 = received CRC
                ADD     CRC_BUF_WORDS, SP       ; free stack memory

                MOVE    R2, R8                  ; CRC is calculated over a..
                MOVE    8, R9                   ; ..buffer of size R2*8
                SYSCALL(mulu, 1)                
                MOVE    R10, R9                 ; R9 = burst size * 8
                MOVE    R4, R8                  ; R8 = start of burst buffer
                RSUB    CALC_CRC16, 1

                CMP     R10, R3                 ; received CRC == calc. CRC?
                RBRA    _CRC_OK, Z              ; yes

                ; CRC ERROR: Send error to UART, output error string, then end
                MOVE    STR_CRCERR, R8
                RSUB    WRITE_UART, 1
                MOVE    STR_ERR_CRC, R8
                SYSCALL(puts, 1)
                RBRA    _END, 1

                ; "ACK" to sender
_CRC_OK         MOVE    STR_ACK, R8
                RSUB    WRITE_UART, 1

                ; write to memory
                MOVE    R2, R0                  ; R0 = burst length
                MOVE    R4, R1                  ; R1 = start of burst buffer

_WRITE_LOOP     MOVE    R1, R8                  ; convert hex string address
                RSUB    HEXSTR2I, 1
                MOVE    R9, R5                  ; R5 = target address

                ADD     4, R1                   ; next hex string address
                MOVE    R1, R8                  ; convert hex string data
                RSUB    HEXSTR2I, 1
                ADD     4, R1                   ; next hex string address

                MOVE    R9, @R5                 ; R9 = data to be written
                SUB     1, R0                   ; burst over?
                RBRA    _WRITE_LOOP, !Z         ; no: continue to fill memory
                RBRA    _RX_LOOP, 1             ; yes: next RX iteration


_RX_DONE        MOVE    STR_DONE, R8
                SYSCALL(puts, 1)

                ; show start address of transmitted program/data
                MOVE    STR_START_ADDR, R8
                SYSCALL(puts, 1)
                MOVE    STR_16SPACES, R8
                SYSCALL(puts, 1)
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    READ_UART, 1
                RSUB    HEXSTR2I, 1
                MOVE    R9, R8
                MOVE    R8, R6                  ; R6 = start addr. for running
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; show overall size of transmitted program/data
                MOVE    STR_LENGTH, R8
                SYSCALL(puts, 1)
                MOVE    STR_16SPACES, R8
                SYSCALL(puts, 1)
                MOVE    R12, R8                 ; R12 = addr. of recv. buf.
                RSUB    READ_UART, 1
                RSUB    HEXSTR2I, 1
                MOVE    R9, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; offer to start/run the program
                MOVE    STR_RUN, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)
                SYSCALL(chr2upper, 1)
                CMP     'R', R8
                RBRA    _END, !Z

                ; run the program
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)
                ADD     BURST_WORDS, SP         ; free memory on the stack
                ADD     VAR_BUF_WORDS, SP
                ABRA    R6, 1                   ; run the program

_END            ADD     BURST_WORDS, SP         ; free memory on the stack
                ADD     VAR_BUF_WORDS, SP
                SYSCALL(exit, 1)

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

                AND     0xFFFB, SR              ; prepare SHR: clear carry
                SHR     1, R0                   ; crc >> 1
                RBRA    _CCRC16_NOXOR, !X       ; crc & 1 == 0? no mask!
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
                AND     0xFFFD, SR              ; clear X (shift in '0')
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

; Function READ_UART: Reads into zero terminated buffer at R8
; Output: R9 =  amount of data words read
READ_UART       INCRB
                MOVE    R8, R3                  ; save R8
                XOR     R1, R1                  ; 0 is default return value

                ; read until \n
                MOVE    R8, R0
_RUA_NEXT_CHAR  RSUB    UART$GETCHAR, 1
                CMP     0x000A, R8                
                RBRA    _RUA_READ_END, Z
                MOVE    R8, @R0++
                ADD     1, R1
                RBRA    _RUA_NEXT_CHAR, 1
_RUA_READ_END   MOVE    0, @R0                  ; add string zero terminator

_END_RUA        MOVE    R3, R8                  ; restore R8
                MOVE    R1, R9                  ; return number of words read
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
; Constants and variables
;=============================================================================

BURST_WORDS     .EQU 241                        ; 8 * BURST_SIZE + 1
VAR_BUF_WORDS   .EQU 9
CRC_BUF_WORDS   .EQU 5

STR_TITLE       .ASCII_W "QTransfer:\n  Waiting for serial connection   "
STR_OK          .ASCII_W "OK!\n"
STR_PROGRESS    .ASCII_W "  Data transfer in progress...    "
STR_DONE        .ASCII_W "Done!\n"
STR_START_ADDR  .ASCII_W "  Start address:  "
STR_LENGTH      .ASCII_W "  Length in words:"
STR_16SPACES    .ASCII_W "                "
STR_RUN         .ASCII_W "Press R to run and any other key to exit"

STR_ERR_NOSTART .ASCII_P "\nError: Wrong protocol. (Are you running "
                .ASCII_W "qtransfer.c on your host?)\n"
STR_ERR_CRC     .ASCII_W "CRC Error!\n"

STR_START       .ASCII_W "START"
STR_END         .ASCII_W "END"
STR_ACK         .ASCII_W "ACK"
STR_CRCERR      .ASCII_W "CRCERR"

STR_HEX_NIBBLES .ASCII_W "0123456789ABCDEF"
