/* $VER: vlink rel_elfjag.h V0.15a (22.01.15)
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


#ifndef REL_ELFJAG_H
#define REL_ELFJAG_H

#define R_JAG_NONE 0      /* No reloc */
#define R_JAG_ABS32 1     /* Direct 32 bit */
#define R_JAG_ABS16 2     /* Direct 16 bit */
#define R_JAG_ABS8 3      /* Direct 8 bit */
#define R_JAG_REL32 4     /* PC relative 32 bit */
#define R_JAG_REL16 5     /* PC relative 16 bit */
#define R_JAG_REL8 6      /* PC relative 8 bit */
#define R_JAG_ABS5 7      /* Direct 5 bit */
#define R_JAG_REL5 8      /* PC relative 5 bit */
#define R_JAG_JR 9        /* PC relative branch (distance / 2), 5 bit */
#define R_JAG_ABS32SWP 10 /* 32 bit direct, halfwords swapped as in MOVEI */
#define R_JAG_REL32SWP 11 /* 32 bit PC rel., halfwords swapped as in MOVEI */

#endif
