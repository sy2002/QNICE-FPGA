#!/bin/bash
cat boot_message.txt > boot_message.asm
git rev-parse --short HEAD | tr -d '\n' >> boot_message.asm 
echo ')\n"' >> boot_message.asm
../assembler/asm pore.asm
