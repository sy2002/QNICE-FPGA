/* $VER: vlink t_elf32ppcbe.c V0.15a (28.02.15)
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
#if defined(ELF32_PPC_BE) || defined(ELF32_AMIGA)
#define T_ELF32PPCBE_C
#include "vlink.h"
#include "elf32.h"
#include "rel_elfppc.h"

#define SBSS_MAXSIZE (4)  /* objects up to 4 bytes into .sbss */

static int ppc32be_identify(char *,uint8_t *,unsigned long,bool);
static void ppc32be_readconv(struct GlobalVars *,struct LinkFile *);

#if defined(ELF32_PPC_BE) || defined(ELF32_AMIGA)
static struct Symbol *ppc32be_dynentry(struct GlobalVars *,DynArg,int);
static void ppc32be_dyncreate(struct GlobalVars *);
static void ppc32be_writeobject(struct GlobalVars *,FILE *);
static void ppc32be_writeshared(struct GlobalVars *,FILE *);
static void ppc32be_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32ppcbe = {
  "elf32ppcbe",
  NULL,
  NULL,
  elf32_headersize,
  ppc32be_identify,
  ppc32be_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf32_initdynlink,
  ppc32be_dynentry,
  ppc32be_dyncreate,
  ppc32be_writeobject,
  ppc32be_writeshared,
  ppc32be_writeexec,
  bss_name,sbss_name,
  0x10000,
  0x8000,
  4,
  0,
  RTAB_ADDEND,RTAB_ADDEND,
  _BIG_ENDIAN_,
  32
};
#endif

#ifdef ELF32_AMIGA
static int amiga_targetlink(struct GlobalVars *,struct LinkedSection *,
                            struct Section *);
static struct Symbol *amiga_lnksym(struct GlobalVars *,struct Section *,
                                   struct Reloc *);
static void amiga_setlnksym(struct GlobalVars *,struct Symbol *);
static void amiga_writeobject(struct GlobalVars *,FILE *);
static void amiga_writeshared(struct GlobalVars *,FILE *);
static void amiga_writeexec(struct GlobalVars *,FILE *);
static void morphos_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32powerup = {
  "elf32powerup",
  NULL,
  NULL,
  elf32_headersize,
  ppc32be_identify,
  ppc32be_readconv,
  NULL,
  amiga_targetlink,
  NULL,
  amiga_lnksym,
  amiga_setlnksym,
  NULL,NULL,NULL,
  amiga_writeobject,
  amiga_writeshared,
  amiga_writeexec,
  bss_name,sbss_name,
  0,
  0x8000,
  4,
  0,
  RTAB_ADDEND,RTAB_ADDEND,
  _BIG_ENDIAN_,
  32,
  FFF_RELOCATABLE|FFF_PSEUDO_DYNLINK
};

struct FFFuncs fff_elf32morphos = {
  "elf32morphos",
  NULL,
  NULL,
  elf32_headersize,
  ppc32be_identify,
  ppc32be_readconv,
  NULL,
  elf_targetlink,
  NULL,
  amiga_lnksym,
  amiga_setlnksym,
  NULL,NULL,NULL,
  amiga_writeobject,
  amiga_writeshared,
  morphos_writeexec,
  bss_name,sbss_name,
  0,
  0x8000,
  4,
  0,
  RTAB_ADDEND,RTAB_ADDEND,
  _BIG_ENDIAN_,
  32,
  FFF_RELOCATABLE
};

struct FFFuncs fff_elf32amigaos = {
  "elf32amigaos",
  NULL,
  NULL,
  elf32_headersize,
  ppc32be_identify,
  ppc32be_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf32_initdynlink,
  ppc32be_dynentry,
  ppc32be_dyncreate,
  ppc32be_writeobject,
  ppc32be_writeshared,
  ppc32be_writeexec,
  bss_name,sbss_name,
  0x10000,
  0x8000,
  4,
  0,
  RTAB_ADDEND,RTAB_ADDEND,
  _BIG_ENDIAN_,
  32,
  FFF_DYN_RESOLVE_ALL
};


