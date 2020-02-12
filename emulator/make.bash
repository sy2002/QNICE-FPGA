#!/bin/bash
source ../tools/detect.include
DEF_SWITCHES="-DUSE_SD -DUSE_UART"
UNDEF_SWITCHES="-UUSE_VGA -UUSE_IDE -U__EMSCRIPTEN__"
$COMPILER qnice.c ide_simulation.c uart.c sd.c -o qnice -O3 $DEF_SWITCHES $UNDEF_SWITCHES
