;
;;=============================================================================
;; The collection of math related functions starts here
;;=============================================================================
;
;******************************************************************************
;*
;* MTH$MULS performs a signed 16 x 16 multiplication of the form 
;* R11(H)/R10(L) = R8 * R9. It is merely an interface to the EAE.
;*
;******************************************************************************
;
MTH$MULS        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$MULS, @R0
#ifndef EAE_NO_WAIT
_MTH$MULS_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$MULS_BUSY, !Z  ; Still busy, wait...
#endif
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
;
;******************************************************************************
;*
;* MTH$MULU performs an unsigned 16 x 16 multiplication of the form 
;* R11(H)/R10(L) = R8 * R9. It is merely an interface to the EAE.
;*
;******************************************************************************
;
MTH$MULU        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$MULU, @R0
#ifndef EAE_NO_WAIT
_MTH$MULU_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$MULU_BUSY, !Z  ; Still busy, wait...
#endif
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
;
;******************************************************************************
;*
;* MTH$DIVS performs a signed 16 / 16 division of the form 
;* R11 = R8 % R9 and R10 = (int) (R8 / 10)
;*
;******************************************************************************
;
MTH$DIVS        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$DIVS, @R0
#ifndef EAE_NO_WAIT
_MTH$DIVS_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$DIVS_BUSY, !Z  ; Still busy, wait...
#endif
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
;
;******************************************************************************
;*
;* MTH$DIVU performs an unsigned 16 / 16 division of the form 
;* R11 = R8 % R9 and R10 = (int) (R8 / 9)
;*
;******************************************************************************
;
MTH$DIVU        INCRB
                MOVE    IO$EAE_OPERAND_0, R0
                MOVE    R8, @R0++           ; R0 now points to OPERAND_1
                MOVE    R9, @R0
                MOVE    IO$EAE_CSR, R0
                MOVE    EAE$DIVU, @R0
#ifndef EAE_NO_WAIT
_MTH$DIVU_BUSY  MOVE    @R0, R1             ; Test busy bit
                AND     0x8000, R1
                RBRA    _MTH$DIVU_BUSY, !Z  ; Still busy, wait...
#endif
                MOVE    IO$EAE_RESULT_LO, R0
                MOVE    @R0++, R10
                MOVE    @R0, R11
                DECRB
                RET
;
;******************************************************************************
;* MTH$MULU32 multiplies two 32bit unsigned values and returns a 64bit unsigned
;*
;* INPUT:  R8/R9   = LO/HI of unsigned multiplicant 1
;*         R10/R11 = LO/HI of unsigned multiplicant 2
;* OUTPUT: R11/R10/R9/R8 = HI .. LO of 64bit result
;******************************************************************************
;
MTH$MULU32      INCRB                           ; registers R3..R0 = result ..
                INCRB                           ; .. therefore two INCRBs

                ; save arguments as in R1|R0 * R3|R2
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3

                ; algorithm:
                ;       R1R0
                ; x     R3R2
                ; ----------
                ;       R2R0
                ; +   R2R1
                ; +   R3R0
                ; + R3R1
                ; ----------

                MOVE    R0, R8                  ; R2 * R0
                MOVE    R2, R9
                RSUB    MTH$MULU, 1             ; result in R11|R10
                DECRB
                MOVE    R10, R0
                MOVE    R11, R1
                XOR     R2, R2
                XOR     R3, R3
                INCRB

                MOVE    R1, R8                  ; R2 * R1
                MOVE    R2, R9
                RSUB    MTH$MULU, 1
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R0, R8                  ; R3 * R0
                MOVE    R3, R9
                RSUB    MTH$MULU, 1
                DECRB
                ADD     R10, R1
                ADDC    R11, R2
                ADDC    0, R3
                INCRB

                MOVE    R1, R8                  ; R3 * R1
                MOVE    R3, R9
                RSUB    MTH$MULU, 1
                DECRB
                ADD     R10, R2
                ADDC    R11, R3

                MOVE    R3, R11                 ; store result (return values)
                MOVE    R2, R10
                MOVE    R1, R9
                MOVE    R0, R8

                DECRB
                RET
;
;******************************************************************************
;* MTH$DIVU32 divides 32bit dividend by 32bit divisor and returns
;*            a 32bit quotient and a 32bit modulo
;*            warning: no division by zero warning; instead, the function 
;*            returns zero as result and as modulo
;*
;* INPUT:  R8/R9   = LO|HI of unsigned dividend
;*         R10/R11 = LO|HI of unsigned divisor
;* OUTPUT: R8/R9   = LO|HI of unsigned quotient
;*         R10/R11 = LO|HI of unsigned modulo
;******************************************************************************
;
MTH$DIVU32      INCRB

                ; perform the division by using the following algorithm, where
                ; N = dividend = HI|LO = R9|R8
                ; D = divisor  = HI|LO = R11|R10
                ; Q = quotient = HI|LO = R1|R0
                ; R = remainder (modulo) = HI|LO = R3|R2
                ;
                ; Q := 0               quotient and remainder = 0
                ; R := 0                     
                ; for i = n-1...0 do   where n is number of bits in N
                ;   R := R << 1        left-shift R by 1 bit
                ;   R(0) := N(i)       set the least-significant bit
                ;                      of R equal to bit i of the divisor    
                ;   if R >= D then
                ;     R := R - D
                ;     Q(i) := 1
                ;   end
                ; end                

                XOR     R0, R0                  ; HI|LO = R1|R0 = quotient
                XOR     R1, R1                  
                XOR     R2, R2                  ; HI|LO = R3|R2 = reminder
                XOR     R3, R3

                ; division by zero
                ; as we have no interrupts and no additional error flag,
                ; we return zero on a division by zero
                CMP     R11, R0
                RBRA    _MTH$DIVU32_ST, !Z
                CMP     R10, R0
                RBRA    _MTH$DIVU32_ST, !Z
                RBRA    _MTH$DIVU32_END, 1

