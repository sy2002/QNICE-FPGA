/* $VER: vlink t_elf32m68k.c V0.13 (02.11.10)
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


#include "config.h"
#if defined(ELF32_M68K)
#define T_ELF32M68K_C
#include "vlink.h"
#include "elf32.h"
#include "rel_elfm68k.h"


static int m68k_identify(char *,uint8_t *,unsigned long,bool);
static void m68k_readconv(struct GlobalVars *,struct LinkFile *);
static struct Symbol *m68k_dynentry(struct GlobalVars *,DynArg,int);
static void m68k_dyncreate(struct GlobalVars *);
static void m68k_writeobject(struct GlobalVars *,FILE *);
static void m68k_writeshared(struct GlobalVars *,FILE *);
static void m68k_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32m68k = {
  "elf32m68k",
  NULL,
  NULL,
  elf32_headersize,
  m68k_identify,
  m68k_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf32_initdynlink,
  m68k_dynentry,
  m68k_dyncreate,
  m68k_writeobject,
  m68k_writeshared,
  m68k_writeexec,
  bss_name,sbss_name,
  0x2000,
  0x8000,
  0,
  0,
  RTAB_ADDEND,RTAB_STANDARD|RTAB_ADDEND,
  _BIG_ENDIAN_,
  32
};



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static int m68k_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify ELF-M68k-32Bit-BigEndian */
{
  return (elf_identify(&fff_elf32m68k,name,p,plen,
                       ELFCLASS32,ELFDATA2MSB,EM_68K,ELF_VER));
}


static uint8_t m68k_reloc_elf2vlink(uint8_t rtype,struct RelocInsert *ri)
/* Determine vlink internal reloc type from ELF reloc type and fill in
   reloc-insert description informations.
   All fields of the RelocInsert structure are preset to zero. */
{
  static struct ELF2vlink convertV4[] = {
    R_NONE,0,0,-1,
    R_ABS,0,32,-1,              /* R_68K_32 */
    R_ABS,0,16,-1,              /* R_68K_16 */
    R_ABS,0,8,-1,               /* R_68K_8 */
    R_PC,0,32,-1,               /* R_68K_PC32 */
    R_PC,0,16,-1,               /* R_68K_PC16 */
    R_PC,0,8,-1,                /* R_68K_PC8 */
    R_GOT,0,32,-1,              /* R_68K_GOT32 */
    R_GOT,0,16,-1,              /* R_68K_GOT16 */
    R_GOT,0,8,-1,               /* R_68K_GOT8 */
    R_GOTOFF,0,32,-1,           /* R_68K_GOT32O */
    R_GOTOFF,0,16,-1,           /* R_68K_GOT16O */
    R_GOTOFF,0,8,-1,            /* R_68K_GOT8O */
    R_PLT,0,32,-1,              /* R_68K_PLT32 */
    R_PLT,0,16,-1,              /* R_68K_PLT16 */
    R_PLT,0,8,-1,               /* R_68K_PLT8 */
    R_PLTOFF,0,32,-1,           /* R_68K_PLT32O */
    R_PLTOFF,0,16,-1,           /* R_68K_PLT16O */
    R_PLTOFF,0,8,-1,            /* R_68K_PLT8O */
    R_COPY,0,32,-1,             /* R_68K_COPY */
    R_GLOBDAT,0,32,-1,          /* R_68K_GLOB_DAT */
    R_JMPSLOT,0,0,-1,           /* R_68K_JMP_SLOT */
    R_LOADREL,0,32,-1           /* R_68K_RELATIVE */
  };

  if (rtype <= R_68K_RELATIVE) {
    ri->bpos = convertV4[rtype].bpos;
    ri->bsiz = convertV4[rtype].bsiz;
    ri->mask = convertV4[rtype].mask;
    rtype = convertV4[rtype].rtype;
  }
  else
    rtype = R_NONE;

  return (rtype);
}


static void m68k_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read ELF-68k executable / object / shared obj. */
{
  if (lf->type == ID_LIBARCH) {
    struct ar_info ai;

    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        elf_check_ar_type(fff[lf->format],lf->pathname,ai.data,
                          ELFCLASS32,ELFDATA2MSB,ELF_VER,1,EM_68K);
        elf32_parse(gv,lf,(struct Elf32_Ehdr *)ai.data,m68k_reloc_elf2vlink);
      }
    }
    else
      ierror("m68k_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    elf32_parse(gv,lf,(struct Elf32_Ehdr *)lf->data,m68k_reloc_elf2vlink);
  }
}


static struct Symbol *m68k_dynentry(struct GlobalVars *gv,DynArg a,int etype)
{
  ierror("m68k_dynentry(): needs to be written");
  return NULL;
}


static void m68k_dyncreate(struct GlobalVars *gv)
{
  elf32_dyncreate(gv,plt_name);
}



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


static uint8_t m68k_reloc_vlink2elf(struct Reloc *r)
/* Try to map vlink-internal representation to a valid ELF reloc type */
{
  if (isstdreloc(r,R_ABS,32)) return R_68K_32;
  else if (isstdreloc(r,R_ABS,16)) return R_68K_16;
  else if (isstdreloc(r,R_ABS,8)) return R_68K_8;
  else if (isstdreloc(r,R_PC,32)) return R_68K_PC32;
  else if (isstdreloc(r,R_PC,16)) return R_68K_PC16;
  else if (isstdreloc(r,R_PC,8)) return R_68K_PC8;
  else if (isstdreloc(r,R_GOT,32)) return R_68K_GOT32;
  else if (isstdreloc(r,R_GOT,16)) return R_68K_GOT16;
  else if (isstdreloc(r,R_GOT,8)) return R_68K_GOT8;
  else if (isstdreloc(r,R_GOTOFF,32)) return R_68K_GOT32O;
  else if (isstdreloc(r,R_GOTOFF,16)) return R_68K_GOT16O;
  else if (isstdreloc(r,R_GOTOFF,8)) return R_68K_GOT8O;
  else if (isstdreloc(r,R_PLT,32)) return R_68K_PLT32;
  else if (isstdreloc(r,R_PLT,16)) return R_68K_PLT16;
  else if (isstdreloc(r,R_PLT,8)) return R_68K_PLT8;
  else if (isstdreloc(r,R_PLTOFF,32)) return R_68K_PLT32O;
  else if (isstdreloc(r,R_PLTOFF,16)) return R_68K_PLT16O;
  else if (isstdreloc(r,R_PLTOFF,8)) return R_68K_PLT8O;
  else if (r->rtype == R_COPY) return R_68K_COPY;
  else if (r->rtype == R_GLOBDAT) return R_68K_GLOB_DAT;
  else if (r->rtype == R_JMPSLOT) return R_68K_JMP_SLOT;
  else if (r->rtype == R_LOADREL) return R_68K_RELATIVE;

  return R_NONE;
}


static void m68k_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32m68k shared object (which is pos. independant) */
{
  ierror("m68k_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void m68k_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32m68k relocatable object file */
{
  elf32_writeobject(gv,f,EM_68K,_BIG_ENDIAN_,m68k_reloc_vlink2elf);
}


static void m68k_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32m68k executable file (with absolute addresses) */
{
  elf32_writeexec(gv,f,EM_68K,_BIG_ENDIAN_,m68k_reloc_vlink2elf);
}


#endif /* ELF32_M68K */
