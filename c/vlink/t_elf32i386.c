/* $VER: vlink t_elf32i386.c V0.15a (28.02.15)
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


#include "config.h"
#if defined(ELF32_386) || defined(ELF32_AROS)
#define T_ELF32I386_C
#include "vlink.h"
#include "elf32.h"
#include "rel_elf386.h"


static int i386_identify(char *,uint8_t *,unsigned long,bool);
static void i386_readconv(struct GlobalVars *,struct LinkFile *);


#ifdef ELF32_386
static struct Symbol *i386_dynentry(struct GlobalVars *,DynArg,int);
static void i386_dyncreate(struct GlobalVars *);
static void i386_writeobject(struct GlobalVars *,FILE *);
static void i386_writeshared(struct GlobalVars *,FILE *);
static void i386_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32i386 = {
  "elf32i386",
  NULL,
  NULL,
  elf32_headersize,
  i386_identify,
  i386_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf32_initdynlink,
  i386_dynentry,
  i386_dyncreate,
  i386_writeobject,
  i386_writeshared,
  i386_writeexec,
  bss_name,sbss_name,
  0x1000,
  0,  /* no small data support */
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD|RTAB_ADDEND,
  _LITTLE_ENDIAN_,
  32
};
#endif  /* ELF32_386 */


#ifdef ELF32_AROS
static int aros_targetlink(struct GlobalVars *,struct LinkedSection *,
                           struct Section *);
static struct Symbol *aros_lnksym(struct GlobalVars *,struct Section *,
                                  struct Reloc *);
static void aros_setlnksym(struct GlobalVars *,struct Symbol *);
static void aros_writeobject(struct GlobalVars *,FILE *);
static void aros_writeshared(struct GlobalVars *,FILE *);
static void aros_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32aros = {
  "elf32aros",
  NULL,
  NULL,
  elf32_headersize,
  i386_identify,
  i386_readconv,
  NULL,
  aros_targetlink,
  NULL,
  aros_lnksym,
  aros_setlnksym,
  NULL,NULL,NULL,
  aros_writeobject,
  aros_writeshared,
  aros_writeexec,
  bss_name,sbss_name,
  0x1000,
  0,  /* no small data support */
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD|RTAB_ADDEND,
  _LITTLE_ENDIAN_,
  32
};


/* elf32aros linker symbols */
static char linkerdb[] = "_LinkerDB";
#define LINKERDB        0   /* _LinkerDB */

#endif  /* ELF32_AROS */



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static int i386_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify ELF-386-32Bit-LittleEndian */
{
  return elf_identify(&fff_elf32i386,name,p,plen,
                       ELFCLASS32,ELFDATA2LSB,EM_386,ELF_VER);
}


static uint8_t i386_reloc_elf2vlink(uint8_t rtype,struct RelocInsert *ri)
/* Determine vlink internal reloc type from ELF reloc type and fill in
   reloc-insert description informations.
   All fields of the RelocInsert structure are preset to zero. */
{
  /* Reloc conversion table for V.4-ABI */
  static struct ELF2vlink convertV4[] = {
    R_NONE,0,0,-1,
    R_ABS,0,32,-1,              /* R_386_32 */
    R_PC,0,32,-1,               /* R_386_PC32 */
    R_GOT,0,32,-1,              /* R_386_GOT32 */
    R_PLT,0,32,-1,              /* R_386_PLT32 */
    R_COPY,0,32,-1,             /* R_386_COPY */
    R_GLOBDAT,0,32,-1,          /* R_386_GLOB_DAT */
    R_JMPSLOT,0,0,-1,           /* R_386_JMP_SLOT */
    R_LOADREL,0,32,-1,          /* R_386_RELATIVE */
    R_GOTOFF,0,32,-1,           /* R_386_GOTOFF */
    R_GOTPC,0,32,-1             /* R_386_GOTPC */
  };

  if (rtype <= R_386_GOTPC) {
    ri->bpos = convertV4[rtype].bpos;
    ri->bsiz = convertV4[rtype].bsiz;
    ri->mask = convertV4[rtype].mask;
    rtype = convertV4[rtype].rtype;
  }
  else
    rtype = R_NONE;

  return rtype;
}


static void i386_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read ELF-386 executable / object / shared obj. */
{
  if (lf->type == ID_LIBARCH) {
    struct ar_info ai;

    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        elf_check_ar_type(fff[lf->format],lf->pathname,ai.data,
                          ELFCLASS32,ELFDATA2LSB,ELF_VER,1,EM_386);
        elf32_parse(gv,lf,(struct Elf32_Ehdr *)ai.data,i386_reloc_elf2vlink);
      }
    }
    else
      ierror("i386_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    elf32_parse(gv,lf,(struct Elf32_Ehdr *)lf->data,i386_reloc_elf2vlink);
  }
}


