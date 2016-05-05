;
;;=============================================================================
;; The collection of math related functions starts here
;;=============================================================================
;
;******************************************************************************
;* MTH$MUL performs a highly unelegant signed 16 x 16 multiplication of the
;* form R11(H)/R10(L) = R8 * R9.
;*
;* (R2 = XL, R3 = XH) = (R8 = |A|), initally
;* R4 = |B|
;* R10 = RL, R11 = RH (result)
;* R5 = counter
;******************************************************************************
MTH$MUL         INCRB
                XOR     R0, R0              ; Clear negative flags
                XOR     R1, R1
                XOR     R3, R3              ; Clear XH
                MOVE    R8, R2              ; Negative A?
                RBRA    _MTH$MUL_A_POS, !N  ; No
                XOR     R2, R2              ; A is negative
                SUB     R8, R2              ; R2 = |R8|
                MOVE    1, R0               ; Remember that A was negative
_MTH$MUL_A_POS  MOVE    R9, R4              ; Negative B?
                RBRA    _MTH$MUL_B_POS, !N  ; No
                XOR     R4, R4              ; B is negative
                SUB     R9, R4              ; R4 = |R9|
                MOVE    1, R1               ; Remember that B was negative
_MTH$MUL_B_POS  XOR     R10, R10            ; Clear the two result registers
                XOR     R11, R11
                MOVE    0x0010, R5          ; Initialize counter to 16
_MTH$MUL_LOOP   SHR     1, R4               ; Determine LSB of B
                RBRA    _MTH$MUL_LAST, !X   ; Nothing to add, LSB was 0
                ADD     R2, R10             ; Add to low result word
                ADDC     R3, R11            ; Add to high result word + C
_MTH$MUL_LAST   SHL     1, R2               ; Shift XL/XH one bit left
                RBRA    _MTH$MUL_ZERO, !C   ; No carry shifted out
                OR      0x0002, SR          ; There was a carry, set X bit
_MTH$MUL_ZERO   SHL     1, R3               ; No shift XH one to the left
                SUB     1, R5               ; Decrement counter
                RBRA    _MTH$MUL_LOOP, !Z   ; Still not done?
                CMPU    R0, R1              ; Are the negative flags equal?
                RBRA    _MTH$MUL_EXIT, Z    ; Yes, nothing further to do
                NOT     R10, R10            ; 2s-complement of the result
                NOT     R11, R11
                ADD     1, R10
                ADDC     0, R11
_MTH$MUL_EXIT   DECRB
                RET

