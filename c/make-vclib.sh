#!/usr/bin/env bash

rm -r vclib/build/
mkdir vclib/build
rm -r vclib/include
mkdir vclib/include
rm -r vclib/machines/qnice/
rm -r vclib/targets/qnice-mon/
cp -r qnice/vclib/include vclib
cp -r qnice/vclib/machines/qnice vclib/machines
cp -r qnice/vclib/targets/qnice-mon vclib/targets
cd vclib
make CPU=qnice ABI=mon
cd ..
rm vbcc/targets/qnice-mon/lib/startup.o
rm vbcc/targets/qnice-mon/lib/libvc.a
cp vclib/build/qnice-mon/startup.o vbcc/targets/qnice-mon/lib
cp vclib/build/qnice-mon/libvc.a vbcc/targets/qnice-mon/lib
rm -r vbcc/targets/qnice-mon/include/
cp -r vclib/build/qnice-mon/include vbcc/targets/qnice-mon
