#!/usr/bin/env bash

mkdir vbcc/bin
cd vasm
make SYNTAX=std CPU=qnice
cp vasmqnice_std ../vbcc/bin/
