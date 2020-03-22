#!/usr/bin/env bash

DISK_IMAGE=http://sy2002x.de/hwdp/qnice_disk.img

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

if [ ! -f qnice_disk.img ]; then
    wget $DISK_IMAGE || curl -O $DISK_IMAGE
fi


if [ ! ./qnice-vga ] || [ ! ../monitor/monitor.out ] || [ ! -f qnice_disk.img ]; then
    echo ""
    echo "ERROR: Something went wrong."
    echo ""
    exit 1
fi

./qnice-vga -a qnice_disk.img ../monitor/monitor.out
