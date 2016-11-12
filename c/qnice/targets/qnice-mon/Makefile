#CC = vc +qnice-mon -k -dontwarn=-1 -I. -Iinclude -c99 -D__BUILD_LIB -DVCLIB_SHORTPRINTF -O -DTHRESHOLD="30" -DBUFSIZE="64" -mtiny
CC = vc +qnice-mon -k -ic2 -dontwarn=-1 -I. -Iinclude -c99 -D__BUILD_LIB -DVCLIB_SHORTPRINTF -O2 -DTHRESHOLD=10 -DBUFSIZ=64 -D_CLE=16384 -DHAVE_TTYS
AS = vasmqnice_std -quiet -Fvobj
AR = ar
RM = rm -f
CP = cp

all: build_vclib build_startup

build_startup:
	echo "Assembling startup code..."
	$(AS) -o startup.o startup/startup.s

	echo "Copying startup.o to lib..."
	$(CP) startup.o lib

build_vclib:
	echo "Removing unneeded files..."
	$(RM) stdlib/atoll.c
	$(RM) stdlib/llabs.c
	$(RM) stdlib/lldiv.c
	$(RM) stdlib/strtoll.c
	$(RM) stdlib/strtoull.c
	$(RM) stdlib/imaxabs.c
	$(RM) stdlib/imaxdiv.c
	$(RM) stdlib/strtoimax.c
	$(RM) stdlib/strtoumax.c
	$(RM) _lmul.c
	echo "Assembling QNICE Monitor wrappers..."
	$(AS) -o _lmul.o _lmul.s
	echo "Processing _main etc..."
	$(CC) -c _main.c
	$(CC) -c _errno.c
	$(CC) -c _errors.c
	$(CC) -c _chkabort.c
	echo "Processing ctype..."
	$(CC) -c ctype/*.c
	echo "Processing stdio..."
	$(CC) -c stdio/*.c
	echo "Processing stdlib..."
	$(CC) -c stdlib/*.c
	echo "Processing string..."
	$(CC) -c string/*.c
	echo "Processing time..."
	$(CC) -c time/*.c
	echo "Processing setjmp..."
	$(CC) -c setjmp/setjmp.s
	echo "Processing signal..."
	$(CC) -c signal/*.c
	echo "Processing locale..."
	$(CC) -c locale/*.c
	echo "Processing arith..."
	$(CC) -c _l*.c
	echo "Joining everything together..."
	$(RM) libvc.a
	$(AR) q libvc.a _main.o
	$(AR) q libvc.a _errno.o
	$(AR) q libvc.a _errors.o
	$(AR) q libvc.a _chkabort.o
	$(AR) q libvc.a ctype/*.o
	$(AR) q libvc.a stdio/*.o
	$(AR) q libvc.a stdlib/*.o
	$(AR) q libvc.a string/*.o
	$(AR) q libvc.a time/*.o
	$(AR) q libvc.a setjmp/*.o
	$(AR) q libvc.a signal/*.o
	$(AR) q libvc.a locale/*.o
	$(AR) q libvc.a _l*.o
	echo "Copying libvc.a to lib..."
	$(CP) libvc.a lib	