/* elf32powerup/elf32morphos linker symbols */
static char linkerdb[] = "_LinkerDB";
static char sdatasize[] = "__sdata_size";
static char sbsssize[] = "__sbss_size";
static char ddrelocs[] = "__datadata_relocs";
static char textsize[] = "__text_size";
#define LINKERDB        0   /* _LinkerDB, powerup/morphos */
#define R13INIT         1   /* __r13_init, morphos */
#define SDATASIZE       2   /* __sdata_size, morphos */
#define SBSSSIZE        3   /* __sbss_size, morphos */
#define DDRELOCS        4   /* __datadata_relocs, morphos */
#define TEXTSIZE        5   /* __text_size, morphos */

static char ddrelocs_name[] = "ddrelocs";
#endif



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static int ppc32be_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify ELF-PPC-32Bit-BigEndian */
{
  int id;

  /* first check for ancient PowerPC machine types */
  if ((id = elf_identify(&fff_elf32ppcbe,name,p,plen,ELFCLASS32,ELFDATA2MSB,
                         EM_CYGNUS_POWERPC,ELF_VER)) != ID_UNKNOWN)
    return id;

  /* EM_PPC_OLD is used in Motorola's libmoto.a, for example... */
  if ((id = elf_identify(&fff_elf32ppcbe,name,p,plen,ELFCLASS32,ELFDATA2MSB,
                         EM_PPC_OLD,ELF_VER)) != ID_UNKNOWN)
    return id;

  /* the normal case: EM_PPC */
  return elf_identify(&fff_elf32ppcbe,name,p,plen,ELFCLASS32,ELFDATA2MSB,
                       EM_PPC,ELF_VER);
}


static uint8_t setupRI(uint8_t rtype,struct ELF2vlink *convert,
                       struct RelocInsert *ri1,struct RelocInsert *ri2)
{
  ri1->bpos = convert[rtype].bpos;
  ri1->bsiz = convert[rtype].bsiz;
  if ((ri1->mask = convert[rtype].mask) == 0) {
    /* @ha mode - add a second RelocInsert */
    memset(ri2,0,sizeof(struct RelocInsert));
    ri1->next = ri2;
    ri1->mask = 0xffff0000;
    ri2->bsiz = 16;
    ri2->mask = 0x8000;
  }
  return convert[rtype].rtype;
}


