#!/usr/bin/env bash

cd ..
gcc assembler/qasm.c -o assembler/qasm
gcc assembler/qasm2rom.c -o assembler/qasm2rom -std=c99

cd emulator
./make.bash

cd ../c
source setenv.source
./make-vasm.sh
./make-vlink.sh
./make-vbcc.sh
gcc qnice/qniceconv.c -o qnice/qniceconv
