#!/usr/bin/env bash

source ./detect.include

$COMPILER bit2core.c -O3 -o bit2core
$COMPILER rgb2q.c -o rgb2q -O3 -Wno-format

TEST_FOR_LIBSERIALPORT=$($LINKER -lserialport 2>&1)
if [ "$TEST_FOR_LIBSERIALPORT" = "ld: library not found for -lserialport" ]; then
    QTRANSFER_WARNING=1
else
    $COMPILER qtransfer.c -o qtransfer -O3 -lserialport
fi

cd ..
$COMPILER assembler/qasm.c -o assembler/qasm
$COMPILER assembler/qasm2rom.c -o assembler/qasm2rom -std=c99

cd monitor
./compile_and_distribute.sh 
cd ..

cd pore
./compile_pore.sh
cd ..

cd emulator
./make.bash

SDL2_CFLAGS=`sdl2-config  --cflags`
if [ ! -z "$SDL2_CFLAGS" ]; then
    ./make-vga.bash -quiet
fi 

cd ../c
source setenv.source
./make-vasm.sh
./make-vlink.sh
./make-vbcc.sh
$COMPILER qnice/qniceconv.c -o qnice/qniceconv

echo ""
echo "==============================================================================="
echo ""

if [ "$QTRANSFER_WARNING" = "1" ]; then
    echo "WARNING: libserialport not found."
    echo "If you also want to make qtransfer, make sure that you have installed libserialport."
    if [ $OSTP = "OSX" ]; then
        echo "On a Mac you can use homebrew to get it: brew install libserialport"
        echo "Or you an directly get it from here: https://sigrok.org/wiki/Libserialport"
    else
        echo "Use your favorite package manager or get it directly from here: https://sigrok.org/wiki/Libserialport"
    fi
    echo "To make qtransfer, enter: $COMPILER qtransfer.c -o qtransfer -O3 -lserialport"
    echo ""
fi

echo "QNICE: Toolchain successfully made, if you do not see any error messages above."
echo "(Outputs like \"mkdir: xyz: File exists\" are OK.)"
