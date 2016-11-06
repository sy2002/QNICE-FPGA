	.text
	.global	___main
	.global ___exit
	.global ___cstart
___cstart:
	asub	#___main,1
___exit:
	asub	0x16,1
loop:
	halt

