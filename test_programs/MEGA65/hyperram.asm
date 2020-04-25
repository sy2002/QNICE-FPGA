; MEGA65 HyperRAM development testbed
; done by sy2002 in April 2020
;

#include "../../dist_kit/sysdef.asm"
#include "../../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; registers addresses
                MOVE    IO$M65HRAM_LO, R0       ; lo word of the address
                MOVE    IO$M65HRAM_HI, R1       ; hi word of the address
                MOVE    IO$M65HRAM_DATA, R2     ; data
                MOVE    0xFF64, R3

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
                RBRA    _write, Z               ; yes: start HyperRAM tests
                RBRA    _rwa_e, 1               ; no: error out and end

                 ; write one byte
 _write         MOVE    STR_B_WD, R8
                SYSCALL(puts, 1)
                MOVE    0x2309, @R0
                MOVE    0x10, @R1
                MOVE    0x76, @R2

                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP

                ; read one byte
                MOVE    STR_B_RD, R8
                SYSCALL(puts, 1)                
                MOVE    @R2, R4                 ; initiate read
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP                                                                                                                                
                MOVE    @R3, R4                 ; complete read
                CMP     0x76, R4                ; correct data received?
                RBRA    _PEND, !Z               ; no: end
                MOVE    STR_OK, R8              ; yes: print OK
                SYSCALL(puts, 1)
                RBRA    _END, 1

_PEND           MOVE    R4, R8
                SYSCALL(puthex, 1)
                MOVE    0xFF65, R8
                MOVE    @R8, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                MOVE    0, @R0
                MOVE    0x200, @R1 
                MOVE    @R2, R4                 ; initiate read
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP                                                                                                                                
                MOVE    @R3, R8                 ; complete read
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0xFFFE, @R0
                MOVE    0x7F, @R1
                MOVE    @R2, R4
                MOVE    @R3, R8               
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)                                

                MOVE    0xFFFF, @R0
                MOVE    0x7F, @R1
                MOVE    @R2, R4
                MOVE    @R3, R8               
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    0, @R0
                MOVE    0, @R1
                MOVE    @R2, R4
                MOVE    @R3, R8               
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)                                

                MOVE    0x0, @R0
                MOVE    0x10, @R1
                MOVE    @R2, R4
                MOVE    @R3, R8               
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)                                


_END            SYSCALL(exit, 1)

; Function xyz
; R8 = Title
; R9 = offset lo
; R10 = offset hi
; R11: output DWORD, when R11 = 1, else output WORD
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

STR_TITLE       .ASCII_P "MEGA65 HyperRAM development testbed  -  done by sy2002 in April 2020\n"
                .ASCII_W "====================================================================\n\n"

ERR_RWADDR      .ASCII_W "Error: HyperRAM address register is not working: "

STR_B_WD        .ASCII_W "Before Writing\n"
STR_B_RD        .ASCII_W "Before Reading\n"
STR_OK          .ASCII_W "OK\n"


;=============================================================================
; Register and Constants for sysdef.asm
;=============================================================================

IO$M65_HRAM_RREQ    .EQU 0x0001                         ; read request
IO$M65_HRAM_WREQ    .EQU 0x0002                         ; write request
IO$M65_HRAM_DREADY  .EQU 0x0004                         ; data ready strobe
IO$M65_HRAM_BUSY    .EQU 0x0008                         ; busy (writing? @TODO)

;
;  HyperRAM (8-Bit Data)
;
IO$M65HRAM_CSR      .EQU 0xFF60 ; Command and Status Register
;    Bit  0 (write only)      Read request: outputs to IO$M65HRAM_READ
;    Bit  1 (write only)      Write request: takes data from IO$
;                             Read and write cannot happen in parallel (? @TODO)
;    Bit  2 (read only)       Data ready strobe: data can be read
;                             (not needed in normal operation due to automatic
;                             CPU wait state insertion of the controller)
;    Bit  3 (read only)       Busy writing data (? @TODO)
;                             (not needed in normal operation)
IO$M65HRAM_LO       .EQU 0xFF61 ; Low word of address  (15 downto 0)
IO$M65HRAM_HI       .EQU 0xFF62 ; High word of address (26 downto 16)
IO$M65HRAM_DATA     .EQU 0xFF63 ; Data in/out
                                ; writes to the write-flipflop and reads from
                                ; the read flip-flop so you cannot read here
                                ; what you have written to the write-flipflop
