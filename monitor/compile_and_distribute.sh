#!/bin/bash

../assembler/asm monitor.asm
cp monitor.def ../dist_kit
cp sysdef.asm ../dist_kit
perl sysdef2header.pl sysdef.asm ../dist_kit/sysdef.h
perl sysdef2header.pl -p QMON_EP_ monitor.def ../dist_kit/qmon-ep.h
perl sysdef2header.pl -vasm sysdef.asm ../dist_kit/sysdef.vasm
perl sysdef2header.pl -vasm monitor.def ../dist_kit/monitor.vdef
cp ../dist_kit/sysdef.h ../c/qnice/compiler-backend/
