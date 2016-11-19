	.text
	.global _setjmp
_setjmp:
	move	R0,@R8++
	move	R1,@R8++
	move	R2,@R8++
	move	R3,@R8++
        move    R4,@R8++
        move    R5,@R8++
        move    R6,@R8++
        move    R7,@R8++
	move	R13,@R8++
	xor	R8,R8
	move	@R13++,R15

