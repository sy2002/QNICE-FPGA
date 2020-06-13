; MEGA65 HyperRAM development testbed
; done by sy2002 in April to June 2020

#include "../../dist_kit/sysdef.asm"
#include "../../dist_kit/monitor.def"

                .ORG 0x8000

                ABRA    _start, 1

                ; DEBUG/SIMULATION
                MOVE    IO$M65HRAM_LO, R0       ; lo word of the address
                MOVE    IO$M65HRAM_HI, R1       ; hi word of the address
                MOVE    IO$M65HRAM_DATA16, R2   ; 16-bit data access

                MOVE    0x3333, @R0
                MOVE    0x0033, @R1
                MOVE    0xAAAA, @R2

                MOVE    @R2, R8
                MOVE    @R2, R8                 ; system gets stuck here

                SYSCALL(puthex, 1)              ; this is never executed
                SYSCALL(exit, 1)

                MOVE    0xAAAA, R5
                XOR     R6, R6

_dbgloop        CMP     0x0001, R6
                RBRA    _dbgend, Z
                MOVE    R5, @R2
                ADD     1, R5
                ADD     1, R6
                ADD     1, @R0
                RBRA    _dbgloop, 1

_dbgend         MOVE    0x3333, @R0
                MOVE    @R2, R8
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(exit, 1)

                MOVE    STR_TITLE, R8
                SYSCALL(puts, 1)

                ; DEBUG
                ;MOVE    0xFF66, R8
                ;MOVE    @R8, R8
                ;SYSCALL(puthex, 1)
                ;SYSCALL(crlf, 1)
                ;SYSCALL(crlf, 1)

                ; HyperRAM registers addresses
_start          MOVE    IO$M65HRAM_LO, R0       ; lo word of the address
                MOVE    IO$M65HRAM_HI, R1       ; hi word of the address
                MOVE    IO$M65HRAM_DATA8, R2    ; 8-bit data access
                MOVE    0xFF66, R4              ; DEBUG

                ;RBRA    _start_16bit, 1

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

                ; read control registers
                ; output should be: 0081, 000C, 00F6, 00FF
                ; see c/test_programs/hyperramtest.c for details
_readctl        MOVE    STR_CTRL, R8
                SYSCALL(puts, 1)

                ; DEBUG
                ;MOVE    0xFF66, R4
                ;MOVE    @R4, R8
                ;SYSCALL(puthex, 1)
                ;SYSCALL(crlf, 1)

                ; expected output of the two "DEBUG" mentioned above is
                ; two times 0x0000

                ; Some currently yet unclear magic from hyperramtest.c
                ; leads to more stable mass reading/writing
                ;MOVE    0x03FF, @R1
                ;MOVE    0xFFF5, @R0
                ;MOVE    0, @R2                  ; disable read delay
                ;MOVE    0xFFF2, @R0          
                ;MOVE    0x00B0, @R2             ; turn cache on

                ; read id0lo
                MOVE    0x0001, @R0
                MOVE    0x0200, @R1
                MOVE    @R2, R8                 ; hw bug: 2 reads necessary!
                MOVE    @R2, R8                 ; when this ctrl-reg is read
                SYSCALL(puthex, 1)              ; after cold start
                ;MOVE    @R4, R8
                ;SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                ; read id0hi
                MOVE    0x0000, @R0
                MOVE    @R2, R8                                
                SYSCALL(puthex,1)
                ;MOVE    @R4, R8
                ;SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                ; read cr0lo
                MOVE    0x1001, @R0
                MOVE    @R2, R8                             
                MOVE    @R2, R8                             
                SYSCALL(puthex, 1)
                ;MOVE    @R4, R8                                
                ;SYSCALL(puthex,1)
                SYSCALL(crlf, 1)

                ; read cr0hi
                MOVE    0x1000, @R0
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R4, R8
                ;SYSCALL(puthex,1)                
                SYSCALL(crlf,1)
                SYSCALL(crlf,1)

                ; expected output of the sequence ABOVE consisting of
                ; id0lo, id0hi, cr0lo, cr0hi is: $81, $0C, $F6, $FF

                MOVE    STR_5READs, R8
                SYSCALL(puts, 1)

                ; read 5 times at 0x0011000
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

                ; write 0x23 at 0x0011000
                MOVE    0x23, @R2

                ; again, read 5 times at 0x0011000
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
                SYSCALL(crlf, 1)

                MOVE    STR_8BIT, R8
                SYSCALL(puts, 1)

                ; ------------------------------------------------------------
                ; 8-bit test
                ; ------------------------------------------------------------

                ; fill 240 bytes (F0) starting from 0x0020003 with increasing
                ; values starting from 3 (3 .. 239)
                MOVE    0x0002, @R1
                MOVE    0x0003, R5
_wloop          MOVE    R5, @R0
                MOVE    R5, @R2
                ADD     1, R5
                CMP     0x00F0, R5
                RBRA    _wloop, !Z

                ; read and compare 240 bytes starting from 0x0020003:
                ; is the memory containing, what we wrote?
                ; if not, push the positions of the wrong values and the
                ; wrong values itself on the stack
                ; R6 contains the amount of errors
                XOR     R6, R6
                MOVE    0x0003, R5