static uint8_t ppc32_reloc_elf2vlink(uint8_t rtype,struct RelocInsert *ri)
/* Determine vlink internal reloc type from ELF reloc type and fill in
   reloc-insert description informations.
   All fields of the RelocInsert structure are preset to zero. */
{
  /* Reloc conversion table for V.4-ABI @@@ not complete! */
  static struct ELF2vlink convertV4[] = {
    R_NONE,0,0,-1,
    R_ABS,0,32,-1,              /* R_PPC_ADDR32 */
    R_ABS,6,24,~3,              /* R_PPC_ADDR24 */
    R_ABS,0,16,-1,              /* R_PPC_ADDR16 */
    R_ABS,0,16,0xffff,          /* R_PPC_ADDR16_LO */
    R_ABS,0,16,0xffff0000,      /* R_PPC_ADDR16_HI */
    R_ABS,0,16,0,               /* R_PPC_ADDR16_HA */
    R_ABS,16,14,~3,             /* R_PPC_ADDR14 */
    R_ABS,16,14,~3,             /* R_PPC_ADDR14_BRTAKEN */
    R_ABS,16,14,~3,             /* R_PPC_ADDR14_BRNTAKEN */
    R_PC,6,24,~3,               /* R_PPC_REL24 */
    R_PC,16,14,~3,              /* R_PPC_REL14 */
    R_PC,16,14,~3,              /* R_PPC_REL14_BRTAKEN */
    R_PC,16,14,~3,              /* R_PPC_REL14_BRNTAKEN */
    R_GOT,0,16,-1,              /* R_PPC_GOT16 */
    R_GOT,0,16,0xffff,          /* R_PPC_GOT16_LO */
    R_GOT,0,16,0xffff0000,      /* R_PPC_GOT16_HI */
    R_GOT,0,16,0,               /* R_PPC_GOT16_HA */
    R_PLTPC,6,24,~3,            /* R_PPC_PLTREL24 */
    R_COPY,0,32,-1,             /* R_PPC_COPY */
    R_GLOBDAT,0,32,-1,          /* R_PPC_GLOB_DAT */
    R_JMPSLOT,0,64,-1,          /* R_PPC_JMP_SLOT */
    R_LOADREL,0,32,-1,          /* R_PPC_RELATIVE */
    R_LOCALPC,6,24,~3,          /* R_PPC_LOCAL24PC */
    R_UABS,0,32,-1,             /* R_PPC_UADDR32 */
    R_UABS,0,16,-1,             /* R_PPC_UADDR16 */
    R_PC,0,32,-1,               /* R_PPC_REL32 */
    R_PLT,0,32,-1,              /* R_PPC_PLT32 */
    R_PLTPC,0,32,-1,            /* R_PPC_PLTREL32 */
    R_PLT,0,16,0xffff,          /* R_PPC_PLT16_LO */
    R_PLT,0,16,0xffff0000,      /* R_PPC_PLT16_HI */
    R_PLT,0,16,0,               /* R_PPC_PLT16_HA */
    R_SD,0,16,-1,               /* R_PPC_SDAREL16 */
    R_SECOFF,0,16,-1,           /* R_PPC_SECTOFF */
    R_SECOFF,0,16,0xffff,       /* R_PPC_SECTOFF_LO */
    R_SECOFF,0,16,0xffff0000,   /* R_PPC_SECTOFF_HI */
    R_SECOFF,0,16,0,            /* R_PPC_SECTOFF_HA */
    R_ABS,0,30,~3               /* R_PPC_ADDR30 */
  };
  /* Reloc conversion table for PPC-EABI @@@ not complete! */
  static struct ELF2vlink convertEABI[] = {
    R_NONE,0,0,-1,              /* R_PPC_EMB_NADDR32 */
    R_NONE,0,0,-1,              /* R_PPC_EMB_NADDR16 */
    R_NONE,0,0,-1,              /* R_PPC_EMB_NADDR16_LO */
    R_NONE,0,0,-1,              /* R_PPC_EMB_NADDR16_HI */
    R_NONE,0,0,-1,              /* R_PPC_EMB_NADDR16_HA */
    R_NONE,0,0,-1,              /* R_PPC_EMB_SDAI16 */
    R_NONE,0,0,-1,              /* R_PPC_EMB_SDA2I16 */
    R_SD2,0,16,-1,              /* R_PPC_EMB_SDA2REL */
    R_SD21,16,16,-1,            /* R_PPC_EMB_SDA21 */
    R_NONE,0,0,-1,              /* R_PPC_EMB_MRKREF */
    R_NONE,0,0,-1,              /* R_PPC_EMB_RELSEC16 */
    R_NONE,0,0,-1,              /* R_PPC_EMB_RELST_LO */
    R_NONE,0,0,-1,              /* R_PPC_EMB_RELST_HI */
    R_NONE,0,0,-1,              /* R_PPC_EMB_RELST_HA */
    R_NONE,0,0,-1,              /* R_PPC_EMB_BIT_FLD */
    R_NONE,0,0,-1               /* R_PPC_EMB_RELSDA */
  };
  /* Reloc conversion table for MorphOS */
  static struct ELF2vlink convertMOS[] = {
    R_MOSDREL,0,16,-1,          /* R_PPC_MORPHOS_DREL */
    R_MOSDREL,0,16,0xffff,      /* R_PPC_MORPHOS_DREL_LO */
    R_MOSDREL,0,16,0xffff0000,  /* R_PPC_MORPHOS_DREL_HI */
    R_MOSDREL,0,16,0,           /* R_PPC_MORPHOS_DREL_HA */
  };
  /* Reloc conversion table for AmigaOS/PPC */
  static struct ELF2vlink convertAOS[] = {
    R_AOSBREL,0,16,-1,          /* R_PPC_AMIGAOS_BREL */
    R_AOSBREL,0,16,0xffff,      /* R_PPC_AMIGAOS_BREL_LO */
    R_AOSBREL,0,16,0xffff0000,  /* R_PPC_AMIGAOS_BREL_HI */
    R_AOSBREL,0,16,0,           /* R_PPC_AMIGAOS_BREL_HA */
  };

  static struct RelocInsert ri2;

  /* @@@ BRTAKEN/BRNTAKEN could get a special treatment by setting
     bsiz to 0 and use the next-pointer as a special function pointer */

  if (rtype <= R_PPC_ADDR30)
    return setupRI(rtype,convertV4,ri,&ri2);

  else if (rtype>=R_PPC_EMB_NADDR32 && rtype<=R_PPC_EMB_RELSDA)
    return setupRI(rtype-R_PPC_EMB_NADDR32,convertEABI,ri,&ri2);

  else if (rtype>=R_PPC_MORPHOS_DREL && rtype<=R_PPC_MORPHOS_DREL_HA)
    return setupRI(rtype-R_PPC_MORPHOS_DREL,convertMOS,ri,&ri2);

  else if (rtype>=R_PPC_AMIGAOS_BREL && rtype<=R_PPC_AMIGAOS_BREL_HA)
    return setupRI(rtype-R_PPC_AMIGAOS_BREL,convertAOS,ri,&ri2);

  return R_NONE;
}


