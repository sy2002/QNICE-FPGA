/* $VER: vlink config.h V0.15a (22.01.15)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2015  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2015 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */

#ifndef CONFIG_H
#define CONFIG_H


/* Edit the following defines for your system: */

/* Default path to search for library. Example: "/usr/lib" */
#ifdef __VBCC__
#if defined(__MORPHOS__)
#define LIBPATH "vlibmos:"
#elif defined(__amigaos4__)
#define LIBPATH "vlibos4:"
#elif defined(__AROS__)
#define LIBPATH "vlibaros:"
#elif defined(AMIGAOS)
#define LIBPATH "vlibos3:"
#endif
#endif

/* Default target file format. Example: "elf32ppcbe" */
#if defined(__MORPHOS__)
#define DEFTARGET "elf32morphos"
#elif defined(__amigaos4__)
#define DEFTARGET "elf32ppcbe"
#elif defined(__AROS__)
#define DEFTARGET "elf32aros"
#elif defined(AMIGAOS)
#define DEFTARGET "amigahunk"
#elif defined(__MINT__)
#define DEFTARGET "aoutmint"
#elif defined(atarist)
#define DEFTARGET "ataritos"
#endif

/* Targets to be included */
#define ADOS                /* AmigaOS 68k hunk format */
#define EHF                 /* WarpOS PPC extended hunk format */
#define ATARI_TOS           /* Atari-ST TOS format */

#define ELF32               /* general 32-bit ELF support */
#define ELF32_PPC_BE        /* ELF PowerPC 32-Bit Big Endian */
#define ELF32_AMIGA         /* ELF PPC relocatable for MorphOS/PowerUp */
#define ELF32_M68K          /* ELF M68k 32-Bit Big Endian */
#define ELF32_386           /* ELF 386 32-Bit Little Endian */
#define ELF32_AROS          /* ELF 386 relocatable for AROS */
#define ELF32_ARM_LE        /* ELF ARM 32-Bit Little Endian */
#define ELF32_JAG           /* ELF Jaguar RISC 32-Bit Big Endian */

#define ELF64               /* general 64-bit ELF support */
#define ELF64_X86           /* ELF x86_64 64-Bit Little Endian */

#define AOUT                /* general a.out support */
#define AOUT_NULL           /* a.out stdandard relocs, undefined endianess */
#define AOUT_SUN010         /* a.out SunOS 68000/010 */
#define AOUT_SUN020         /* a.out SunOS 68020+ */
#define AOUT_BSDM68K        /* a.out NetBSD M68k (68020+) 8k Pages */
#define AOUT_BSDM68K4K      /* a.out NetBSD M68k (68020+) 4k Pages */
#define AOUT_MINT           /* a.out Atari MiNT 680x0, with TOS header */
#define AOUT_JAGUAR         /* a.out Atari Jaguar (M68k+RISC, write-only) */
#define AOUT_BSDI386        /* a.out NetBSD i386 (486,Pentium) 4k Pages */
#define AOUT_PC386          /* a.out PC i386 (GNU MS-DOS?) */

#define RAWBIN1             /* single raw binary file */
#define RAWBIN2             /* multiple raw binary files */
#define AMSDOS              /* Amstrad/Schneider CPC program */
#define CBMPRG              /* Commodore PET, VIC-20, 64, etc. program */
#define SREC19              /* Motorola S-Record 16-bit addresses */
#define SREC28              /* Motorola S-Record 24-bit addresses */
#define SREC37              /* Motorola S-Record 32-bit addresses */
#define IHEX                /* Intel Hex */
#define SHEX1               /* Customer specific hex format */
#define RAWSEG              /* multiple raw segment files */

#define VOBJ                /* vasm special object format */

/* dependencies */
#ifdef AOUT_MINT
#define ATARI_TOS           /* a.out-MiNT format needs TOS */
#endif

#endif /* CONFIG_H */
