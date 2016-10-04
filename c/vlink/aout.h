/* $VER: vlink aout.h V0.13 (02.11.10)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2010  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2010 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */

#include "stabdefs.h"


#define TEXTNAME text_name
#define DATANAME data_name
#define BSSNAME  bss_name

#define MIN_ALIGNMENT 2  /* 32-bit align */


/* a.out header */
struct aout_hdr {
  uint8_t  a_midmag[4];
  uint8_t  a_text[4];
  uint8_t  a_data[4];
  uint8_t  a_bss[4];
  uint8_t  a_syms[4];
  uint8_t  a_entry[4];
  uint8_t  a_trsize[4];
  uint8_t  a_drsize[4];
};

/* a_magic */
#define OMAGIC 0407    /* old impure format */
#define NMAGIC 0410    /* read-only text */
#define ZMAGIC 0413    /* demand load format */
#define QMAGIC 0314    /* not supported */

/* a_mid - machine id */
#define MID_SUN010      1       /* sun 68010/68020 binary */
#define MID_SUN020      2       /* sun 68020-only binary */
#define MID_PC386       100     /* 386 PC binary. (so quoth BFD) */
#define MID_HP200       200     /* hp200 (68010) BSD binary */
#define MID_I386        134     /* i386 BSD binary */
#define MID_M68K        135     /* m68k BSD binary with 8K page sizes */
#define MID_M68K4K      136     /* m68k BSD binary with 4K page sizes */
#define MID_NS32532     137     /* ns32532 */
#define MID_SPARC       138     /* sparc */
#define MID_PMAX        139     /* pmax */
#define MID_VAX1K       140     /* vax 1K page size binaries */
#define MID_ALPHA       141     /* Alpha BSD binary */
#define MID_MIPS        142     /* big-endian MIPS */
#define MID_ARM6        143     /* ARM6 */
#define MID_SH3         145     /* SH3 */
#define MID_POWERPC     149     /* big-endian PowerPC */
#define MID_VAX         150     /* vax */
#define MID_SPARC64     151     /* LP64 sparc */
#define MID_HP300       300     /* hp300 (68020+68881) BSD binary */
#define MID_HPUX        0x20C   /* hp200/300 HP-UX binary */
#define MID_HPUX800     0x20B   /* hp800 HP-UX binary */

/* a_flags */
#define EX_DYNAMIC      0x20
#define EX_PIC          0x10
#define EX_DPMASK       0x30

/* a_midmag macros */
#define GETMAGIC(a) ((uint32_t)(read32be((a)->a_midmag)&0xffff))
#define GETMID(a)   ((uint32_t)((read32be((a)->a_midmag)>>16)&0x3ff))
#define GETFLAGS(a) ((uint32_t)((read32be((a)->a_midmag)>>26)&0x3f))
#define SETMIDMAG(a,mag,mid,flag) write32be((a)->a_midmag, \
                  ((flag)&0x3f)<<26|((mid)&0x3ff)<<16|((mag)&0xffff))


/* Relocation info structures */
struct relocation_info {
  int32_t r_address;
  uint32_t r_info;
};

#define RELB_symbolnum 0            /* ordinal number of add symbol */
#define RELS_symbolnum 24
#define RELB_reloc     24           /* the whole reloc field */
#define RELS_reloc     8

/* standard relocs: M68k, x86, ... */
#define RSTDB_pcrel     24          /* 1 if value should be pc-relative */
#define RSTDS_pcrel     1
#define RSTDB_length    25          /* log base 2 of value's width */
#define RSTDS_length    2
#define RSTDB_extern    27          /* 1 if need to add symbol to value */
#define RSTDS_extern    1
#define RSTDB_baserel   28          /* linkage table relative */
#define RSTDS_baserel   1
#define RSTDB_jmptable  29          /* relocate to jump table */
#define RSTDS_jmptable  1
#define RSTDB_relative  30          /* load address relative */
#define RSTDS_relative  1
#define RSTDB_copy      31          /* run time copy, or other meaning */
#define RSTDS_copy      1

/* FileFormat target family flags */
#define AOUT_JAGRELOC   0x01000000  /* copy = word-swapped GPU-RISC reloc */

/* Special Relocations */
#define R_AOUT_MOVEI    (LAST_STANDARD_RELOC+1)

#define SWAP16(x)       (((x)&0xffff) << 16) | (((x)&0xffff0000) >> 16)


/* vlink specific - used to generate a.out files */

#define STRHTABSIZE 0x10000

struct StrTabNode {
  struct node n;
  struct StrTabNode *hashchain;
  const char *str;
  uint32_t offset;
};

struct StrTabList {
  struct list l;
  struct StrTabNode **hashtab;
  uint32_t nextoffset;
};

struct SymbolNode {
  struct node n;
  struct SymbolNode *hashchain;
  const char *name;
  struct nlist32 s;
  uint32_t index;
};

struct SymTabList {
  struct list l;
  struct SymbolNode **hashtab;
  uint32_t nextindex;
};

struct RelocNode {
  struct node n;
  struct relocation_info r;
};

/* global variables */
extern struct SymTabList aoutsymlist;
extern struct StrTabList aoutstrlist;


/* t_aout.c prototypes */
int aout_identify(struct FFFuncs *,char *,struct aout_hdr *,unsigned long);
uint8_t aout_cmpsecflags(uint8_t,uint8_t);
int aout_targetlink(struct GlobalVars *,struct LinkedSection *,
                    struct Section *);
struct Symbol *aout_lnksym(struct GlobalVars *,struct Section *,
                           struct Reloc *);
void aout_setlnksym(struct GlobalVars *,struct Symbol *);

void aoutstd_readconv(struct GlobalVars *,struct LinkFile *);
void aoutstd_read(struct GlobalVars *,struct LinkFile *,struct aout_hdr *);
void aoutstd_relocs(struct GlobalVars *,struct ObjectUnit *,
                    struct aout_hdr *,int be,struct relocation_info *,
                    uint32_t,struct Section *,uint32_t);
unsigned long aout_headersize(struct GlobalVars *);
void aout_initwrite(struct GlobalVars *,struct LinkedSection **);
void aout_addsymlist(struct GlobalVars *,struct LinkedSection **,
                     uint8_t,uint8_t,int);
void aout_debugsyms(struct GlobalVars *,bool);
uint32_t aout_addrelocs(struct GlobalVars *,struct LinkedSection **,int,
                      struct list *,
                      uint32_t (*getrinfo)(struct GlobalVars *,struct Reloc *,
                                          bool,const char *,uint32_t),int);
void aout_calcrelocs(struct GlobalVars *,struct LinkedSection **,
                     int,int32_t (*)(struct GlobalVars *,char *,uint8_t,
                     int32_t,int32_t,int32_t));
void aout_header(FILE *,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,
                 uint32_t,uint32_t,uint32_t,uint32_t,int);
uint32_t aout_getpagedsize(struct GlobalVars *,struct LinkedSection **,int);
void aout_pagedsection(struct GlobalVars *,FILE *,struct LinkedSection **,int);
void aout_writesection(FILE *,struct LinkedSection *,uint8_t);
void aout_writerelocs(FILE *,struct list *);
void aout_writesymbols(FILE *);
void aout_writestrings(FILE *,int);
void aoutstd_writeobject(struct GlobalVars *,FILE *);
void aoutstd_writeshared(struct GlobalVars *,FILE *);
void aoutstd_writeexec(struct GlobalVars *,FILE *);
