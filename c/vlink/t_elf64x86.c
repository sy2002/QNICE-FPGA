/* $VER: vlink t_elf64x86.c V0.14 (24.06.11)
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


#include "config.h"
#if defined(ELF64_X86)
#define T_ELF64X86_C
#include "vlink.h"
#include "elf64.h"
#include "rel_elfx86_64.h"


static int x86_64_identify(char *,uint8_t *,unsigned long,bool);
static void x86_64_readconv(struct GlobalVars *,struct LinkFile *);
static struct Symbol *x86_64_dynentry(struct GlobalVars *,DynArg,int);
static void x86_64_dyncreate(struct GlobalVars *);
static void x86_64_writeobject(struct GlobalVars *,FILE *);
static void x86_64_writeshared(struct GlobalVars *,FILE *);
static void x86_64_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf64x86 = {
  "elf64x86",
  NULL,
  NULL,
  elf64_headersize,
  x86_64_identify,
  x86_64_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf64_initdynlink,
  x86_64_dynentry,
  x86_64_dyncreate,
  x86_64_writeobject,
  x86_64_writeshared,
  x86_64_writeexec,
  bss_name,sbss_name,
  0x1000,
  0,  /* no small data support */
  0,
  0,
  RTAB_ADDEND,RTAB_STANDARD|RTAB_ADDEND,
  _LITTLE_ENDIAN_,
  32
};



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static int x86_64_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify ELF-x86_64-LittleEndian */
{
  return elf_identify(&fff_elf64x86,name,p,plen,
                      ELFCLASS64,ELFDATA2LSB,EM_X86_64,ELF_VER);
}


static uint8_t x86_64_reloc_elf2vlink(uint8_t rtype,struct RelocInsert *ri)
/* Determine vlink internal reloc type from ELF reloc type and fill in
   reloc-insert description informations.
   All fields of the RelocInsert structure are preset to zero. */
{
  /* Reloc conversion table for V.4-ABI */
  static struct ELF2vlink convertV4[] = {
    R_NONE,0,0,-1,
    R_ABS,0,64,-1,              /* R_X86_64_64 */
    R_PC,0,32,-1,               /* R_X86_64_PC32 */
    R_GOT,0,32,-1,              /* R_X86_64_GOT32 */
    R_PLT,0,32,-1,              /* R_X86_64_PLT32 */
    R_COPY,0,64,-1,             /* R_X86_64_COPY */
    R_GLOBDAT,0,64,-1,          /* R_X86_64_GLOB_DAT */
    R_JMPSLOT,0,0,-1,           /* R_X86_64_JUMP_SLOT */
    R_LOADREL,0,64,-1,          /* R_X86_64_RELATIVE */
    R_GOTPC,0,32,-1,            /* R_X86_64_GOTPCREL @@@ */
    R_ABS,0,32,-1,              /* R_X86_64_32 */
    R_ABS,0,32,-1,              /* R_X86_64_32S @@@ signed 32-bit? */
    R_ABS,0,16,-1,              /* R_X86_64_16 */
    R_PC,0,16,-1,               /* R_X86_64_PC16 */
    R_ABS,0,8,-1,               /* R_X86_64_8 */
    R_PC,0,8,-1                 /* R_X86_64_PC8 */
  };

  if (rtype <= R_X86_64_PC8) {
    ri->bpos = convertV4[rtype].bpos;
    ri->bsiz = convertV4[rtype].bsiz;
    ri->mask = convertV4[rtype].mask;
    rtype = convertV4[rtype].rtype;
  }
  else
    rtype = R_NONE;

  return rtype;
}


static void x86_64_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read ELF-x86_64 executable / object / shared obj. */
{
  if (lf->type == ID_LIBARCH) {
    struct ar_info ai;

    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        elf_check_ar_type(fff[lf->format],lf->pathname,ai.data,
                          ELFCLASS64,ELFDATA2LSB,ELF_VER,1,EM_X86_64);
        elf64_parse(gv,lf,(struct Elf64_Ehdr *)ai.data,x86_64_reloc_elf2vlink);
      }
    }
    else
      ierror("x86_64_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    elf64_parse(gv,lf,(struct Elf64_Ehdr *)lf->data,x86_64_reloc_elf2vlink);
  }
}


