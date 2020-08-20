#!/usr/bin/env bash

# setup C compiler environment
export PATH=$PATH:$PWD/../c/vbcc/bin:$PWD/../c/qnice
export VBCC=$PWD/../c/vbcc
export DIST_KIT=$PWD/../dist_kit
C_FLAGS="-c99 -O1"
C_DEMOS=../c/test_programs

# build C demos and move them here
echo "building:   adventure.c"
qvc  $C_DEMOS/adventure.c $C_FLAGS
mv   $C_DEMOS/adventure.out .
echo "building:   hdmi_de.c"
qvc  $C_DEMOS/hdmi_de.c $C_FLAGS
mv   $C_DEMOS/hdmi_de.out .
echo "building:   shell.c"
qvc  $C_DEMOS/shell.c $C_FLAGS
mv   $C_DEMOS/shell.out .
echo "building:   sierpinski.c"
qvc  $C_DEMOS/sierpinski.c $C_FLAGS
mv   $C_DEMOS/sierpinski.out .
echo "building:   ttt2.c"
qvc  $C_DEMOS/ttt2.c $C_FLAGS
mv   $C_DEMOS/ttt2.out .
echo "building:   vga_calibration.c"
qvc  $C_DEMOS/vga_calibration.c $C_FLAGS
mv   $C_DEMOS/vga_calibration.out .
echo "building:   wolfram.c"
qvc  $C_DEMOS/wolfram.c $C_FLAGS
mv   $C_DEMOS/wolfram.out .
rm mapfile

# setup assembler environment
ASM=../assembler/asm
ASM_TEST=../test_programs
ASM_DEMOS=../demos
export QNICE_ASM_NO_ROM=1 #do not create .rom files

# build assembler demos and move them here
echo "assembling: mandel.asm"
$ASM $ASM_DEMOS/mandel.asm
mv   $ASM_DEMOS/mandel.out .
echo "assembling: mandel_zoom.asm"
$ASM $ASM_DEMOS/mandel_zoom.asm
mv   $ASM_DEMOS/mandel_zoom.out .
echo "assembling: q-tris.asm"
$ASM $ASM_DEMOS/q-tris.asm
mv   $ASM_DEMOS/q-tris.out .
echo "assembling: qtransfer.asm"
$ASM ../tools/qtransfer.asm
mv   ../tools/qtransfer.out .
echo "assembling: simple_timer_test.asm"
$ASM $ASM_TEST/simple_timer_test.asm
mv   $ASM_TEST/simple_timer_test.out .
echo "assembling: sdcard.asm"
$ASM $ASM_TEST/sdcard.asm
mv   $ASM_TEST/sdcard.out .
echo "assembling: tile_ed.asm"
$ASM $ASM_DEMOS/tile_ed.asm
mv   $ASM_DEMOS/tile_ed.out .
echo "assembling: timer_test.asm"
$ASM $ASM_TEST/timer_test.asm
mv   $ASM_TEST/timer_test.out .

# .out files are excluded by .gitignore so let's add them
git add -f adventure.out
git add -f hdmi_de.out
git add -f shell.out
git add -f sierpinski.out
git add -f ttt2.out
git add -f vga_calibration.out
git add -f wolfram.out
git add -f mandel.out
git add -f mandel_zoom.out
git add -f q-tris.out
git add -f qtransfer.out
git add -f simple_timer_test.out
git add -f sdcard.out
git add -f tile_ed.out
git add -f timer_test.out  
