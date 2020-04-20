; MEGA65 HyperRAM development testbed
; done by sy2002 in April 2020
;

#include "../../dist_kit/sysdef.asm"
#include "../../dist_kit/monitor.def"

                .ORG 0x8000

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; XYZ
                MOVE    R0, R10                 ; the comment goes here

                SYSCALL(exit, 1)

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
;    Bit  3 (read only)       Busy writing data (? @TODO)
IO$M65HRAM_LO       .EQU 0xFF61 ; Low word of address  (15 downto 0)
IO$M65HRAM_HI       .EQU 0xFF62 ; High word of address (26 downto 16)
IO$M65HRAM_DATA     .EQU 0xFF63 ; data in/out