_rloop          MOVE    R5, @R0
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                CMP     R8, R5
                RBRA    _rloop_cnt, Z
                MOVE    R5, @--SP
                MOVE    R8, @--SP
                ADD     1, R6
_rloop_cnt      ADD     1, R5
                CMP     0x00F0, R5
                RBRA    _rloop, !Z
                SYSCALL(crlf, 1)

                ; no errors? print "PASSED" message and jump to 16-bit test
                CMP     0, R6
                RBRA    _print_8berr, !Z
                MOVE    STR_8BIT_OK, R8
                SYSCALL(puts, 1)
                RBRA    _start_16bit, 1

                ; print errors
_print_8berr    MOVE    ERR_READ, R8
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

                ; ------------------------------------------------------------
                ; 16-bit test
                ; ------------------------------------------------------------

_start_16bit    MOVE    STR_16BIT, R8
                SYSCALL(puts, 1)

                MOVE    IO$M65HRAM_DATA16, R2   ; 16-bit data access

                ; fill 1MB starting at 0x0333333 with changing 16-bit
                ; values and then read everything back and test if correct
                ; 0x0333333 + 1 MB = 0x4333333
                MOVE    0x0033, @R1             ; hi-word of 0x0333333
                MOVE    0x3333, @R0             ; lo-word
                XOR     R5, R5                  ; repeatedly runs to 0xFFFF

                ; DEBUG                
                MOVE    0x4321, R5

_16bit_loop     CMP     0x0043, @R1             ; hi-word of 1MB reached?
                RBRA    _16bl_write, !Z         ; no: write next word
                CMP     0x3333, @R0             ; yes: check if lo-word fits
                RBRA    _16bit_check, Z         ; yes: leave loop, go checking

_16bl_write     MOVE    R5, @R2                 ; write test value
                ADD     1, R5                   ; increase test value
                ADD     1, @R0                  ; next word (inc lo-word)
                RBRA    _16bit_loop, !Z         ; no overflow => continue
                ADD     1, @R1                  ; inc hi-word
                RBRA    _16bit_loop, 1

                ; linearily check, if the 1MB data that was written above
                ; is now accessible in the HRAM
_16bit_check    MOVE    0x0033, @R1             ; hi-word of 0x0333333
                MOVE    0x3333, @R0             ; lo-word
                XOR     R5, R5                  ; repeatedly runs to 0xFFFF
                XOR     R6, R6                  ; R6 = error counter

                ; DEBUG
_dbgstart       MOVE    STR_OK, R8
                SYSCALL(puts, 1)

                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                MOVE    @R2, R8
                SYSCALL(puthex, 1)                                
                RBRA    _END, 1
                
                ; DEBUG
                ;MOVE    IO$M65HRAM_DATA8, R2    ; 8-bit data access  

_16bit_cloop    MOVE    STR_OK, R8
                SYSCALL(puts, 1)

                CMP     0x0043, @R1             ; hi-word of 1MB reached?
                RBRA    _16bl_check, !Z         ; no: check next word
                CMP     0x3333, @R0             ; yes: check if lo-word fits
                RBRA    _16bit_res, Z           ; yes: leave and print result

_16bl_check     MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    STR_OK, R8
                SYSCALL(puts, 1)

                MOVE    @R2, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    STR_OK, R8
                SYSCALL(puts, 1)

                CMP     R5, @R2                 ; HRAM = test value?
                RBRA    _16bit_err, !Z          ; no: error
                ADD     1, R5                   ; yes: increase test value
                ADD     1, @R0                  ; next word (inc lo-word)
                RBRA    _16bit_cloop, !Z        ; no overflow => continue

_16bit_res      MOVE    STR_16BIT_OK, R8
                SYSCALL(puts, 1)
                RBRA    _END, 1

_16bit_err      MOVE    ERR_16BIT, R8
                SYSCALL(puts, 1)

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
; String constants
;=============================================================================

STR_TITLE       .ASCII_P "MEGA65 HyperRAM development testbed  -  done by sy2002 in May 2020\n"
                .ASCII_W "==================================================================\n\n"
STR_CTRL        .ASCII_W "Control Registers:     (Output should be: 0081, 000C, 00F6, 00FF)\n"
STR_5READs      .ASCII_W "Read 5 times from 0x0011000, then write 0x23 there, then read 5 times:\n"
STR_8BIT        .ASCII_W "8-bit test: Fill 240 bytes from 0x0020003 with increasing values, then test:\n"
STR_8BIT_OK     .ASCII_W "8-bit test: PASSED\n"
STR_16BIT       .ASCII_W "\n16-bit linear test: Fill 1MB from 0x0333333 with 16-bit values, then test:\n"
STR_16BIT_OK    .ASCII_W "16-bit linear test: PASSED\n"

STR_COLON_SPACE .ASCII_W ": "
STR_OK          .ASCII_W "OK\n"

ERR_RWADDR      .ASCII_W "Error: HyperRAM address register is not working: "
ERR_READ        .ASCII_W "Read Errors: "
ERR_16BIT       .ASCII_W "16-bit linear test: FAILED\n"

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
