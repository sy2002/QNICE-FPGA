	.global	_longjmp
	.text
_longjmp:
	move	R8,R10
	add	9,R10
	move	@--R10,R13
	move	@--R10,R7
        move    @--R10,R6
        move    @--R10,R5
        move    @--R10,R4
        move    @--R10,R3
        move    @--R10,R2
        move    @--R10,R1
        move    @--R10,R0
	move	R9,R8
        move    @R13++,R15




