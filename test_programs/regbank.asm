; Checks, if all register banks are working by putting data in all registers
; then generating a check sum for each register. The validity of the check sum
; for each register is shown on the emulated TIL by cycling through all 8
; result registers, showing the actual value, then subtracting the correct
; value, so that next a "0" should be shown.
;
; Also, a simple RAM check is included, as this test program does subtractions
; in RAM and furtheron uses RSUB to call the delay routine, therefore a super
; small stack on RAM is utilized using two nested function calls
;
; Everything works correct, if the TIL displays the following sequence in 
; a loop: 8080, 0000, 1700, 0000 
;
; done by sy2002 on August, 1st/2nd 2015

IO$TIL_BASE     .EQU    0xFF10              ; Address of TIL-display

; about 10.000.000 cycles are needed to delay 1 sec
WAIT_CYCLES1    .EQU    0x1388              ; 0x1388 = decimal 5.000
WAIT_CYCLES2    .EQU    0x07D0              ; 0x07D0 = decimal 2.000

NEXT_BANK       .EQU    0x0100              ; added to SR: switch to next bank

; expected check sum values
CHECK_R0        .EQU    0x8080              ; sum(1..256) = 32.896 = 0x8080
CHECK_R1        .EQU    0x1700              ; 256 x 23 = 5.888 = 0x1700

; memory locations
STACK_TOP       .EQU    0x8020              ; top of the stack, initial SP
VAR_DIFF        .EQU    0x8000              ; variable in memory to store the
                                            ; difference between a register
                                            ; value and the expected value

                .ORG    0x0000

                MOVE    0x8020, R13         ; setup stack pointer

                MOVE    0x1111, R0
                MOVE    0x2222, R1
                RBRA    DISPLAY_LOOP, 1 

                OR      0xFF00, R14         ; activate highest register page
                MOVE    0x0100, R8          ; loop through 256 banks
                MOVE    0x0001, R9          ; we need to sub 1 often
                MOVE    NEXT_BANK, R10      ; we need to sub 0x100 often
                MOVE    23, R11             ; we need to move 23 often

; fill registers throughout 256 registerbanks with meaningful values
BANK_LOOP       MOVE    R8, R0              ; move 256 downto 1 in all R0's
                MOVE    R11, R1             ; move 23 in all R1's
                SUB     R10, R14            ; previous register bank
                SUB     R9, R8              ; decrease loop counter
                RBRA    BANK_LOOP, !Z       ; loop 256 downto 1 (0 exits)

; calculate check sums over all registers and store the results in bank 0
                MOVE    0x00FF, R8          ; loop only through 255 as we
                AND     0x00FF, R14         ; are adding everything to bank 0

CHECK_LOOP      ADD     R10, R14            ; next bank

                MOVE    R0, R12             ; use R12 as temp for R0
                MOVE    R14, R11            ; save current bank page
                AND     0x00FF, R14         ; back to bank 0
                ADD     R12, R0             ; accumulate check sum in R0
                MOVE    R11, R14            ; restore current bank page

                MOVE    R1, R12             ; use R12 as temp for R1
                MOVE    R14, R11            ; save current bank page
                AND     0x00FF, R14         ; back to bank 0
                ADD     R12, R1             ; accumulate check sum in R1
                MOVE    R11, R14            ; restore current bank page

                SUB     R9, R8              ; decrease loop counter
                RBRA    CHECK_LOOP, !Z      ; loop 255 downto 1 (0 exits)


; output results to TIL
DISPLAY_LOOP    AND     0x00FF, R14         ; switch back to reg bank 0                
                MOVE    IO$TIL_BASE, R12    ; TIL MMIO display address

                ; display register R0 and the difference to the expected value
                MOVE    R0, R8              ; register = R8          
                MOVE    CHECK_R0, R9        ; expected value = R9
                RSUB    DISPLAY_REG, 1      ; call sub routine

                ; dito R1
                MOVE    R1, R8
                MOVE    CHECK_R1, R9
                RSUB    DISPLAY_REG, 1

                RBRA    DISPLAY_LOOP, 1

                HALT

; sub routine to display the register value and the expected value
; the sub routine uses another sub routine so this is also a nice first
; test of stacked sub routine calls
; input: R8 = register, R9 = expected value, R12 = TIL BASE
DISPLAY_REG     ADD     NEXT_BANK, R14      ; next register bank
                MOVE    R8, @R12            ; display value on TIL
                RSUB    DELAY, 1            ; wait 1 second
                MOVE    VAR_DIFF, R0        ; memory location of variable
                MOVE    R8, @R0             ; store register value in var
                SUB     R9, @R0             ; subtract expected value
                MOVE    @R0, @R12           ; display difference reg vs. expct
                RSUB    DELAY, 1            ; wait 1 second 
                SUB     NEXT_BANK, R14      ; previous register bank
                MOVE    @R13++, R15         ; return from sub routine

; sub routine to wait for about 1sec
DELAY           ADD     NEXT_BANK, R14      ; next register bank
                MOVE    WAIT_CYCLES2, R1    ; outer wait cycles (2.000)
WAIT_LOOP2      MOVE    WAIT_CYCLES1, R0    ; inner wait cycles (5.000)
WAIT_LOOP1      SUB     1, R0               ; dec inner wait cycles and ...
                RBRA    WAIT_LOOP1, !Z      ; ... repeat if not zero
                SUB     1, R1               ; dec outer wait cycles and ...
                RBRA    WAIT_LOOP2, !Z      ; ... repeat if not zero
                SUB     NEXT_BANK, R14      ; previous register bank
                MOVE    @R13++, R15         ; return from sub routine

