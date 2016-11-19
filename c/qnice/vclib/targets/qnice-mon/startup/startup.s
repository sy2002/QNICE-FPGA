    .include "monitor.vdef"

	.text
	.global	___main
	.global ___exit
	.global ___cstart
___cstart:
	asub	#___main, 1
___exit:
	abra	exit, 1
loop:
	halt

