#!/usr/bin/env bash

DISK_IMAGE=qnice_disk_v16.img
HOSTING_LOCATION=http://sy2002x.de/hwdp

FULL_PATH=$HOSTING_LOCATION/$DISK_IMAGE

if [ ! -f ../assembler/qasm ] || [ ! -f ../assembler/qasm2rom ]; then
    source ../tools/detect.include
    cd ..
    $COMPILER assembler/qasm.c -o assembler/qasm
    $COMPILER assembler/qasm2rom.c -o assembler/qasm2rom -std=c99
    cd emulator
fi

if [ ! -f ../monitor/monitor.out ]; then
    cd ../monitor
    ../assembler/asm monitor.asm
    cd ../emulator
fi

if [ ! -f qnice-vga ]; then
    ./make-vga.bash
fi

if [ ! -f $DISK_IMAGE ]; then
    wget $FULL_PATH || curl -O $FULL_PATH
fi


if [ ! ./qnice-vga ] || [ ! ../monitor/monitor.out ] || [ ! -f $DISK_IMAGE ]; then
    echo ""
    echo "ERROR: Something went wrong."
    echo ""
    exit 1
fi

./qnice-vga -a $DISK_IMAGE ../monitor/monitor.out
