#!/usr/bin/env bash

cd vasm
make SYNTAX=std CPU=qnice
cp vasmqnice_std ../vbcc/bin
