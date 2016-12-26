/* $VER: vlink elf64.h V0.14 (24.06.11)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2011  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2011 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#include "elfcommon.h"
#include "elf64std.h"


struct ShdrNode {
  struct node n;
  struct Elf64_Shdr s;
};


#if 0
/* .stab compilation units */
struct StabCompUnit {
  struct node n;
  long nameidx;
  unsigned long entries;
  struct list stabs;
  struct StrTabList strtab;
};
#endif


/* Prototypes from t_elf64.c */

void elf64_parse(struct GlobalVars *,struct LinkFile *,struct Elf64_Ehdr *,
                 uint8_t (*)(uint8_t,struct RelocInsert *));
void elf64_initdynlink(struct GlobalVars *);
struct Section *elf64_dyntable(struct GlobalVars *,unsigned long,unsigned long,
                               uint8_t,uint8_t,uint8_t,int);
struct Symbol *elf64_pltgotentry(struct GlobalVars *,struct Section *,DynArg,
                                 uint8_t,unsigned long,unsigned long,int);
struct Symbol *elf64_bssentry(struct GlobalVars *,const char *,struct Symbol *);
void elf64_dynamicentry(struct GlobalVars *,uint64_t,uint64_t,struct Section *);
void elf64_dyncreate(struct GlobalVars *,const char *);
unsigned long elf64_headersize(struct GlobalVars *);
void elf64_writerelocs(struct GlobalVars *,FILE *);
void elf64_writeobject(struct GlobalVars *,FILE *,uint16_t,int8_t,
                       uint8_t (*)(struct Reloc *));
void elf64_writeexec(struct GlobalVars *,FILE *,uint16_t,int8_t,
                     uint8_t (*)(struct Reloc *));
