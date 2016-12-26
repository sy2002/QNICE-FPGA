/* $VER: vlink rel_elfalpha.h V0.3b (25.04.98)
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


#ifndef REL_ALPHA_H
#define REL_ALPHA_H

#define R_NONE                  0
#define R_ALPHA_REFLONG         1 /* Direct 32 bit */
#define R_ALPHA_REFQUAD         2 /* Direct 64 bit */
#define R_ALPHA_GPREL32         3 /* GP relative 32 bit */
#define R_ALPHA_LITERAL         4 /* GP relative 16 bit w/optimization */
#define R_ALPHA_LITUSE          5 /* Optimization hint for LITERAL */
#define R_ALPHA_GPDISP          6 /* Add displacement to GP */
#define R_ALPHA_BRADDR          7 /* PC+4 relative 23 bit shifted */
#define R_ALPHA_HINT            8 /* PC+4 relative 16 bit shifted */
#define R_ALPHA_SREL16          9 /* PC relative 16 bit */
#define R_ALPHA_SREL32         10 /* PC relative 32 bit */
#define R_ALPHA_SREL64         11 /* PC relative 64 bit */
#define R_ALPHA_OP_PUSH        12 /* OP stack push */
#define R_ALPHA_OP_STORE       13 /* OP stack pop and store */
#define R_ALPHA_OP_PSUB        14 /* OP stack subtract */
#define R_ALPHA_OP_PRSHIFT     15 /* OP stack right shift */
#define R_ALPHA_GPVALUE        16
#define R_ALPHA_GPRELHIGH      17
#define R_ALPHA_GPRELLOW       18
#define R_ALPHA_IMMED_GP_16    19
#define R_ALPHA_IMMED_GP_HI32  20
#define R_ALPHA_IMMED_SCN_HI32 21
#define R_ALPHA_IMMED_BR_HI32  22
#define R_ALPHA_IMMED_LO32     23
#define R_ALPHA_COPY           24 /* Copy symbol at runtime */
#define R_ALPHA_GLOB_DAT       25 /* Create GOT entry */
#define R_ALPHA_JMP_SLOT       26 /* Create PLT entry */
#define R_ALPHA_RELATIVE       27 /* Adjust by program base */

#endif
