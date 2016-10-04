/* $VER: vlink rel_elfm68k.h V0.9 (30.09.03)
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


#ifndef REL_ELFM68K_H
#define REL_ELFM68K_H

#define R_68K_NONE 0      /* No reloc */
#define R_68K_32 1        /* Direct 32 bit  */
#define R_68K_16 2        /* Direct 16 bit  */
#define R_68K_8 3         /* Direct 8 bit  */
#define R_68K_PC32 4      /* PC relative 32 bit */
#define R_68K_PC16 5      /* PC relative 16 bit */
#define R_68K_PC8 6       /* PC relative 8 bit */
#define R_68K_GOT32 7     /* 32 bit PC relative GOT entry */
#define R_68K_GOT16 8     /* 16 bit PC relative GOT entry */
#define R_68K_GOT8 9      /* 8 bit PC relative GOT entry */
#define R_68K_GOT32O 10   /* 32 bit GOT offset */
#define R_68K_GOT16O 11   /* 16 bit GOT offset */
#define R_68K_GOT8O 12    /* 8 bit GOT offset */
#define R_68K_PLT32 13    /* 32 bit PC relative PLT address */
#define R_68K_PLT16 14    /* 16 bit PC relative PLT address */
#define R_68K_PLT8 15     /* 8 bit PC relative PLT address */
#define R_68K_PLT32O 16   /* 32 bit PLT offset */
#define R_68K_PLT16O 17   /* 16 bit PLT offset */
#define R_68K_PLT8O 18    /* 8 bit PLT offset */
#define R_68K_COPY 19     /* Copy symbol at runtime */
#define R_68K_GLOB_DAT 20 /* Create GOT entry */
#define R_68K_JMP_SLOT 21 /* Create PLT entry */
#define R_68K_RELATIVE 22 /* Adjust by program base */      

#endif
