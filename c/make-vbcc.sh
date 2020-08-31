#!/usr/bin/env bash

cp qnice/compiler-backend/ vbcc/machines/qnice/
cd vbcc
mkdir bin
make TARGET=qnice
mkdir config
cp ../qnice/qnice-mon config
cp ../qnice/qnice-mon config/vc.config
