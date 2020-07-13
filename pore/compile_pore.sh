#!/bin/bash
cat boot_message.txt > boot_message.asm
git rev-parse --short HEAD | tr -d '\n' >> boot_message.asm 
echo ')\n"' >> boot_message.asm
echo -n "Standard PORE: "
../assembler/asm pore.asm

cat boot_message_mega65.txt > boot_message_mega65.asm
git rev-parse --short HEAD | tr -d '\n' >> boot_message_mega65.asm 
echo ')\n"' >> boot_message_mega65.asm
echo -n "MEGA65 PORE:   "
../assembler/asm pore_mega65.asm
