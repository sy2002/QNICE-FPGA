#!/bin/bash
source ../tools/detect.include
FILES="qnice.c uart.c sd.c"
DEF_SWITCHES="-DUSE_SD -DUSE_UART"
UNDEF_SWITCHES="-UUSE_VGA -UUSE_IDE -U__EMSCRIPTEN__"
$COMPILER $FILES -O3 $DEF_SWITCHES $UNDEF_SWITCHES -o qnice