static struct Symbol *i386_dynentry(struct GlobalVars *gv,DynArg a,int etype)
/* Create an entry into .got/.plt/.bss for the referenced symbol. */
{
  struct Symbol *entry_sym = NULL;
  struct Section *sec;
  char *bssname;

  switch (etype) {

    case GOT_ENTRY:
    case GOT_LOCAL:
      /* .got has 12 bytes reserved at the beginning,
         is writable, a new entry occupies 4 bytes. */
      sec = elf_dyntable(gv,12,12,ST_DATA,SF_ALLOC,SP_READ|SP_WRITE,GOT_ENTRY);
      entry_sym = elf32_pltgotentry(gv,sec,a,SYMI_OBJECT,4,4,etype);
      break;

    case PLT_ENTRY:
      /* .plt has 16 bytes reserved at the beginning, is executable,
         a new entry occupies another 16 bytes. */
      sec = elf_dyntable(gv,16,16,ST_CODE,SF_ALLOC,SP_READ|SP_EXEC,PLT_ENTRY);
      entry_sym = elf32_pltgotentry(gv,sec,a,SYMI_FUNC,16,16,PLT_ENTRY);
      break;

    case BSS_ENTRY:
      /* @@@ */
      ierror("i386_dynentry(): BSS_ENTRY not yet written");
      break;

    default:
      ierror("i386_dynentry(): illegal entrytype: %d",etype);
      break;
  }

  return entry_sym;
}


static void i386_dyncreate(struct GlobalVars *gv)
{
  elf32_dyncreate(gv,got_name);
}


#ifdef ELF32_AROS

static int aros_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                           struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  if (!gv->use_ldscript) {
    if ((!strncmp(ls->name,sdata_name,6) && !strncmp(s->name,sbss_name,5)
         && *(ls->name+6) == *(s->name+5)) ||
        (!strncmp(ls->name,sbss_name,5) && !strncmp(s->name,sdata_name,6)
         && *(ls->name+5) == *(s->name+6)))
      /* .sdata/.sbss, .sdata2/.sbss2, etc. are always combined */
      return 1;
  }
  return 0;
}


static struct Symbol *aros_lnksym(struct GlobalVars *gv,struct Section *sec,
                                  struct Reloc *xref)
{
  struct Symbol *sym;

  if (!gv->dest_object && !gv->use_ldscript) {
    if (!strcmp(linkerdb,xref->xrefname)) {  /* _LinkerDB */
      sym = addlnksymbol(gv,linkerdb,(lword)fff[gv->dest_format]->baseoff,
                         SYM_RELOC,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|LINKERDB;
      if (findlnksymbol(gv,sdabase_name) == NULL) {
        /* Reference to _LinkerDB creates _SDA_BASE_ */
        struct Symbol *sdabase = addlnksymbol(gv,sdabase_name,
                                              (lword)fff[gv->dest_format]->baseoff,
                                              SYM_ABS,SYMF_LNKSYM,
                                              SYMI_OBJECT,SYMB_GLOBAL,0);
        sdabase->type = SYM_RELOC;
        sdabase->extra = SDABASE;
      }
      return sym;  /* new linker symbol created */
    }
  }

  return elf_lnksym(gv,sec,xref);
}


static void aros_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
{
  if ((xdef->flags & SYMF_LNKSYM) && (xdef->extra & SYMX_SPECIAL)) {
    struct LinkedSection *ls;

    switch (xdef->extra & ~SYMX_SPECIAL) {
      case LINKERDB:
        ls = smalldata_section(gv);
        xdef->relsect = (struct Section *)ls->sections.first;
        break;
    }
    xdef->flags &= ~SYMF_LNKSYM;  /* do not init again */
  }
  else
    elf_setlnksym(gv,xdef);
}

#endif /* ELF32_AROS */



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


static uint8_t i386_reloc_vlink2elf(struct Reloc *r)
/* Try to map vlink-internal representation to a valid ELF reloc type */
{
  struct RelocInsert *ri;

  if (ri = r->insert) {
    if (ri->bpos==0 && ri->bsiz==32 &&
        (ri->mask & 0xffffffff)==0xffffffff && ri->next==NULL) {
      switch (r->rtype) {
        case R_ABS: return R_386_32;
        case R_PC: return R_386_PC32;
        case R_GOT: return R_386_GOT32;
        case R_PLT: return R_386_PLT32;
        case R_COPY: return R_386_COPY;
        case R_GLOBDAT: return R_386_GLOB_DAT;
        case R_JMPSLOT: return R_386_JMP_SLOT;
        case R_GOTOFF: return R_386_GOTOFF;
        case R_GOTPC: return R_386_GOTPC;
      }
    }
  }

  return R_NONE;
}


#ifdef ELF32_386

static void i386_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 shared object (which is pos. independant) */
{
  ierror("i386_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void i386_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 relocatable object file */
{
  elf32_writeobject(gv,f,EM_386,_LITTLE_ENDIAN_,i386_reloc_vlink2elf);
}


static void i386_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32i386 executable file (with absolute addresses) */
{
  elf32_writeexec(gv,f,EM_386,_LITTLE_ENDIAN_,i386_reloc_vlink2elf);
}

#endif /* ELF32_386 */


#ifdef ELF32_AROS

static void aros_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32aros shared object (which is pos. independant) */
{
  ierror("aros_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void aros_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32aros relocatable object file */
{
  elf32_writeobject(gv,f,EM_386,_LITTLE_ENDIAN_,i386_reloc_vlink2elf);
}


static void aros_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elfaros executable file, which in reality */
/* is a relocatable object too, but all symbol references have */
/* been resolved */
{
  struct LinkedSection *ls;

  for (ls=(struct LinkedSection *)gv->lnksec.first; ls->n.next!=NULL;
       ls=(struct LinkedSection *)ls->n.next) {
    /* set filesize to memsize for all sections */
    if (!(ls->flags & SF_UNINITIALIZED))
      ls->filesize = ls->size;
  }

  elf32_writeobject(gv,f,EM_386,_LITTLE_ENDIAN_,i386_reloc_vlink2elf);
}

#endif /* ELF32_AROS */


#endif /* ELF32_386 || ELF32_AROS */
