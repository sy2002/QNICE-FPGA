; MEGA65 HyperRAM development testbed
; done by sy2002 in April and May 2020
;

#include "../../dist_kit/sysdef.asm"
#include "../../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                MOVE    0xFF66, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; registers addresses
                MOVE    IO$M65HRAM_LO, R0       ; lo word of the address
                MOVE    IO$M65HRAM_HI, R1       ; hi word of the address
                MOVE    IO$M65HRAM_DATA, R2     ; data

                ; check reading/writing address
                MOVE    0x4321, @R0             ; lo word is full 16bit wide
                MOVE    0x0678, @R1             ; hi "word" is only 11bit wide
                CMP     0x4321, @R0             ; check, if lo word is correct
                RBRA    _rwa, Z                 ; yes: check hi word
_rwa_e          MOVE    ERR_RWADDR, R8          ; no: show error message
                SYSCALL(puts, 1)
                MOVE    @R1, R8                 ; and then: hi word value
                SYSCALL(puthex, 1)
                MOVE    @R0, R8                 ; and then: lo word value
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                RBRA    _END, 1                 ; exit due to error
_rwa            CMP     0x0678, @R1             ; check, if hi word is correct
                RBRA    _readctl, Z             ; yes: start HyperRAM tests
                RBRA    _rwa_e, 1               ; no: error out and end


                ; DEBUG
 _readctl       MOVE    0xFF66, R4
                MOVE    @R4, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                ; For some reason (bug?) we need to read something, which will
                ; be wrong and only from then on, it will work
;                MOVE    0x0000, @R0
;                MOVE    0x0000, @R1
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R4, R8
;                SYSCALL(puthex, 1)
;                SYSCALL(crlf, 1)
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R4, R8
;                SYSCALL(puthex, 1)
;                SYSCALL(crlf, 1)


                MOVE    0x0001, @R0
                MOVE    0x0200, @R1
                MOVE    @R2, R8
                MOVE    @R2, R8
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R4, R8
                SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                MOVE    0x0000, @R0
                MOVE    @R2, R8                                
                SYSCALL(puthex,1)
                MOVE    @R4, R8
                SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                MOVE    0x1001, @R0
                MOVE    @R2, R8                             
                MOVE    @R2, R8                             
                SYSCALL(puthex, 1)
                MOVE    @R4, R8                                
                SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                MOVE    0x1000, @R0
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R4, R8
                SYSCALL(puthex,1)                
                SYSCALL(crlf,1)

;                MOVE    0x0000, @R0
;                MOVE    0x0000, @R1
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                MOVE    @R2, R8
;                SYSCALL(puthex, 1)
;                SYSCALL(crlf, 1)

                MOVE    0x1000, @R0
                MOVE    0x0001, @R1
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0x23, @R2

                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0x0002, @R1
                MOVE    0x0003, R5
_wloop          MOVE    R5, @R0
                MOVE    R5, @R2
                ADD     1, R5
                CMP     0x00A0, R5
                RBRA    _wloop, !Z

                MOVE    0x0003, R5
                MOVE    R5, R6
_rloop          MOVE    R5, @R0
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                CMP     R8, R5
                RBRA    _rloop_cnt, Z
                MOVE    R5, @--SP
                MOVE    R8, @--SP
                ADD     1, R6
_rloop_cnt      ADD     1, R5
                CMP     0x00A0, R5
                RBRA    _rloop, !Z
                SYSCALL(crlf, 1)

                CMP     0, R6
                RBRA    _END, Z

                MOVE    ERR_READ, R8
                SYSCALL(puts, 1)
                MOVE    R6, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

_show_err       MOVE    @SP++, R7
                MOVE    @SP++, R8
                SYSCALL(puthex, 1)
                MOVE    STR_COLON_SPACE, R8
                SYSCALL(puts, 1)
                MOVE    R7, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)                                
                SUB     1, R6
                RBRA    _show_err, !Z

_END            SYSCALL(exit, 1)

; Function xyz
; R8 = Title
; R9 = offset lo
; R10 = offset hi
; R11: output DWORD, when R11 = 1, else output WORDs
OUTPUT_DW       INCRB
                DECRB
                RET

;=============================================================================
; Variables
;=============================================================================

A_VARIABLE  .BLOCK 1                            ; mount struct / device handle

;=============================================================================
; String constants
;=============================================================================

STR_TITLE       .ASCII_P "MEGA65 HyperRAM development testbed  -  done by sy2002 in May 2020\n"
                .ASCII_W "==================================================================\n\n"

ERR_RWADDR      .ASCII_W "Error: HyperRAM address register is not working: "
ERR_READ        .ASCII_W "Read Errors: "

STR_COLON_SPACE .ASCII_W ": "
STR_OK          .ASCII_W "OK\n"


;=============================================================================
; Register and Constants for sysdef.asm
;=============================================================================

;
;  HyperRAM (8-Bit Data)
;
IO$M65HRAM_LO       .EQU 0xFF60 ; Low word of address  (15 downto 0)
IO$M65HRAM_HI       .EQU 0xFF61 ; High word of address (26 downto 16)
IO$M65HRAM_DATA     .EQU 0xFF62 ; Data in/out
