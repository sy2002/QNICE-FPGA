#!/bin/bash

../assembler/asm monitor.asm
cp monitor.def ../dist_kit
cp sysdef.asm ../dist_kit
perl sysdef2header.pl sysdef.asm ../dist_kit/sysdef.h