static void ppc32be_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read elfppc32be executable / object / shared obj. */
{
  if (lf->type == ID_LIBARCH) {
    struct ar_info ai;

    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        elf_check_ar_type(fff[lf->format],lf->pathname,ai.data,
                          ELFCLASS32,ELFDATA2MSB,ELF_VER,
                          3,EM_PPC,EM_PPC_OLD,EM_CYGNUS_POWERPC);
        elf32_parse(gv,lf,(struct Elf32_Ehdr *)ai.data,
                    ppc32_reloc_elf2vlink);
      }
    }
    else
      ierror("ppc32be_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    elf32_parse(gv,lf,(struct Elf32_Ehdr *)lf->data,ppc32_reloc_elf2vlink);
  }
}


static struct Symbol *ppc32be_dynentry(struct GlobalVars *gv,DynArg a,int etype)
/* Create an entry into .got/.plt/.bss for the referenced symbol. */
{
  struct Symbol *entry_sym = NULL;
  struct Section *sec;
  const char *bssname;

  switch (etype) {

    case GOT_ENTRY:
    case GOT_LOCAL:
      /* .got has 4 reserved words at the beginning,
         is writable and executable (contains a blrl in first word),
         a new entry occupies 1 word. */
      sec = elf_dyntable(gv,16,16,ST_DATA,SF_ALLOC,SP_READ|SP_WRITE|SP_EXEC,
                         GOT_ENTRY);
      entry_sym = elf32_pltgotentry(gv,sec,a,SYMI_OBJECT,4,4,etype);
      break;

    case PLT_ENTRY:
      /* .plt has 18 reserved words at the beginning,
         is writable and executable, but uninitialized for PPC,
         a new entry occupies 2 words and 1 additional word at the end */
      sec = elf_dyntable(gv,72,72,ST_UDATA,SF_ALLOC|SF_UNINITIALIZED,
                         SP_READ|SP_WRITE|SP_EXEC,PLT_ENTRY);
      entry_sym = elf32_pltgotentry(gv,sec,a,SYMI_FUNC,8,12,PLT_ENTRY);
      break;

    case BSS_ENTRY:
      /* small objects are copied to .sbss, larger ones to .bss */
      bssname = (a.sym->size <= SBSS_MAXSIZE) ? sbss_name : bss_name;
      entry_sym = elf32_bssentry(gv,bssname,a.sym);
      break;

    case STR_ENTRY:
      /* enter StrTabList .dynstr */
      elf_adddynstr(a.name);
      break;

    case SYM_ENTRY:
      /* enter SymTabList .dynsym and name to .dynstr */
      elf_adddynsym(a.sym);
      break;

    case SO_NEEDED:
      /* denote shared object's name as 'needed' */
      elf32_dynamicentry(gv,DT_NEEDED,elf_adddynstr(a.name),NULL);
      break;

    default:
      ierror("ppc32be_dynentry(): illegal entrytype: %d",etype);
      break;
  }

  return entry_sym;
}


static void ppc32be_dyncreate(struct GlobalVars *gv)
{
  elf32_dyncreate(gv,plt_name);
}


#ifdef ELF32_AMIGA

static struct Section *ddrelocs_sec(struct GlobalVars *gv,
                                    struct LinkedSection *sdata)
{
  struct Section *s; 
  struct LinkedSection *ls;
  struct ObjectUnit *obj;

