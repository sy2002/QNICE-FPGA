#!/bin/bash

if [[ ! -f qnice.js ]] || [[ ! -f qnice.wasm ]] || [[ ! -f qnice.html ]]; then
    echo "Build the QNICE Emulator with VGA and PS/2 (USB) keyboard support"
    echo "for the WebAssembly/WebGL target using the Emscripten toolchain"
    echo ""
    echo "Some hints:"
    echo "* Emscripten is a dependency: https://emscripten.org/"
    echo "* You need to have SDL2 installed for compiling."
    echo "* The Emscripten environment needs to be active: source emsdk_env.sh"
    echo "* A FAT32 SD Card image named qnice_disk.img needs to be present"
    echo "  (read ../doc/emumount.txt to learn how to create one)"
    echo "* The monitor needs to be present at ../monitor/monitor.out"
    echo "* The resulting executables are qnice.wasm, qnice.js and qnice.html"
    echo "* Use for example Python's minimal webserver to serve the executables:"
    echo "  python -m SimpleHTTPServer 8000"
    echo ""
    read -p "Press ENTER to continue or CTRL+C to quit."
fi

FILES="qnice.c fifo.c sd.c vga.c"
DEF_SWITCHES="-DUSE_SD -DUSE_VGA"
UNDEF_SWITCHES="-UUSE_IDE -UUSE_UART"
PRELOAD_FILES="--preload-file monitor.out"

cp ../monitor/monitor.out .
emcc $FILES -O3 -s ASYNCIFY -s ASYNCIFY_IGNORE_INDIRECT -s USE_SDL=2 $DEF_SWITCHES $UNDEF_SWITCHES $PRELOAD_FILES -o qnice.html
rm monitor.out
