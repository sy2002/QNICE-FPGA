; This test file is the very first test of the CPU.
; It tests the following:
; MOVE R, R
; MOVE @R, R
; MOVE @R++, R
; MOVE @--R, R
; So far, no data dependencies are challenged. I.e. a register
; written to is not used until at least 4 instructions later (
; corresponding to the length of the pipeline).


; First we place some dummy words, since PC currently starts at 0x0010.
.DW   0x0100
.DW   0x0101
.DW   0x0102
.DW   0x0103
.DW   0x0104
.DW   0x0105
.DW   0x0106
.DW   0x0107
.DW   0x0108
.DW   0x0109
.DW   0x010A
.DW   0x010B
.DW   0x010C
.DW   0x010D
.DW   0x010E
.DW   0x010F

; Start with simple MOVE R, R. This fills the registers with known (non-zero) values.
MOVE  R15, R0     ; Should put 0x0011 into R0
MOVE  R15, R1     ; Should put 0x0012 into R1
MOVE  R15, R2     ; Should put 0x0013 into R2
MOVE  R15, R3     ; Should put 0x0014 into R3

; Now do some more MOVE R, R, using the previous values.
MOVE  R0,  R4     ; Should put 0x0011 into R4
MOVE  R1,  R5     ; Should put 0x0012 into R5
MOVE  R2,  R6     ; Should put 0x0013 into R6
MOVE  R3,  R7     ; Should put 0x0014 into R7

; Now test MOVE @R, R
MOVE  @R0, R8     ; Should put 0x0F04 into R8  (hex for MOVE R15, R1)
MOVE  @R1, R9     ; Should put 0x0F08 into R9  (hex for MOVE R15, R2)
MOVE  @R2, R10    ; Should put 0x0F0C into R10 (hex for MOVE R15, R3)
MOVE  @R3, R11    ; Should put 0x0010 into R11 (hex for MOVE R0,  R4)

; Now test MOVE @R++, R
MOVE  @R0++, R4   ; Should put 0x0F04 into R4 and 0x0012 into R0
MOVE  @R1++, R5   ; Should put 0x0F08 into R5 and 0x0013 into R1
MOVE  @R2++, R6   ; Should put 0x0F0C into R6 and 0x0014 into R2
MOVE  @R3++, R7   ; Should put 0x0010 into R7 and 0x0015 into R3

; This is just to reset R4-R7 before the next test
MOVE  R0, R4      ; Should put 0x0012 into R4
MOVE  R1, R5      ; Should put 0x0013 into R5
MOVE  R2, R6      ; Should put 0x0014 into R6
MOVE  R3, R7      ; Should put 0x0015 into R7

; Now test MOVE @--R, R
MOVE  @--R0, R4   ; Should put 0x0F04 into R4 and 0x0011 into R0
MOVE  @--R1, R5   ; Should put 0x0F08 into R5 and 0x0012 into R1
MOVE  @--R2, R6   ; Should put 0x0F0C into R6 and 0x0013 into R2
MOVE  @--R3, R7   ; Should put 0x0010 into R7 and 0x0014 into R3