  if (sdata)
    obj = ((struct Section *)sdata->sections.first)->obj;
  else
    obj = (struct ObjectUnit *)gv->selobjects.first;
  if (obj == NULL)
    ierror("No object unit for ddrelocs section");
  s = create_section(obj,ddrelocs_name,NULL,0);
  s->type = ST_DATA;
  s->flags = SF_ALLOC;
  s->protection = SP_READ;
  s->alignment = 2;
  s->id = ~0;

  ls = create_lnksect(gv,s->name,s->type,s->flags,s->protection,
                      s->alignment,0);
  addtail(&ls->sections,&s->n);
  s->lnksec = ls;
  s->size = ls->size = 1; /* protect from deletion */

  return s;
}


static int amiga_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
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
      return (1);
  }
  return elf_targetlink(gv,ls,s);
}


static struct Symbol *amiga_lnksym(struct GlobalVars *gv,
                                     struct Section *sec,
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
      if (findlnksymbol(gv,r13init_name) == NULL) {
        /* Reference to _LinkerDB creates __r13_init */
        struct Symbol *r13init = addlnksymbol(gv,r13init_name,
                                              (lword)fff[gv->dest_format]->baseoff,
                                              SYM_ABS,SYMF_LNKSYM,
                                              SYMI_OBJECT,SYMB_GLOBAL,0);
        r13init->type = SYM_RELOC;
        r13init->extra = SYMX_SPECIAL|R13INIT;
      }
      return sym;  /* new linker symbol created */
    }

    else if (!strcmp(r13init_name,xref->xrefname)) {  /* __r13_init */
      sym = addlnksymbol(gv,r13init_name,(lword)fff[gv->dest_format]->baseoff,
                         SYM_RELOC,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|R13INIT;
      return sym;  /* new linker symbol created */
    }

    else if (!strcmp(sdatasize,xref->xrefname)) {  /* __sdata_size */
      sym = addlnksymbol(gv,sdatasize,0,
                         SYM_ABS,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|SDATASIZE;
      return sym;  /* new linker symbol created */
    }

    else if (!strcmp(sbsssize,xref->xrefname)) {  /* __sbss_size */
      sym = addlnksymbol(gv,sbsssize,0,
                         SYM_ABS,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|SBSSSIZE;
      return sym;  /* new linker symbol created */
    }

    else if (!strcmp(ddrelocs,xref->xrefname)) {  /* __datadata_relocs */
      sym = addlnksymbol(gv,ddrelocs,0,
                         SYM_RELOC,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|DDRELOCS;
      return sym;  /* new linker symbol created */
    }

    else if (!strcmp(textsize,xref->xrefname)) {  /* __text_size */
      sym = addlnksymbol(gv,textsize,0,
                         SYM_ABS,SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
      sym->extra = SYMX_SPECIAL|TEXTSIZE;
      return sym;  /* new linker symbol created */
    }
  }

  return elf_lnksym(gv,sec,xref);
}


static void amiga_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
{
  if ((xdef->flags & SYMF_LNKSYM) && (xdef->extra & SYMX_SPECIAL)) {
    struct LinkedSection *ls;

    switch (xdef->extra & ~SYMX_SPECIAL) {
      case LINKERDB:
      case R13INIT:
        ls = smalldata_section(gv);
        xdef->relsect = (struct Section *)ls->sections.first;
        break;
      case SDATASIZE:
        if (ls = find_lnksec(gv,sdata_name,0,0,0,0))
          xdef->value = (lword)ls->size;
        break;
      case SBSSSIZE:
        if (ls = find_lnksec(gv,sbss_name,0,0,0,0))
          xdef->value = (lword)ls->size;
        break;
      case DDRELOCS:
        xdef->relsect = ddrelocs_sec(gv,find_lnksec(gv,sdata_name,0,0,0,0));
        break;
      case TEXTSIZE:
        if (ls = find_lnksec(gv,text_name,0,0,0,0))
          xdef->value = (lword)ls->size;
        break;
    }
    xdef->flags &= ~SYMF_LNKSYM;  /* do not init again */
  }
  else
    elf_setlnksym(gv,xdef);
}

#endif /* ELF32_AMIGA */



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/

#define FSTD 1  /* standard field, 16 or 32 bits */
#define FLO 2   /* @l lower 16 bits */
#define FHI 3   /* @h higher 16 bits */
#define FHA 4   /* @ha higher 16 bits for add, including carry */
#define FB24 5  /* low24 field, b and bl branches */
#define FB14 6  /* low14 field, 16-bit conditional branches */
#define FW30 7  /* 30-bit word */


static uint8_t ppc32_reloc_vlink2elf(struct Reloc *r)
/* Try to map vlink-internal representation to a valid ELF reloc type */
{
  lword m32 = 0xffffffff;
  struct RelocInsert *ri;
  uint8_t rt = R_NONE;

  if (ri = r->insert) {
    int pos = (int)ri->bpos;
    int size = (int)ri->bsiz;
    lword mask = ri->mask;
    struct RelocInsert *ri2 = ri->next;
    int f = 0;  /* field type */

    r->offset += (unsigned long)pos >> 3;
    pos &= 7;
    ri->bpos = (uint16_t)pos;

    if (pos==0 && (size==16 || size==32) && mask==-1 && ri2==NULL) {
      f = FSTD;
    }
    else if (pos==6 && size==24 && (mask&0x3ffffff)==0x3fffffc && ri2==NULL) {
      f = FB24;
    }
    else if (pos==0 && size==16 && (mask&m32)==0xffff && ri2==NULL) {
      f = FLO;
    }
    else if (pos==0 && size==16 && (mask&m32)==0xffff0000 && ri2==NULL) {
      f = FHI;
    }
    else if (pos==0 && size==16 && (mask&m32)==0xffff0000 && ri2!=NULL) {
      if (ri2->bpos==0 && ri2->bsiz==16 &&
          (ri2->mask&m32)==0x8000 && ri2->next==NULL)
        f = FHA;
    }
    else if (pos==0 && size==14 && (mask&0xffff)==0xfffc && ri2==NULL) {
      f = FB14;
      r->offset -= 2;
      ri->bpos += 16;
    }
    else if (pos==0 && size==30 && ri2==NULL) {
      f = FW30;
    }
    else
      f = 0;  /* no usable insert-field description found */

    switch (r->rtype) {

      case R_ABS:
        switch (f) {
          case FSTD: rt = size==32 ? R_PPC_ADDR32 : R_PPC_ADDR16; break;
          case FLO: rt = R_PPC_ADDR16_LO; break;
          case FHI: rt = R_PPC_ADDR16_HI; break;
          case FHA: rt = R_PPC_ADDR16_HA; break;
          case FB24: rt = R_PPC_ADDR24; break;
          case FB14: rt = R_PPC_ADDR14; break;
          case FW30: rt = R_PPC_ADDR30; break;
        }
        break;

      case R_PC:
        switch (f) {
          case FSTD:
            if (size == 32) {
              rt = R_PPC_REL32;
            }
            else if ((r->addend & 3) == 0) {
              r->offset -= 2;
              ri->bpos += 16;
              rt = R_PPC_REL14;
            }
            break;
          case FB24: rt = R_PPC_REL24; break;
          case FB14: rt = R_PPC_REL14; break;  /* @@@ BRTAKEN/BRNTAKEN */
        }
        break;

      case R_GOT:
        switch (f) {
          case FSTD:
            if (size == 16)
              rt = R_PPC_GOT16;
            break;
          case FLO: rt = R_PPC_GOT16_LO; break;
          case FHI: rt = R_PPC_GOT16_HI; break;
          case FHA: rt = R_PPC_GOT16_HA; break;
        }
        break;

      case R_PLT:
        switch (f) {
          case FSTD:
            if (size == 32)
              rt = R_PPC_PLT32;
            break;
          case FLO: rt = R_PPC_PLT16_LO; break;
          case FHI: rt = R_PPC_PLT16_HI; break;
          case FHA: rt = R_PPC_PLT16_HA; break;
        }
        break;

      case R_PLTPC:
        switch (f) {
          case FSTD:
            if (size == 32)
              rt = R_PPC_PLTREL32;
            break;
          case FB24: rt = R_PPC_PLTREL24; break;
        }
        break;

      case R_SECOFF:
        switch (f) {
          case FSTD:
            if (size == 16)
              rt = R_PPC_SECTOFF;
            break;
          case FLO: rt = R_PPC_SECTOFF_LO; break;
          case FHI: rt = R_PPC_SECTOFF_HI; break;
          case FHA: rt = R_PPC_SECTOFF_HA; break;
        }
        break;
      
      case R_COPY:
        rt = R_PPC_COPY;
        break;
      
      case R_GLOBDAT:
        rt = R_PPC_GLOB_DAT;
        break;
      
      case R_JMPSLOT:
        rt = R_PPC_JMP_SLOT;
        break;
      
      case R_LOADREL:
        rt = R_PPC_RELATIVE;
        break;
      
      case R_LOCALPC:
        if (f == FB24)
          rt = R_PPC_LOCAL24PC;
        break;

      case R_SD:
        if (f==FSTD && size==16)
          rt = R_PPC_SDAREL16;
        break;

       case R_UABS:
         rt = size==32 ? R_PPC_UADDR32 : R_PPC_UADDR16;
         break;

      /* Embedded and OS-specific relocs */

      case R_SD2:
        if (f==FSTD && size==16)
          rt = R_PPC_EMB_SDA2REL;
        break;

      case R_SD21:
        if (f==FSTD && size==16) {
          r->offset -= 2;
          ri->bpos += 16;
          rt = R_PPC_EMB_SDA21;
        }
        break;

      case R_MOSDREL:
        switch (f) {
          case FSTD:
            if (size == 16)
              rt = R_PPC_MORPHOS_DREL;
            break;
          case FLO: rt = R_PPC_MORPHOS_DREL_LO; break;
          case FHI: rt = R_PPC_MORPHOS_DREL_HI; break;
          case FHA: rt = R_PPC_MORPHOS_DREL_HA; break;
        }
        break;

      case R_AOSBREL:
        switch (f) {
          case FSTD:
            if (size == 16)
              rt = R_PPC_AMIGAOS_BREL;
            break;
          case FLO: rt = R_PPC_AMIGAOS_BREL_LO; break;
          case FHI: rt = R_PPC_AMIGAOS_BREL_HI; break;
          case FHA: rt = R_PPC_AMIGAOS_BREL_HA; break;
        }
        break;
    }
  }

  return rt;
}


static void init_got(struct GlobalVars *gv)
/* initialize target-specific .got contents */
{
  struct LinkedSection *got,*dyn;

  if (got = find_lnksec(gv,got_name,0,0,0,0)) {
    write32be(got->data,0x4e800021);  		  /* 0: blrl */
    if (dyn = find_lnksec(gv,dyn_name,0,0,0,0))
      write32be(got->data+4,(uint32_t)dyn->base);   /* 4: .dynamic address */
  }
}


#ifdef ELF32_PPC_BE

static void ppc32be_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elfppc32be shared object (which is pos. independant) */
{
  init_got(gv);
  elf32_writeexec(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}


static void ppc32be_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elfppc32be relocatable object file */
{
  elf32_writeobject(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}


static void ppc32be_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elfppc32be executable file (with absolute addresses) */
{
  init_got(gv);
  elf32_writeexec(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}

#endif /* ELF32_PPC_BE */


#ifdef ELF32_AMIGA

static void make_ddrelocs(struct GlobalVars *gv,struct LinkedSection *ddrel)
{
  struct LinkedSection *sdata;
  struct Section *sec;
  struct Reloc *rel;
  uint8_t *table;
  uint32_t *p;
  unsigned long size;
  uint32_t nrelocs = 0;

  if (sdata = find_lnksec(gv,sdata_name,0,0,0,0)) {
    for (rel=(struct Reloc *)sdata->relocs.first;
         rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next) {
      if (rel->relocsect.lnk==sdata && rel->rtype==R_ABS)
        nrelocs++;
    }
  }

  size = (nrelocs+1) * sizeof(uint32_t);
  table = alloc(size);
  p = (uint32_t *)table;
  write32be(p++,nrelocs);

  if (sdata) {
    for (rel=(struct Reloc *)sdata->relocs.first;
         rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next) {
      if (rel->relocsect.lnk==sdata && rel->rtype==R_ABS)
        write32be(p++,(uint32_t)rel->offset);
    }
  }

  ddrel->data = table;
  ddrel->size = ddrel->filesize = size;
  if (sec = (struct Section *)ddrel->sections.first) {
    sec->data = table;
    sec->size = size;
  }
}


static void amiga_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32powerup/morphos shared object (which is pos.
   independant) */
{
  ierror("amiga_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void amiga_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32powerup/morphos relocatable object file */
{
  elf32_writeobject(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}


static void amiga_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32powerup executable file, which in */
/* reality is a relocatable object too, but all symbol references have */
/* been resolved */
{
  struct LinkedSection *ls;

  if (gv->collect_ctors_type == CCDT_VBCC_ELF) {
    static const char ctname[] = ".vbcc_ctors";
    static const char dtname[] = ".vbcc_dtors";
    /* rename .ctors and .dtors,
       otherwise the PowerUp ELF loader will rearrange the pointers */
    if (ls = find_lnksec(gv,ctors_name,0,0,0,0))
      ls->name = ctname;
    if (ls = find_lnksec(gv,dtors_name,0,0,0,0))
      ls->name = dtname;
  }

  for (ls=(struct LinkedSection *)gv->lnksec.first; ls->n.next!=NULL;
       ls=(struct LinkedSection *)ls->n.next) {
    /* set filesize to memsize for all sections */
    if (!(ls->flags & SF_UNINITIALIZED))
      ls->filesize = ls->size;

    /* setup ddrelocs section, if present */
    if (!strcmp(ls->name,ddrelocs_name))
      make_ddrelocs(gv,ls);
  }

  elf32_writeobject(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}


static void morphos_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32morphos executable file, which in */
/* reality is a relocatable object too, but all symbol references have */
/* been resolved */
{
  struct LinkedSection *ls;
  int sdflag=0,sbflag=0;

  for (ls=(struct LinkedSection *)gv->lnksec.first; ls->n.next!=NULL;
       ls=(struct LinkedSection *)ls->n.next) {

    if (ls->flags & SF_SMALLDATA) {
      /* data sections should be called .sdata, and bss sections .sbss */

      if (ls->type == ST_DATA) {  /* .sdata */
        struct Section *bss_sec = find_first_bss_sec(ls);

        if (sdflag)
          error(124,fff[gv->dest_format]->tname);
        sdflag = 1;
        ls->name = sdata_name;

        if (bss_sec && (ls->filesize < ls->size)) {
          /* put bss-part of .sdata into an own section called .sbss */
          struct LinkedSection *sbss;
          struct Section *sec = bss_sec;
          struct Section *nextsec;
          struct Symbol *sym = (struct Symbol *)ls->symbols.first;
          struct Symbol *nextsym;
          unsigned long bss_offset = bss_sec->offset;
          lword bss_va = (lword)(ls->base + bss_offset);

          sbss = create_lnksect(gv,sbss_name,ST_UDATA,
                                ls->flags|SF_UNINITIALIZED,
                                ls->protection,ls->alignment,ls->memattr);
          sbss->size = ls->size - bss_sec->offset;
          sbss->data = alloc(sbss->size);

          /* move bss sections from .sdata to .sbss */
          while (nextsec = (struct Section *)sec->n.next) {
            remnode(&sec->n);
            addtail(&sbss->sections,&sec->n);
            sec->lnksec = sbss;
            sec->offset -= bss_offset;
            sec = nextsec;
          }

          /* move symbols */
          while (nextsym = (struct Symbol *)sym->n.next) {
            /* move bss symbols to .sbss */
            if (sym->relsect->lnksec == sbss) {
              remnode(&sym->n);
              addtail(&sbss->symbols,&sym->n);
              sym->value -= bss_va;
            }
            sym = nextsym;
          }
          /* no relocs and no xrefs can occur in bss */

          ls->size -= sbss->size;  /* the bss part is gone */
        }
      }

      else if (ls->type == ST_UDATA) {
        if (sbflag)
          error(124,fff[gv->dest_format]->tname);
        sbflag = 1;
        ls->name = sbss_name;
      }
    }

    /* set filesize to memsize for all sections */
    if (!(ls->flags & SF_UNINITIALIZED))
      ls->filesize = ls->size;

    /* setup ddrelocs section, if present */
    if (!strcmp(ls->name,ddrelocs_name))
      make_ddrelocs(gv,ls);
  }

  elf32_writeobject(gv,f,EM_PPC,_BIG_ENDIAN_,ppc32_reloc_vlink2elf);
}

#endif /* ELF32_AMIGA */


#endif /* ELF32_PPC_BE || ELF32_AMIGA */
