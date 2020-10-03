#!/bin/bash
source ../tools/detect.include
FILES="qnice.c uart.c sd.c timer.c"
DEF_SWITCHES="-DUSE_SD -DUSE_UART -DUSE_TIMER"
UNDEF_SWITCHES="-UUSE_VGA -UUSE_IDE -U__EMSCRIPTEN__"
if [ $OSTP = "LINUX" ]; then
    MORE_SWITCHES="-lpthread"
fi;
$COMPILER $FILES -O3 $DEF_SWITCHES $UNDEF_SWITCHES $MORE_SWITCHES -o qnice -Wno-unused-result
