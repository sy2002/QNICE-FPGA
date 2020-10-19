#!/bin/bash

if [[ ! -f qnice.js ]] || [[ ! -f qnice.wasm ]] || [[ ! -f qnice.html ]] || [[ ! -f qnice.data ]]; then
    echo "Build the QNICE Emulator with VGA and PS/2 (USB) keyboard support"
    echo "for the WebAssembly/WebGL target using the Emscripten toolchain"
    echo ""
    echo "Some hints:"
    echo "* Emscripten is a dependency: https://emscripten.org/"
    echo "* The Emscripten environment needs to be active: source emsdk_env.sh"
    echo "* You need to have SDL2 installed for compiling."
    echo "* A FAT32 SD Card image named qnice_disk.img needs to be present"
    echo "  (read ../doc/emumount.txt to learn how to create one)"
    echo "* The monitor needs to be present at ../monitor/monitor.out"
    echo "* The resulting executables are qnice.wasm, qnice.js and qnice.html"
    echo "  and qnice.data contains the Monitor (operating system)"
    echo "* If you want to create an embeddable release version of qnice.html"
    echo "  then run this script having RELEASE as parameter: ./make-wasm.bash RELEASE"
    echo "* If you are developing the release version, then use the parameter DEVELOP-RELEASE"
    echo "* Use for example Python's minimal webserver to serve the executables:"
    echo "  python -m SimpleHTTPServer 8080"
    echo ""
    read -p "Press ENTER to continue or CTRL+C to quit."
fi

command -v emcc >/dev/null 2>&1 || { 
    echo >&2 ""
    echo >&2 "emcc from Emscripten toolchain not found."
    echo >&2 "Activate it with: source <path-to-emsdk>/emsdk_env.sh"
    echo ""
    exit 1
}

EMCC_VERSION=`emcc --version|grep emcc|egrep -o "([0-9]{1,}\.)+[0-9]{1,}"`
if [[ $EMCC_VERSION = "1.39.11" ]] || [[ $EMCC_VERSION = "1.39.12" ]] || [[ $EMCC_VERSION = "1.39.13" ]]; then
    echo "Error: This Emscripten SDK version will not work. Please upgrade."
    echo "(see also https://github.com/emscripten-core/emscripten/issues/10746)"
    echo ""
    exit 1
fi

if [[ ! -f qnice_disk_v16.img ]]; then
    echo "Warning: qnice_disk_v16.img not found. You can still compile the emulator."
fi

FILES="qnice.c fifo.c sd.c vga.c linenoise.c"
DEF_SWITCHES="-DUSE_SD -DUSE_VGA -DUSE_SYSINFO"
UNDEF_SWITCHES="-UUSE_IDE -UUSE_UART -UUSE_TIMER"
PRELOAD_FILES="--preload-file monitor.out"

if [ "$1" == "DEVELOP-RELEASE" ]; then
    SHELL_FILE="--shell-file wasm-shell.html"
fi

if [ "$1" == "RELEASE" ]; then
    SHELL_FILE="--shell-file wasm-shell-release.html"
fi

cp ../monitor/monitor.out .
emcc $FILES -O3 -s ASYNCIFY -s ASYNCIFY_IGNORE_INDIRECT -s USE_SDL=2 $SHELL_FILE $DEF_SWITCHES $UNDEF_SWITCHES $PRELOAD_FILES -o qnice.html
rm monitor.out
