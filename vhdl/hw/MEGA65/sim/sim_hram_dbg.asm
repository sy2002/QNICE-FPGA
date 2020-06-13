; MEGA65 HyperRAM
; Minimal reproduction code for the following HyperRAM problem as basis
; for simulation
; done by sy2002 on June, 12 2020
;

#include "../../../../dist_kit/sysdef.asm"
#include "../../../../dist_kit/monitor.def"

                .ORG 0x0000

                ; MMIO addresses of the HyperRAM controller => registers
                MOVE    IO$M65HRAM_LO, R0       ; lo word of the address
                MOVE    IO$M65HRAM_HI, R1       ; hi word of the address
                MOVE    IO$M65HRAM_DATA16, R2   ; 16-bit data access

                ; HyperRAM access
                MOVE    0x3333, @R0             ; lo word of address = 0x3333
                MOVE    0x0033, @R1             ; hi word of address = 0x0033
                MOVE    0xABCD, @R2             ; write 0xABCD to 0x00333333

                MOVE    @R2, R8                 ; read 0x00333333 to R8
                                                ; and do it again
                MOVE    @R2, R8                 ; PROBLEM: system stalls here

                SYSCALL(puthex, 1)              ; this code is never reached
                SYSCALL(exit, 1)

;=============================================================================
; Register and Constants for sysdef.asm
;=============================================================================

;
;  HyperRAM
;
IO$M65HRAM_LO       .EQU 0xFF60 ; Low word of address  (15 downto 0)
IO$M65HRAM_HI       .EQU 0xFF61 ; High word of address (26 downto 16)
IO$M65HRAM_DATA8    .EQU 0xFF62 ; HyperRAM native 8-bit data in/out
IO$M65HRAM_DATA16   .EQU 0xFF63 ; HyperRAM 16-bit data in/out
