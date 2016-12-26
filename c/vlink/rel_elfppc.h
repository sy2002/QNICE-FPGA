/* $VER: vlink rel_elfppc.h V0.9f (21.11.04)
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


#ifndef REL_ELFPPC_H
#define REL_ELFPPC_H

#define R_NONE                  0
#define R_PPC_ADDR32            1
#define R_PPC_ADDR24            2
#define R_PPC_ADDR16            3
#define R_PPC_ADDR16_LO         4
#define R_PPC_ADDR16_HI         5
#define R_PPC_ADDR16_HA         6
#define R_PPC_ADDR14            7
#define R_PPC_ADDR14_BRTAKEN    8
#define R_PPC_ADDR14_BRNTAKEN   9
#define R_PPC_REL24             10
#define R_PPC_REL14             11
#define R_PPC_REL14_BRTAKEN     12
#define R_PPC_REL14_BRNTAKEN    13
#define R_PPC_GOT16             14
#define R_PPC_GOT16_LO          15
#define R_PPC_GOT16_HI          16
#define R_PPC_GOT16_HA          17
#define R_PPC_PLTREL24          18
#define R_PPC_COPY              19
#define R_PPC_GLOB_DAT          20
#define R_PPC_JMP_SLOT          21
#define R_PPC_RELATIVE          22
#define R_PPC_LOCAL24PC         23
#define R_PPC_UADDR32           24
#define R_PPC_UADDR16           25
#define R_PPC_REL32             26
#define R_PPC_PLT32             27
#define R_PPC_PLTREL32          28
#define R_PPC_PLT16_LO          29
#define R_PPC_PLT16_HI          30
#define R_PPC_PLT16_HA          31
#define R_PPC_SDAREL16          32
#define R_PPC_SECTOFF           33
#define R_PPC_SECTOFF_LO        34
#define R_PPC_SECTOFF_HI        35
#define R_PPC_SECTOFF_HA        36
#define R_PPC_ADDR30            37
#define R_PPC_PASM_TOC16        63

/* EABI additions */
#define R_PPC_EMB_NADDR32       101
#define R_PPC_EMB_NADDR16       102
#define R_PPC_EMB_NADDR16_LO    103
#define R_PPC_EMB_NADDR16_HI    104
#define R_PPC_EMB_NADDR16_HA    105
#define R_PPC_EMB_SDAI16        106
#define R_PPC_EMB_SDA2I16       107
#define R_PPC_EMB_SDA2REL       108
#define R_PPC_EMB_SDA21         109
#define R_PPC_EMB_MRKREF        110
#define R_PPC_EMB_RELSEC16      111
#define R_PPC_EMB_RELST_LO      112
#define R_PPC_EMB_RELST_HI      113
#define R_PPC_EMB_RELST_HA      114
#define R_PPC_EMB_BIT_FLD       115
#define R_PPC_EMB_RELSDA        116

/* MorphOS additions */
#define R_PPC_MORPHOS_DREL      200
#define R_PPC_MORPHOS_DREL_LO   201
#define R_PPC_MORPHOS_DREL_HI   202
#define R_PPC_MORPHOS_DREL_HA   203

/* AmigaOS4 additions */
#define R_PPC_AMIGAOS_BREL      210
#define R_PPC_AMIGAOS_BREL_LO   211
#define R_PPC_AMIGAOS_BREL_HI   212
#define R_PPC_AMIGAOS_BREL_HA   213

#endif
