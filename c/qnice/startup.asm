	.text
	.global	_main
	.global _exit
	asub	#_main,1
_exit:
	abra	0x16,1
loop:
	halt

