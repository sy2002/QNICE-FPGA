#!/usr/bin/env bash

cd vbcc
mkdir bin
make TARGET=qnice
mkdir config
cp ../qnice/qnice-mon config
cp ../qnice/qnice-mon config/vc.config