static struct Symbol *x86_64_dynentry(struct GlobalVars *gv,DynArg a,int etype)
/* Create an entry into .got/.plt/.bss for the referenced symbol. */
{
  struct Symbol *entry_sym = NULL;
  struct Section *sec;
  char *bssname;

  switch (etype) {

    case GOT_ENTRY:
    case GOT_LOCAL:
      /* @@@ .got has ?? bytes reserved at the beginning,
         is writable, a new entry occupies ? bytes. */
      ierror("x86_64_dynentry(): GOT_ENTRY not yet written");
      sec = elf_dyntable(gv,12,12,ST_DATA,SF_ALLOC,SP_READ|SP_WRITE,GOT_ENTRY);
      entry_sym = elf64_pltgotentry(gv,sec,a,SYMI_OBJECT,4,4,etype);
      break;

    case PLT_ENTRY:
      /* .got.plt has ?? bytes reserved at the beginning, is executable,
         a new entry occupies another ?? bytes. */
      ierror("x86_64_dynentry(): PLT_ENTRY not yet written");
      sec = elf_dyntable(gv,16,16,ST_CODE,SF_ALLOC,SP_READ|SP_EXEC,PLT_ENTRY);
      entry_sym = elf64_pltgotentry(gv,sec,a,SYMI_FUNC,16,16,PLT_ENTRY);
      break;

    case BSS_ENTRY:
      /* @@@ */
      ierror("x86_64_dynentry(): BSS_ENTRY not yet written");
      break;

    default:
      ierror("x86_64_dynentry(): illegal entrytype: %d",etype);
      break;
  }

  return entry_sym;
}


static void x86_64_dyncreate(struct GlobalVars *gv)
{
  elf64_dyncreate(gv,got_name);
}



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


static uint8_t x86_64_reloc_vlink2elf(struct Reloc *r)
/* Try to map vlink-internal representation to a valid ELF reloc type */
{
  if (isstdreloc(r,R_ABS,8)) return R_X86_64_8;
  else if (isstdreloc(r,R_ABS,16)) return R_X86_64_16;
  else if (isstdreloc(r,R_ABS,32)) return R_X86_64_32;
  else if (isstdreloc(r,R_ABS,64)) return R_X86_64_64;
  else if (isstdreloc(r,R_PC,8)) return R_X86_64_PC8;
  else if (isstdreloc(r,R_PC,16)) return R_X86_64_PC16;
  else if (isstdreloc(r,R_PC,32)) return R_X86_64_PC32;
  else if (isstdreloc(r,R_GOT,32)) return R_X86_64_GOT32;
  else if (isstdreloc(r,R_GOTPC,32)) return R_X86_64_GOTPCREL; /* @@@ */
  else if (isstdreloc(r,R_PLT,32)) return R_X86_64_PLT32;
  else if (r->rtype == R_COPY) return R_X86_64_COPY;
  else if (r->rtype == R_GLOBDAT) return R_X86_64_GLOB_DAT;
  else if (r->rtype == R_JMPSLOT) return R_X86_64_JUMP_SLOT;
  else if (r->rtype == R_LOADREL) return R_X86_64_RELATIVE;

  return R_NONE;
}


static void x86_64_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 shared object (which is pos. independant) */
{
  ierror("x86_64_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void x86_64_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 relocatable object file */
{
  elf64_writeobject(gv,f,EM_X86_64,_LITTLE_ENDIAN_,x86_64_reloc_vlink2elf);
}


static void x86_64_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 executable file (with absolute addresses) */
{
  elf64_writeexec(gv,f,EM_X86_64,_LITTLE_ENDIAN_,x86_64_reloc_vlink2elf);
}

#endif /* ELF64_X86 */
