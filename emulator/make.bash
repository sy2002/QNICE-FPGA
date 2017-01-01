#!/bin/bash
source ../tools/detect.include
$COMPILER qnice.c ide_simulation.c uart.c sd.c -o qnice -O3 -UUSE_VGA
