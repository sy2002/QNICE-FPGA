#!/bin/bash

if [ ! -f qnice-vga ]; then
    echo "Build the QNICE Emulator with VGA and PS/2 (USB) keyboard support."
    echo ""
    echo "Some hints:"
    echo "* You need to have SDL2 installed for compiling."
    echo "* We are linking static libs, so SDL2 does not need to be installed"
    echo "  on the end user's machine."
    echo "* Run the executable with ./qnice-vga"
    echo ""
    read -p "Press ENTER to continue or CTRL+C to quit."
fi

source ../tools/detect.include

SDL2_CFLAGS=`sdl2-config  --cflags`

if [ -z "$SDL2_CFLAGS" ]; then
    echo ""
    echo "error: SDL2 not found!"
    echo ""
    if [ "$OSTP" = "OSX" ]; then
        echo "On OSX we suggest using the Homebrew package manager. Install it "
        echo "via http://brew.sh and then install SDL2 by entering: brew install sdl2"
        echo "Alternatively, go to https://www.libsdl.org"

    else
        echo "Use your favorite package manager or go to https://www.libsdl.org"
    fi
    exit
fi 

#Temporarily removed due to https://github.com/sy2002/QNICE-FPGA/issues/78
#That means that for now, we revert back from static linking to dynamic linking
#if [ $OSTP = "OSX" ]; then
    #On OSX sdl2-config is not returning the right string to build statically, so we
    #need to create it manually by finding out the path to the SDL2 library and then
    #by replacing the lSDL2 part in the output of sdl2-config
#    PATH_TO_SDL2LIB=$(sdl2-config --static-libs | perl -pe 's|(-L/.+?\s).*|\1|' | cut -c 3- | rev | cut -c 2- | rev)"/libSDL2.a"
#    SDL2_LIBS=$(sdl2-config --static-libs | sed 's|-lSDL2|'$PATH_TO_SDL2LIB'|')
#else
#    SDL2_LIBS=`sdl2-config --static-libs`
#fi

SDL2_LIBS=`sdl2-config --libs`

FILES="qnice.c fifo.c sd.c uart.c vga.c timer.c"
DEF_SWITCHES="-DUSE_SD -DUSE_UART -DUSE_VGA -DUSE_TIMER"
UNDEF_SWITCHES="-UUSE_IDE -U__EMSCRIPTEN__"
if [ $OSTP = "LINUX" ]; then
    MORE_SWITCHES="-lpthread"
fi;
$COMPILER $FILES -O3 $DEF_SWITCHES $UNDEF_SWITCHES $MORE_SWITCHES $SDL2_CFLAGS $SDL2_LIBS -o qnice-vga