_MTH$DIVU32_ST  MOVE    31, R4                  ; R4 = bit counter: 31 .. 0

                ; R := R << 1: 32bit shift-left of R
_MTH$DIVU32_NBT AND     0xFFFD, SR              ; clear X (shift in '0')
                SHL     1, R2                   ; MSB of lo word shifts to C
                RBRA    _MTH$DIVU32_SL0, !C     ; C=0 => X=0
                OR      0x0002, SR              ; C=1 => X=1
                SHL     1, R3                   ; hi word (shifts in X=1)
                RBRA    _MTH$DIVU32_RNI, 1
_MTH$DIVU32_SL0 AND     0xFFFD, SR              ; C=0 => X=0                
                SHL     1, R3                   ; hi word (shifts in X=0)

                ; R(0) := N(i)
_MTH$DIVU32_RNI MOVE    R4, R6
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _MTH$DIVU32_RNL, !N     ; yes: consider low word of R
                MOVE    R9, R5                  ; high word of N
                SUB     16, R6                  ; correct index b/c of hi word
                RBRA    _MTH$DIVU32_RNH, 1
_MTH$DIVU32_RNL MOVE    R8, R5                  ; low word of N
_MTH$DIVU32_RNH AND     0xFFFB, SR              ; clear C
                SHR     R6, R5                  ; extract bit by SHR to the ..
                AND     1, R5                   ; ..LSB pos. and and-ing 1
                AND     0xFFFE, R2              ; clear target bit and ...
                OR      R5, R2                  ; ... set it again, if needed

                ; if R >= D then
                ; done by doing 32bit R - D and checking:
                ; if MSB = 1, then R < D, else R >= D
                ; hint: MSB in this case is the 33th bit, i.e. bit #32 = carry
                MOVE    R2, R5                  ; R5 = low word of R
                MOVE    R3, R6                  ; R6 = high word of R
                SUB     R10, R5                 ; R6|R5 = 32bit (R := R - D)
                SUBC    R11, R6
                RBRA    _MTH$DIVU32_ITR, C      ; bit #32 is "negative"

                ; when reaching this code, R is >= D
                ;   if R >= D then
                ;     R := R - D
                ;     Q(i) := 1
                ;   end
                MOVE    R6, R3                  ; R = R6|R5 = (R := R - D)
                MOVE    R5, R2
                MOVE    1, R7                   ; Q(i) := 1 by shifting a "1"
                CMP     R4, 15                  ; R4 <= 15?
                RBRA    _MTH$DIVU32_QL, !N      ; yes: consider low word of Q
                MOVE    R4, R6                  ; R6 := i
                SUB     16, R6                  ; adjust for high word
                AND     0xFFFD, SR              ; clear X
                SHL     R6, R7                  ; move "1" to the right place
                OR      R7, R1                  ; R1:= hi Q(i) := 1
                RBRA    _MTH$DIVU32_ITR, 1

_MTH$DIVU32_QL  AND     0xFFFD, SR              ; clear X
                SHL     R4, R7                  ; move "1" to the right place
                OR      R7, R0                  ; R0 := low Q(i) := 1

                ; for i = n-1...0 do (i.e. also one loop for the case i=0)
_MTH$DIVU32_ITR SUB     1, R4
                RBRA    _MTH$DIVU32_NBT, !N     ; !N includes a round for i=0

                ; return results
_MTH$DIVU32_END MOVE    R1, R9                  ; hi Q
                MOVE    R0, R8                  ; lo Q
                MOVE    R3, R11                 ; hi R
                MOVE    R2, R10                 ; lo R

                DECRB
                RET
;
;******************************************************************************
;*
;* MTH$IN_RANGE_U    returns C=1 if R9 <= R8 < R10 else C=0
;*                   R8, R9, R10 treated as unsigned
;*
;******************************************************************************
;
MTH$IN_RANGE_U  INCRB
                AND     0xFFFB, SR              ; Clear carry bit
                CMP     R8, R9
                RBRA    _MTH$IRU_1, Z
                RBRA    _MTH$IRU_1, N
                RET                             ; Not in range
_MTH$IRU_1      CMP     R10, R8
                RBRA    _MTH$IRU_2, N
                RET
_MTH$IRU_2      OR      0x0004, SR              ; Set carry bit
                DECRB
                RET

;******************************************************************************
;*
;* MTH$IN_RANGE_S    returns C=1 if R8 >= R9 and < R10 else C=0
;*                   R8, R9, R10 treated as signed
;*
;******************************************************************************
;
MTH$IN_RANGE_S  HALT
