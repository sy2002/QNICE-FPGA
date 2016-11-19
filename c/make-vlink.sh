#!/usr/bin/env bash

mkdir vbcc/bin
mkdir vlink/objects
cd vlink
make
cp vlink ../vbcc/bin/
