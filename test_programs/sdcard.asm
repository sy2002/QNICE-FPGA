; SD Card development testbed
; done by sy2002 in June 2016

#include "../dist_kit/sysdef.asm"
#include "../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)
                MOVE    STR_REGCHK_T, R8
                SYSCALL(puts, 1)
                
                ; SD registers
                MOVE    IO$SD_ADDR_LO, R0
                MOVE    IO$SD_ADDR_HI, R1
                MOVE    IO$SD_DATA_POS, R2
                MOVE    IO$SD_DATA, R3
                MOVE    IO$SD_ERROR, R4
                MOVE    IO$SD_CSR, R5

                ; perform register write/read-back checks
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
                MOVE    R4, R8                  ; ERROR is read only
                MOVE    0x0000, R9              ; and must be zero
                MOVE    STR_REGCHK_ER, R10
                RSUB    REG_CHECK, 1
                MOVE    R5, R8                  ; CSR status bits
                MOVE    0x0000, R9              ; must be zero
                MOVE    STR_REGCHK_CS, R10
                RSUB    REG_CHECK, 1

                ; read first 512 bytes (starting from address 0)
                MOVE    0, @R0                  ; block addr low word
                MOVE    0, @R1                  ; block addr hi word
                MOVE    SD$READ, @R5            ; start read operation
                RSUB    WAIT_BUSY, 1            ; wait until completed

                ; output buffer_ptr (via error)
                MOVE    @R4, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; output the 512 bytes of the buffer
                MOVE    0, R6
_TEMP           MOVE    R6, @R2
                MOVE    @R3, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                ADD     1, R6
                CMP     512, R6
                RBRA    _TEMP, !Z

                ; back to monitor
                SYSCALL(exit, 1)

; Register check subroutine: Expects the to be written and read-back
; register in R8, the value in R9 and the name string in R10
REG_CHECK       INCRB
                MOVE    R8, R0

                ; print "checking <register name>"
                MOVE    STR_REGCHK_R, R8
                SYSCALL(puts, 1)
                MOVE    R10, R8
                SYSCALL(puts, 1)

                ; write SD card register, read it back and test the value
                MOVE    R9, @R0                 ; write to the register
                MOVE    @R0, R1                 ; read it back
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

; Wait as long as the SD Card signals busy
WAIT_BUSY       INCRB
                MOVE    IO$SD_CSR, R0
WAIT_BUSY_LP    MOVE    @R0, R1                 ; read CSR register           
                AND     SD$BUSY, R1             ; check busy flag
                RBRA    WAIT_BUSY_LP, !Z        ; loop flag is set
                DECRB
                RET


STR_TITLE       .ASCII_W "SD Card development testbed\n===========================\n\n"
STR_OK          .ASCII_W "OK"
STR_FAILED      .ASCII_W "FAILED: "
STR_REGCHK_T    .ASCII_W "Register write and read-back:\n"
STR_REGCHK_R    .ASCII_W "    checking "
STR_REGCHK_AL   .ASCII_W "ADDR_LO: "
STR_REGCHK_AH   .ASCII_W "ADDR_HI: "
STR_REGCHK_DP   .ASCII_W "DATA_POS: "
STR_REGCHK_DTA  .ASCII_W "DATA: "
STR_REGCHK_ER   .ASCII_W "ERROR: "
STR_REGCHK_CS   .ASCII_W "CSR: "
