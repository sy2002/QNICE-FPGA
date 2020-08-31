all:
	rm -f lib/*
	vc src/qmon.c -o lib/qmon.o -c -O3 -k -c99 -rw-threshold=0 -speed
	mv src/*.asm lib
	ar q lib/qmon.a lib/qmon.o
