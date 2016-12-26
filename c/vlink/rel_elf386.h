/* $VER: vlink rel_elf386.h V0.9c (08.05.04)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2005  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2005 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#ifndef REL_ELF386_H
#define REL_ELF386_H

#define R_386_NONE        0
#define R_386_32          1
#define R_386_PC32        2
#define R_386_GOT32       3
#define R_386_PLT32       4
#define R_386_COPY        5
#define R_386_GLOB_DAT    6
#define R_386_JMP_SLOT    7
#define R_386_RELATIVE    8
#define R_386_GOTOFF      9
#define R_386_GOTPC       10

#endif
