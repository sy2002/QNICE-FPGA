/* $VER: vlink elf.c V0.14 (29.07.11)
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
#if defined(ELF32) || defined(ELF64)
#define ELF_C
#include "vlink.h"
#include "elfcommon.h"
#include "elf32std.h"
#include "elf64std.h"


/* global data for all ELF targets */
struct StrTabList elfstringlist = { {NULL,NULL,NULL},NULL,STRHTABSIZE,0 };
struct StrTabList elfdstrlist = { {NULL,NULL,NULL},NULL,DYNSTRHTABSIZE,0 };
struct StrTabList elfshstrlist = { {NULL,NULL,NULL},NULL,SHSTRHTABSIZE,0 };
struct SymTabList elfsymlist;
struct SymTabList elfdsymlist;

struct list shdrlist;
struct list elfdynsymlist;

struct Section *elfdynrelocs;
struct Section *elfpltrelocs;

uint32_t elfshdridx,elfsymtabidx,elfshstrtabidx,elfstrtabidx;
uint32_t elfoffset;             /* current ELF file offset */
unsigned long elf_file_hdr_gap; /* gap between hdr and first segment */
int8_t elf_endianess = -1;      /* used while creating output-file */

/* ELF section names */
const char note_name[] = ".note";
const char dyn_name[] = ".dynamic";
const char hash_name[] = ".hash";
const char dynsym_name[] = ".dynsym";
const char dynstr_name[] = ".dynstr";
const char *dynrel_name[2] = { ".rel.dyn",".rela.dyn" };
const char *pltrel_name[2] = { ".rel.plt",".rela.plt" };


/* local static data */
static struct list phdrlist;
static struct Section *gotsec = NULL;
static struct Section *pltsec = NULL;
static int secsyms;  /* offset to find section symbols by shndx */

static char ELFid[4] = {   /* identification for all ELF files */
  0x7f,'E','L','F'
};

/* table to determine number of buckets in .hash */
static const size_t elf_buckets[] =
{
  1, 3, 17, 37, 67, 97, 131, 197, 263, 521, 1031, 2053, 4099, 8209,
  16411, 32771, 0
};

/* common linker symbols */
static const char *elf_symnames[] = {
  sdabase_name,sda2base_name,"__CTOR_LIST__","__DTOR_LIST__",
  gotbase_name+1,pltbase_name+1,dynamic_name+1
};



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


int elf_identify(struct FFFuncs *ff,char *name,void *p,
                 lword plen,unsigned char class,
                 unsigned char endian,uint16_t machine,uint32_t ver)
/* check a possible ELF file against the requirements, then */
/* return its type (object, library, shared object) */
{
  bool arflag = FALSE;
  bool be = (endian == ELFDATA2MSB);
  struct Elf_CommonHdr *hdr;
  struct ar_info ai;

  if (plen < sizeof(struct Elf_CommonHdr))
    return ID_UNKNOWN;

  if (ar_init(&ai,(char *)p,plen,name)) {
    /* library archive detected, extract 1st archive member */
    arflag = TRUE;
    if (!(ar_extract(&ai))) {
      error(38,name);  /* Empty archive ignored */
      return ID_IGNORE;
    }
    hdr = (struct Elf_CommonHdr *)ai.data;
  }
  else
    hdr = (struct Elf_CommonHdr *)p;

  if ((class==ELFCLASS32 && plen < sizeof(struct Elf32_Ehdr)) ||
      (class==ELFCLASS64 && plen < sizeof(struct Elf64_Ehdr)))
    return ID_UNKNOWN;

  if (!strncmp((char *)hdr->e_ident,ELFid,4)) {
    /* ELF identification found */
    if (hdr->e_ident[EI_CLASS]==class && hdr->e_ident[EI_DATA]==endian &&
        hdr->e_ident[EI_VERSION]==(unsigned char)ver &&
        read32(be,hdr->e_version)==ver && read16(be,hdr->e_machine)==machine) {
      switch (read16(be,hdr->e_type)) {
        case ET_REL:
          return arflag ? ID_LIBARCH : ID_OBJECT;
        case ET_EXEC:
          if (arflag) /* no executables in library archives */
            error(40,name,ff->tname);
          return ID_EXECUTABLE;
        case ET_DYN:
          if (arflag) /* no shared objects in library archives */
            error(39,name,ff->tname);
          return ID_SHAREDOBJ;
        default:
          error(41,name,ff->tname);  /* illegal fmt. / file corrupted */
          break;
      }
    }
  }

  return ID_UNKNOWN;
}


void elf_check_ar_type(struct FFFuncs *ff,const char *name,void *p,
                       unsigned char class,unsigned char endian,
                       uint32_t ver,int nmach,...)
/* check all library archive members before conversion */
{
  struct Elf_CommonHdr *ehdr = (struct Elf_CommonHdr *)p;
  bool be = (endian == ELFDATA2MSB);
  uint16_t m = read16(be,ehdr->e_machine);
  va_list vl;

  va_start(vl,nmach);
  if (!strncmp((char *)ehdr->e_ident,ELFid,4)) {
    /* ELF identification found */
    if (ehdr->e_ident[EI_CLASS]==class && ehdr->e_ident[EI_DATA]==endian &&
        ehdr->e_ident[EI_VERSION]==(unsigned char)ver &&
        read32(be,ehdr->e_version)==ver && nmach>0) {
      while (nmach--) {
        if (va_arg(vl,int) == m)
          m = 0;
      }
      if (m == 0) {
        switch (read16(be,ehdr->e_type)) {
          case ET_REL:
            goto check_ar_exit;
          case ET_EXEC:  /* no executables in library archives */
            error(40,name,ff->tname);
            break;
          case ET_DYN:  /* no shared objects in library archives */
            error(39,name,ff->tname);
            break;
          default:  /* illegal fmt. / file corrupted */
            break;
        }
      }
    }
  }
  error(41,name,ff->tname);

check_ar_exit:
  va_end(vl);
}


void elf_check_offset(struct LinkFile *lf,char *tabname,void *data,lword size)
{
  uint8_t *p = (uint8_t *)data;

  if ((p < lf->data) || (p + size) > (lf->data + lf->length))
    error(51,lf->pathname,tabname,lf->objname);
}


struct Section *elf_add_section(struct GlobalVars *gv,struct ObjectUnit *ou,
                                char *name,uint8_t *data,lword size,
                                uint32_t shtype,uint64_t shflags,uint8_t align)
{
  struct LinkFile *lf = ou->lnkfile;
  uint8_t type=ST_DATA,flags=0,prot=SP_READ;

  if (gv->strip_symbols>=STRIP_DEBUG &&
      (!strncmp(name,".debug",6) || !strncmp(name,".line",5) ||
       !strncmp(name,".stab",5)))
    return NULL;   /* ignore debugging sections when -S or -s is given */

  if (shtype == SHT_NOBITS) {
    data = NULL;
    type = ST_UDATA;
    flags |= SF_UNINITIALIZED;
  }
  else {
    if (data+size > lf->data+lf->length)  /* illegal section offset */
      error(49,lf->pathname,name,lf->objname);
  }

  if ((shflags & SHF_EXECINSTR) && data!=NULL) {
    type = ST_CODE;
    prot |= SP_EXEC;
  }
  if (shflags & SHF_WRITE)
    prot |= SP_WRITE;
  if (shflags & SHF_ALLOC)
    flags |= SF_ALLOC;
  if (!strncmp(name,".gnu.linkonce",13))
    flags |= SF_LINKONCE;

  return add_section(ou,name,data,size,type,flags,prot,align,FALSE);
}


void elf_add_symbol(struct GlobalVars *gv,struct ObjectUnit *ou,
                    char *symname,uint8_t flags,int shndx,uint32_t shtype,
                    uint8_t sttype,uint8_t stbind,lword value,uint32_t size)
{
  struct LinkFile *lf = ou->lnkfile;
  struct Section *sec;
  uint8_t type = 0;

  if (flags & SYMF_SHLIB) {
    /* don't import linker symbols from shared objects - we make our own */
    int i;

    for (i=0; i<(sizeof(elf_symnames)/sizeof(elf_symnames[0])); i++) {
      if (!strcmp(elf_symnames[i],symname))
        return;
    }
  }

  switch (shndx) {
    case SHN_UNDEF:
      sec = NULL;  /* ignore xrefs for now */
      break;
    /* assign a section for ABS and COMMON symbols */
    case SHN_ABS:
      sec = abs_section(ou);
      type = SYM_ABS;
      break;
    case SHN_COMMON:
      sec = common_section(gv,ou);
      type = SYM_COMMON;
      break;
    /* reloc symbols have a definite section to which they belong */
    default:
      if (shtype == SHT_DYNSYM) {
        /* just put dynamic symbols into the first section -
           the section index might be wrong in .dynsym */
        sec = abs_section(ou);
      }
      else if (!(sec = find_sect_id(ou,shndx))) {
        /* a section with this index doesn't exist! */
        if (sttype != STT_SECTION)
          error(53,lf->pathname,symname,lf->objname,shndx);
      }
      type = SYM_RELOC;
      break;
  }

  if (sttype == STT_SECTION)
    sec = NULL;  /* ignore section defines - will be reproduced */

  if (sec) {
    if (sttype > STT_FILE) {
      /* illegal symbol type */
      error(54,lf->pathname,(int)sttype,symname,lf->objname);
      sttype = STT_NOTYPE;
    }
    switch (stbind) {
      case STB_LOCAL:
        stbind = SYMB_LOCAL;
        break;
      case STB_GLOBAL:
        stbind = SYMB_GLOBAL;
        break;
      case STB_WEAK:
        stbind = SYMB_WEAK;
        break;
      default:  /* illegal binding type */
        error(55,lf->pathname,symname,stbind,lf->objname);
        stbind = SYMB_LOCAL;
        break;
    }

    /* add a new symbol definition */
    if (stbind == SYMB_LOCAL)
      addlocsymbol(gv,sec,symname,NULL,value,type,flags,sttype,size);
    else
      addsymbol(gv,sec,symname,NULL,value,type,flags,sttype,stbind,size,TRUE);
  }
}


/*****************************************************************/
/*                          Link ELF                             */
/*****************************************************************/


int elf_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                   struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  return 0;
}


struct Symbol *elf_makelnksym(struct GlobalVars *gv,int idx)
{
  struct Symbol *sym = addlnksymbol(gv,elf_symnames[idx],0,SYM_ABS,
                                    SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);

  sym->extra = idx;  /* for easy ident. in elf_setlnksym */
  switch (idx) {
    case SDABASE:
    case SDA2BASE:
      sym->type = SYM_RELOC;
      sym->value = (lword)fff[gv->dest_format]->baseoff;
      break;
    case GLOBOFFSTAB:
      sym->value = fff[gv->dest_format]->gotoff;
      gv->got_base_name = elf_symnames[idx];
      break;
    case PROCLINKTAB:
      gv->plt_base_name = elf_symnames[idx];
      break;
  }
  return sym;
}


struct Symbol *elf_lnksym(struct GlobalVars *gv,struct Section *sec,
                          struct Reloc *xref)
/* Check for common ELF linker symbols. */
{
  int i;

  if (!gv->dest_object) {
    for (i=0; i<(sizeof(elf_symnames)/sizeof(elf_symnames[0])); i++) {
      if (!strcmp(elf_symnames[i],xref->xrefname))
        return elf_makelnksym(gv,i);  /* new linker symbol created */
    }
  }
  return NULL;
}


void elf_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
/* Initialize common ELF linker symbol structure during resolve_xref() */
{
  if (xdef->flags & SYMF_LNKSYM) {
    struct LinkedSection *ls;

    switch (xdef->extra) {
      case SDABASE:
        if (!(ls = find_lnksec(gv,sdata_name,ST_DATA,0,0,0)))
          if (!(ls = find_lnksec(gv,sbss_name,ST_UDATA,0,0,0)))
            ls = smalldata_section(gv);
        xdef->relsect = (struct Section *)ls->sections.first;
        break;
      case SDA2BASE:
        if (!(ls = find_lnksec(gv,sdata2_name,ST_DATA,0,0,0)))
          if (!(ls = find_lnksec(gv,sbss2_name,ST_UDATA,0,0,0)))
            ls = smalldata_section(gv);
        xdef->relsect = (struct Section *)ls->sections.first;
        break;
      case CTORS:
        if (ls = find_lnksec(gv,ctors_name,0,0,0,0)) {
          xdef->type = SYM_RELOC;
          xdef->relsect = (struct Section *)ls->sections.first;
        }
        break;
      case DTORS:
        if (ls = find_lnksec(gv,dtors_name,0,0,0,0)) {
          xdef->type = SYM_RELOC;
          xdef->relsect = (struct Section *)ls->sections.first;
        }
        break;
      case GLOBOFFSTAB:
        if (ls = find_lnksec(gv,got_name,0,0,0,0)) {
          xdef->type = SYM_RELOC;
          xdef->relsect = (struct Section *)ls->sections.first;
        }
        break;
      case PROCLINKTAB:
        if (ls = find_lnksec(gv,plt_name,0,0,0,0)) {
          xdef->type = SYM_RELOC;
          xdef->relsect = (struct Section *)ls->sections.first;
        }
        break;
      case DYNAMICSYM:
        if (ls = find_lnksec(gv,dyn_name,0,0,0,0)) {
          xdef->value = ls->base;
        }
        /* @@@ when .dynamic was not created _DYNAMIC stays NULL - ok? */
        break;
    }
    xdef->flags &= ~SYMF_LNKSYM;  /* do not init again */
  }
}


struct Section *elf_dyntable(struct GlobalVars *gv,
                             unsigned long initial_size,
                             unsigned long initial_offset,
                             uint8_t sectype,uint8_t secflags,
                             uint8_t secprot,int type)
/* return got/plt section, create new when missing */
{
  static const char fn[] = "elf_dyntable():";
  static const char *secname[] = { NULL, got_name, plt_name };
  struct Section *sec,**secp;
  struct ObjectUnit *ou;
  int symidx = -1;

  switch (type) {
    case GOT_ENTRY:
      secp = &gotsec;
      symidx = GLOBOFFSTAB;
      break;
    case PLT_ENTRY:
      secp = &pltsec;
      symidx = PROCLINKTAB;
      break;
    default:
      ierror("%s wrong type: %d",fn,type);
      break;
  }
  if (sec = *secp)
    return sec;

  if (gv->dynobj == NULL)
    ierror("%s no dynobj",fn);

  /* Section does not exist - create it.
     The offset field is used for the next table entry offset. */
  sec = add_section(gv->dynobj,(char *)secname[type],NULL,initial_size,
                    sectype,secflags,secprot,2,TRUE);
  sec->offset = initial_offset;
  *secp = sec;

  /* create _GLOBAL_OFFSET_TABLE_ or _PROCEDURE_LINKAGE_TABLE_ linker symbol */
  if (symidx >= 0) {
    if (!findlnksymbol(gv,elf_symnames[symidx]))
      elf_makelnksym(gv,symidx);
  }

  return sec;
}


void elf_adddynsym(struct Symbol *sym)
{
  if (sym->flags & SYMF_DYNIMPORT) {
    elf_addsym(&elfdsymlist,sym->name,0,0,STB_GLOBAL,STT_NOTYPE,SHN_UNDEF);
  }
  else if (sym->flags & SYMF_DYNEXPORT) {
    struct DynSymNode *dsn = alloc(sizeof(struct DynSymNode));

    /* section index and value need to be fixed later for these entries! */
    dsn->idx = elf_addsym(&elfdsymlist,sym->name,0,sym->size,
                          elf_getbind(sym),elf_getinfo(sym),0);
    dsn->sym = sym;
    addtail(&elfdynsymlist,&dsn->n);
  }
  else
    ierror("elf_adddynsym(): <%s> was not flagged as dynamic",sym->name);
}


void elf_dynreloc(struct ObjectUnit *ou,struct Reloc *r,int relafmt,
                  size_t elfrelsize)
{
  const char *secname;
  struct Section **secp;
  uint8_t dynflag = SYMF_DYNIMPORT;

  switch (r->rtype) {
    case R_COPY:
      dynflag = SYMF_DYNEXPORT;
      /* fall through */
    case R_GLOBDAT:
    case R_LOADREL:
      secp = &elfdynrelocs;
      secname = dynrel_name[relafmt?1:0];
      r->flags |= RELF_DYN;
      break;
    case R_JMPSLOT:
      secp = &elfpltrelocs;
      secname = pltrel_name[relafmt?1:0];
      r->flags |= RELF_PLT;
      break;
    case R_ABS:
      return;
    default:
      ierror("elf_dynreloc(): wrong rtype %s (%d)",
             reloc_name[r->rtype],(int)r->rtype);
      break;
  }

  /* make sure that dynamic relocation section exists */
  if (*secp == NULL)
    *secp = add_section(ou,secname,NULL,0,ST_DATA,SF_ALLOC,SP_READ,2,TRUE);

  /* increase size for new entry */
  (*secp)->size += elfrelsize;
  
  /* allocate referenced symbol in .dynsym and .dynstr */
  if (r->xrefname) {
    struct Symbol *sym = r->relocsect.symbol;

    if (!(sym->flags & SYMF_DYNLINK)) {
      /* add symbol to .dynsym symbol list, if not already present */
      sym->flags |= dynflag;
      elf_adddynsym(sym);
    }
  }
}


struct Section *elf_initdynlink(struct GlobalVars *gv)
{
  struct ObjectUnit *ou = gv->dynobj;
  struct Symbol *sym;
  struct Section *dynsec;

  /* set endianess for output file */
  elf_endianess = fff[gv->dest_format]->endianess;

  /* init dynamic symbol list */
  initlist(&elfdynsymlist);

  /* allocate .interp section for dynamically linked executables only */
  if (!gv->dest_sharedobj)
    add_section(ou,".interp",(uint8_t *)gv->interp_path,
                strlen(gv->interp_path)+1,ST_DATA,SF_ALLOC,SP_READ,0,TRUE);

  /* .hash, .dynsym, .dynstr and .dynamic are always present.
     Set them to an initial size. They will grow with dynamic symbols added. */
  add_section(ou,hash_name,NULL,0,ST_DATA,SF_ALLOC,SP_READ,2,TRUE);
  add_section(ou,dynsym_name,NULL,0,ST_DATA,SF_ALLOC,SP_READ,2,TRUE);
  add_section(ou,dynstr_name,NULL,0,ST_DATA,SF_ALLOC,SP_READ,0,TRUE);
  dynsec = add_section(ou,dyn_name,NULL,0,ST_DATA,SF_ALLOC,
                       SP_READ|SP_WRITE,2,TRUE);

  /* assign symbol _DYNAMIC the address of the .dynamic section */
  sym = elf_makelnksym(gv,DYNAMICSYM);
  sym->flags |= SYMF_DYNEXPORT;
  elf_adddynsym(sym);
  return dynsec;
}


struct Symbol *elf_pltgotentry(struct GlobalVars *gv,struct Section *sec,
                               DynArg a,uint8_t entrysymtype,
                               unsigned long offsadd,unsigned long sizeadd,
                               int etype,bool relaflag,
                               size_t relocsize,size_t addrsize)
/* Make a table entry for indirectly accessing a location from an external
   symbol defintion (GOT_ENTRY/PLT_ENTRY) or a local relocation (GOT_LOCAL).
   The entry has a size of offsadd bytes, while the table section sec will
   become sizeadd bytes larger per entry. */
{
  const char *fn = "elf_pltgotentry():";
  char entryname[MAXLEN];
  struct Symbol *tabsym;
  struct Section *refsec;
  unsigned long refoffs;

  /* determine reference section and offset of ext. symbol or local reloc */
  if (etype == GOT_LOCAL) {
    refsec = a.rel->relocsect.ptr;
    refoffs = a.rel->offset;
  }
  else {
    refsec = a.sym->relsect;
    refoffs = (unsigned long)a.sym->value;
  }

  /* generate internal symbol name for this reference */
  snprintf(entryname,MAXLEN," %s@%lx@%lx",
           sec->name,(unsigned long)refsec,refoffs);

  /* create internal symbol, or return old one, when already present */
  tabsym = addsymbol(gv,sec,allocstring(entryname),NULL,(lword)sec->offset,
                     SYM_RELOC,0,entrysymtype,SYMB_LOCAL,offsadd,FALSE);

  /* tabsym is NULL when it was just created, otherwise we already got it */
  if (tabsym == NULL) {
    static uint8_t dyn_reloc_types[] = { R_NONE,R_GLOBDAT,R_JMPSLOT,R_COPY };
    struct Reloc *r;
    uint8_t rtype;

    tabsym = findlocsymbol(gv,sec->obj,entryname);
    if (tabsym == NULL) {
      ierror("%s %s-symbol refering to %s+%lx disappeared",
             fn,sec->name,refsec->name,refoffs);
    }

    /* create a relocation for the new entry */
    if (etype == GOT_LOCAL) {
      /* local symbol: GOT relocation can be resolved now */
      r = newreloc(gv,sec,NULL,refsec,0,sec->offset,R_ABS,(lword)refoffs);
    }
    else {
      /* we need a dynamic linker relocation at the entry's offset */
      r = newreloc(gv,sec,a.sym->name,NULL,0,sec->offset,
                   dyn_reloc_types[etype],0);
      r->relocsect.symbol = a.sym;  /* resolve with external symbol */
      /* Possible enhancement: Find out whether referenced symbol resides
         in an uninitialized section, without a relocation, then we don't
         need an R_COPY relocation either! */
    }
    addreloc(sec,r,0,addrsize,-1);  /* size,mask only important for R_ABS */
    elf_dynreloc(gv->dynobj,r,relaflag,relocsize);

    /* increase offset and size counters of table-section */
    sec->offset += offsadd;
    sec->size += sizeadd;
  }

  return tabsym;
}


struct Symbol *elf_bssentry(struct GlobalVars *gv,const char *secname,
                            struct Symbol *xdef,bool relaflag,
                            size_t relocsize,size_t addrsize)
/* Allocate space for a copy-object in a .bss or .sbss section and create
   a R_COPY relocation to the original symbol in the shared object. */
{
  struct Symbol *newxdef;

  if (gv->dynobj == NULL)
    ierror("elf_bssentry(): no dynobj");
  newxdef = bss_entry(gv->dynobj,secname,xdef);

  if (newxdef) {
    /* entry in BSS was done, so we need a R_COPY relocation */
    struct Reloc *r;

    xdef = newxdef;
    r = newreloc(gv,xdef->relsect,xdef->name,NULL,0,0,R_COPY,0);
    r->relocsect.symbol = xdef;
    addreloc(xdef->relsect,r,0,addrsize,-1);  /* mask/size irrel. for R_COPY */
    elf_dynreloc(xdef->relsect->obj,r,relaflag,relocsize);
  }

  return xdef;
}


size_t elf_num_buckets(size_t symcount)
/* determine optimal number of buckets in dynamic symbol hash table */
{
  int i;
  size_t best_num;

  for (i=0; elf_buckets[i]; i++) {
    best_num = elf_buckets[i];
    if (symcount < elf_buckets[i+1])
      break;
  }
  return best_num;
}


void elf_putsymtab(uint8_t *p,struct SymTabList *sl)
/* write all SymTabList nodes sequentially into memory */
{
  size_t sz = sl->elfsymsize;
  struct SymbolNode *sym;

  while (sym = (struct SymbolNode *)remhead(&sl->l)) {
    memcpy(p,sym->elfsym,sz);
    p += sz;
  }
}


/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


unsigned long elf_numsegments(struct GlobalVars *gv)
{
  int segcnt = 0;
  struct Phdr *p = gv->phdrlist;

  while (p) {
    if (p->flags & PHDR_USED)
      segcnt++;
    p = p->next;
  }
  return segcnt;
}


uint8_t elf_getinfo(struct Symbol *sym)
{
  uint8_t type = STT_NOTYPE;

  switch (sym->info) {
    case SYMI_NOTYPE:
      break;  /* @@@ Is this allowed? */
    case SYMI_OBJECT:
      type = STT_OBJECT;
      break;
    case SYMI_FUNC:
      type = STT_FUNC;
      break;
    case SYMI_SECTION:
      ierror("elf_getinfo(): STT_SECTION symbol detected");
      type = STT_SECTION;
      break;
    case SYMI_FILE:
      type = STT_FILE;
      break;
    default:
      ierror("elf_getinfo(): Illegal symbol info: %d",(int)sym->info);
      break;
  }
  return type;
}


uint8_t elf_getbind(struct Symbol *sym)
{
  uint8_t bind = STB_GLOBAL;

  switch (sym->bind) {
    case SYMB_LOCAL:
      bind = STB_LOCAL;
      break;
    case SYMB_GLOBAL:
      bind = STB_GLOBAL;
      break;
    case SYMB_WEAK:
      bind = STB_WEAK;
      break;
    default:
      ierror("elf_getbind(): Illegal symbol binding: %d",(int)sym->bind);
      break;
  }
  return bind;
}


uint16_t elf_getshndx(struct GlobalVars *gv,
                      struct Symbol *sym,uint8_t symtype)
{
  uint16_t shndx = SHN_UNDEF;

  switch (sym->type) {
    case SYM_INDIR:
      /* can't reproduce unsupported symbol type */
      error(33,fff[gv->dest_format]->tname,sym->name,sym_bind[sym->bind],
            sym_type[sym->type],sym_info[sym->info]);
    case SYM_UNDEF:
      shndx = SHN_UNDEF;
      break;
    case SYM_ABS:
      shndx = SHN_ABS;
      break;
    case SYM_RELOC:
      if (symtype > STT_FUNC)
        ierror("elf_getshndx(): %s is relocatable, but not a "
               "function or object (type %d)",sym->name,(int)symtype);
      shndx = (uint16_t)sym->relsect->lnksec->index;
      break;
    case SYM_COMMON:
      shndx = SHN_COMMON;
      break;
    default:
      ierror("elf_getshndx(): Illegal symbol type: %d",(int)sym->type);
      break;
  }
  return shndx;
}


void elf_putstrtab(uint8_t *p,struct StrTabList *sl)
/* write all StrTabList nodes sequentially into memory */
{
  struct StrTabNode *stn;

  while (stn = (struct StrTabNode *)remhead(&sl->l)) {
    const char *s;
    char c;

    s = stn->str;
    do {
      c = *s++;
      *p++ = c;
    } while (c);
  }
}


uint32_t elf_addstrlist(struct StrTabList *sl,const char *s)
/* add a new string to an ELF string table and return its index */
{
  struct StrTabNode **chain,*sn;

  if (sl->hashtab == NULL) {
    /* initialize an unused string list */
    initlist(&sl->l);
    sl->hashtab = alloczero(sl->htabsize * sizeof(struct StrTabNode *));
    elf_addstrlist(sl,noname);
  }
  chain = &sl->hashtab[elf_hash(s) % sl->htabsize];

  /* search string in hash table */
  while (sn = *chain) {
    if (!strcmp(s,sn->str))
      return sn->index;  /* it's already in, return index */
    chain = &sn->hashchain;
  }

  /* new string table entry */
  *chain = sn = alloc(sizeof(struct StrTabNode));
  sn->hashchain = NULL;
  sn->str = s;
  sn->index = sl->nextindex;
  addtail(&sl->l,&sn->n);
  sl->nextindex += (uint32_t)strlen(s) + 1;

  return sn->index;
}


uint32_t elf_addshdrstr(const char *s)
{
  return elf_addstrlist(&elfshstrlist,s);
}


uint32_t elf_addstr(const char *s)
{
  return elf_addstrlist(&elfstringlist,s);
}


uint32_t elf_adddynstr(const char *s)
{
  return elf_addstrlist(&elfdstrlist,s);
}


uint32_t elf_addsym(struct SymTabList *sl,const char *name,uint64_t value,
                    uint64_t size,uint8_t bind,uint8_t type,uint16_t shndx)
{
  struct SymbolNode **chain,*sn;
  void *sym;

  if (name == NULL)  /* do nothing, return first index */
    return 0;

  chain = &sl->hashtab[elf_hash(name) % sl->htabsize];

  while (sn = *chain)
    chain = &sn->hashchain;

  /* new symbol table entry */
  *chain = sn = alloc(sizeof(struct SymbolNode));
  sn->hashchain = NULL;
  sn->name = name;
  sn->index = sl->nextindex++;
  sn->shndx = shndx;
  sn->elfsym = sym = alloc(sl->elfsymsize);
  addtail(&sl->l,&sn->n);

  /* initialize ELF symbol */
  sl->initsym(sym,elf_addstrlist(sl->strlist,name),value,size,
              bind,type,shndx,elf_endianess==_BIG_ENDIAN_);

  return sn->index;
}


void elf_initsymlist(struct SymTabList *sl,struct StrTabList *strl,
                     size_t tabsize,size_t symsize,
                     void (*init)(void *,uint32_t,uint64_t,uint64_t,
                                  uint8_t,uint8_t,uint16_t,bool))
{
  initlist(&sl->l);
  sl->htabsize = tabsize;
  sl->hashtab = alloczero(tabsize * sizeof(struct SymbolNode *));
  sl->strlist = strl;
  sl->elfsymsize = symsize;
  sl->initsym = init;
  sl->nextindex = sl->globalindex = 0;
  elf_addsym(sl,noname,0,0,0,0,SHN_UNDEF);
}


struct SymbolNode *elf_findSymNode(struct SymTabList *sl,const char *name)
/* Find an ELF symbol node by its name.
   Return pointer to it, or NULL when not found. */
{
  struct SymbolNode **chain = &sl->hashtab[elf_hash(name) % sl->htabsize];
  struct SymbolNode *sym;

  while (sym = *chain) {
    if (!strcmp(name,sym->name))
      return sym;
    chain = &sym->hashchain;
  }
  return NULL;
}


static uint32_t elf_findsymidx(struct SymTabList *sl,const char *name,
                               uint16_t shndx)
/* find an ELF symbol by its name and shndx */
/* return its symbol table index, index=0 means 'not found' */
{
  struct SymbolNode **chain = &sl->hashtab[elf_hash(name) % sl->htabsize];
  struct SymbolNode *sym;

  while (sym = *chain) {
    if (!strcmp(name,sym->name) && sym->shndx==shndx)
      return sym->index;
    chain = &sym->hashchain;
  }
  return 0;
}


uint32_t elf_extsymidx(struct SymTabList *sl,const char *name)
/* return index of external symbol with name from SymTabList */
{
  uint32_t symidx;

  if (!(symidx = elf_findsymidx(sl,name,SHN_COMMON)))
    if (!(symidx = elf_findsymidx(sl,name,SHN_UNDEF)))
      symidx = elf_addsym(sl,name,0,0,STB_GLOBAL,STT_NOTYPE,SHN_UNDEF);

  return symidx;
}


void elf_ident(void *p,bool be,uint8_t class,uint16_t type,uint16_t mach)
{
  struct Elf_CommonHdr *hdr = (struct Elf_CommonHdr *)p;

  strncpy((char *)hdr->e_ident,ELFid,4);
  hdr->e_ident[EI_CLASS] = class;
  hdr->e_ident[EI_DATA] = be ? ELFDATA2MSB : ELFDATA2LSB;
  hdr->e_ident[EI_VERSION] = ELF_VER;
  memset(&hdr->e_ident[EI_PAD],0,EI_NIDENT-EI_PAD);
  write16(be,hdr->e_type,type);
  write16(be,hdr->e_machine,mach);
  write32(be,hdr->e_version,ELF_VER);
}


void elf_addsymlist(struct GlobalVars *gv,struct SymTabList *sl,
                    uint8_t bind,uint8_t type)
/* add all symbols with specified bind and type to the ELF symbol list */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextls;
  struct Symbol *nextsym,*sym;

  while (nextls = (struct LinkedSection *)ls->n.next) {
    sym = (struct Symbol *)ls->symbols.first;

    while (nextsym = (struct Symbol *)sym->n.next) {
      uint8_t symtype = elf_getinfo(sym);
      uint8_t symbind = elf_getbind(sym);

      if (symbind == bind && (!type || (symtype == type))) {
        if (!discard_symbol(gv,sym)) {
          remnode(&sym->n);
          elf_addsym(sl,sym->name,sym->value,sym->size,symbind,symtype,
                     elf_getshndx(gv,sym,symtype));
        }
      }
      sym = nextsym;
    }
    ls = nextls;
  }
}


void elf_stdsymtab(struct GlobalVars *gv,uint8_t bind,uint8_t type)
{
  elf_addsymlist(gv,&elfsymlist,bind,type);
}


static uint16_t conv_perm_to_elf(uint8_t secperm)
/* converts vlink section permissions to ELF segment permissions */
{
  uint16_t elfperm = 0;

  if (secperm & SP_READ)
    elfperm |= PF_R;
  if (secperm & SP_WRITE)
    elfperm |= PF_W;
  if (secperm & SP_EXEC)
    elfperm |= PF_X;

  return elfperm;
}


uint32_t elf_segmentcheck(struct GlobalVars *gv,size_t ehdrsize)
/* 1. checks the PT_LOAD segments for intermediate uninitialized sections,
      which will be turned into initialized PROGBITS data sections
   2. sets segment permissions from contained sections
   3. calculates bytes to insert at beginning of segment to meet
      page-alignment restrictions
   4. initializes PT_PHDR segment
   Returns number of segments in list */
{
  unsigned long headersize = fff[gv->dest_format]->headersize(gv);
  struct Phdr *p,*phdrs,*first=NULL;
  struct LinkedSection *ls,*bss_start,*seg_lastdat,*seg_lastsec,*prg_lastdat;
  unsigned long foffs;
  uint32_t segcnt;

  /* find PHDR segment */
  for (phdrs=NULL,p=gv->phdrlist; p; p=p->next) {
    if ((p->flags&PHDR_USED) && p->type==PT_PHDR) {
      phdrs = p;
      break;
    }
  }

  for (p=gv->phdrlist,prg_lastdat=NULL; p; p=p->next) {
    if (p->type==PT_LOAD && (p->flags&PHDR_USED) &&
        p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {
      unsigned long amask = (1L << p->alignment) - 1;
      long gapsize;

      bss_start = seg_lastsec = NULL;
      p->flags &= ~PHDR_PFMASK;
      p->flags |= PF_R;  /* at least 'read' should be allowed */

      /* determine initial file offset for first segment */
      if (!first) {
        first = p;
        if (phdrs) {  /* header is included in first segment */
          p->flags |= PHDR_PHDRS | PHDR_FILEHDR;
          foffs = 0;
          elf_file_hdr_gap = (unsigned long)p->start -
                             ((unsigned long)(p->start-headersize) & ~amask) -
                             headersize;
          p->start -= headersize + elf_file_hdr_gap;
          if (p->start_vma)
            p->start_vma -= headersize + elf_file_hdr_gap;
        }
        else
          foffs = headersize;  /* first segment starts after header */
      }

      for (ls=(struct LinkedSection *)gv->lnksec.first,
            seg_lastdat=NULL,seg_lastsec=NULL;
           ls->n.next!=NULL;
           ls=(struct LinkedSection *)ls->n.next) {

        if (ls->copybase>=(unsigned long)p->start && ls->size &&
            (ls->copybase+ls->size)<=(unsigned long)p->mem_end &&
            (ls->flags & SF_ALLOC)) {

          p->flags |= conv_perm_to_elf(ls->protection);
          if (ls->alignment > p->alignment)
            p->alignment = ls->alignment;

          if (ls->flags & SF_UNINITIALIZED) {
            if (!bss_start)
              bss_start = ls;
          }
          else {
            if (bss_start) {
              struct LinkedSection *bssls;

              for (bssls=bss_start; bssls!=ls;
                   bssls=(struct LinkedSection *)bssls->n.next) {
                bssls->flags &= ~SF_UNINITIALIZED;
                if (bssls->type == ST_UDATA)
                  bssls->type = ST_DATA;
                bssls->filesize = bssls->size;
              }
              /* Warning: Intermediate uninitialized sections in ELF
                 segment will be turned into initialized */
              error(82,p->name,bss_start->name,
                    ((struct LinkedSection *)ls->n.pred)->name);
              bss_start = NULL;
            }
          }

          if (seg_lastsec && !bss_start) {
            if (ls->copybase >= seg_lastsec->copybase+seg_lastsec->filesize) {
              seg_lastsec->gapsize = ls->copybase - (seg_lastsec->copybase +
                                                     seg_lastsec->filesize);
            }
            else if (ls->copybase > 0) {
              ierror("elf_segmentcheck(): overlapping sections "
                     "%s(%lx-%lx) followed by %s(%lx)",
                     seg_lastsec->name,seg_lastsec->copybase,
                     seg_lastsec->copybase + seg_lastsec->filesize,
                     ls->copybase);
            }
          }
          seg_lastsec = ls;
          if (!bss_start || !seg_lastdat)
            prg_lastdat = seg_lastdat = ls;
        }
      }

      /* calculate alignment gap for segment */
      /* @@@ do we align on LMA or VMA? */
      gapsize = (p->start & amask) - (foffs & amask);
      p->alignment_gap = gapsize<0 ? gapsize+amask+1 : gapsize;

      if (seg_lastdat)
        p->file_end = seg_lastdat->copybase + seg_lastdat->filesize;

      foffs += p->alignment_gap;
      p->offset = foffs;
      foffs += p->file_end - p->start;
    }
  }

  if (phdrs!=NULL && first!=NULL) {
    /* init PHDR segment using the first LOAD seg. which directly follows */
    phdrs->flags &= ~PHDR_PFMASK;
    phdrs->flags |= PF_R | PF_X;
    phdrs->start = first->start + ehdrsize;
    phdrs->start_vma = phdrs->start;
    phdrs->mem_end = phdrs->start + headersize - ehdrsize;
    phdrs->file_end = phdrs->mem_end;
    phdrs->offset = ehdrsize;
  }

  for (p=gv->phdrlist,segcnt=0; p; p=p->next) {
    if ((p->flags&PHDR_USED)
        && p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {
      segcnt++;

      if (p->type!=PT_LOAD && p->type!=PT_PHDR && p->type!=PT_NULL) {
        /* set segment permissions for remaining segment types */
        p->flags &= ~PHDR_PFMASK;
        for (ls=seg_lastdat=(struct LinkedSection *)gv->lnksec.first;
             ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
          if (ls->copybase>=(unsigned long)p->start && ls->size &&
              (ls->copybase+ls->size)<=(unsigned long)p->mem_end &&
              (ls->flags & SF_ALLOC)) {
            p->flags |= conv_perm_to_elf(ls->protection);
            seg_lastdat = ls;
          }
        }
        p->file_end = seg_lastdat->copybase + seg_lastdat->filesize;
      }
    }
  }

  return segcnt;
}


void elf_makeshdrs(struct GlobalVars *gv,
                   void (*addsecshdr)(struct LinkedSection *,bool,uint64_t))
/* generate all ELF section headers */
{
  struct Phdr *p,*p2;
  struct LinkedSection *ls;
  unsigned long poffs;

  /* offset, to find section-symbols by section header index */
  secsyms = (int)elfsymlist.nextindex - (int)elfshdridx;

  /* reset index */
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next)
    ls->index = 0;

  for (p=gv->phdrlist; p; p=p->next) {
    if (p->type==PT_LOAD && (p->flags&PHDR_USED) &&
        p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {
      /* check file offset for current segment */
      elfoffset += p->alignment_gap;
      poffs = p->offset;
      if (p->flags & (PHDR_PHDRS|PHDR_FILEHDR)) {
        poffs += fff[gv->dest_format]->headersize(gv) + elf_file_hdr_gap;
        elfoffset += elf_file_hdr_gap;
      }
      if (poffs != elfoffset) {
        ierror("elf32_makeshdrs(): PHDR \"%s\" offs %lu != %lu\n",
               p->name,poffs,elfoffset);
      }

      /* find sections which belong to this segment and set their index */
      for (ls=(struct LinkedSection *)gv->lnksec.first;
           ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
        if (ls->copybase>=(unsigned long)p->start &&
            (ls->copybase+ls->size)<=(unsigned long)p->mem_end &&
            (ls->flags & SF_ALLOC) && ls->index==0) {
          uint32_t f = SHF_ALLOC;
          bool bss = ls->type==ST_UDATA || (ls->flags&SF_UNINITIALIZED);

          ls->index = (int)elfshdridx;
          f |= (ls->protection & SP_WRITE) ? SHF_WRITE : 0;
          f |= (ls->protection & SP_EXEC) ? SHF_EXECINSTR : 0;
          addsecshdr(ls,bss,f);

          /* check if section included in other non-LOAD segments as well */
          for (p2=gv->phdrlist; p2; p2=p2->next) {
            if (p2->type!=PT_LOAD && (p2->flags&PHDR_USED) &&
                p2->start==(lword)ls->copybase)
              p2->offset = elfoffset;
          }

          /* update file offset */
          if (gv->dest_object) {
            if (!bss)
              elfoffset += ls->size;
          }
          else {
            elfoffset += ls->filesize + ls->gapsize;
          }

          /* add section symbol (without name) */
          elf_addsym(&elfsymlist,noname,ls->base,0,STB_LOCAL,STT_SECTION,
                     ls->index);
        }
      }
    }
  }

  /* unallocated sections at last */
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    if (ls->index == 0) {
      uint32_t f = 0;
      bool bss = ls->type==ST_UDATA || (ls->flags&SF_UNINITIALIZED);

      ls->index = (int)elfshdridx;
      f |= (ls->protection & SP_WRITE) ? SHF_WRITE : 0;
      f |= (ls->protection & SP_EXEC) ? SHF_EXECINSTR : 0;
      addsecshdr(ls,bss,f);
      /* update file offset */
      if (!bss)
        elfoffset += ls->size;
      /* add section symbol (without name) */
      elf_addsym(&elfsymlist,noname,ls->base,0,STB_LOCAL,STT_SECTION,ls->index);
    }
  }
}


struct RelocList *elf_newreloclist(size_t relasize,size_t writesize,
                                   void (*initfunc)(void *,uint64_t,uint64_t,
                                                    uint32_t,uint32_t,bool))
{
  struct RelocList *rl = alloc(sizeof(struct RelocList));

  initlist(&rl->l);
  rl->relasize = relasize;
  rl->writesize = writesize;
  rl->initreloc = initfunc;
  return rl;
}


void elf_addrelocnode(struct RelocList *rl,uint64_t offset,uint64_t addend,
                      uint32_t symidx,uint32_t type,bool be)
{
  struct RelocNode *rn = alloc(sizeof(struct RelocNode));
  void *elfrel = alloc(rl->relasize);

  rl->initreloc(elfrel,offset,addend,symidx,type,be);
  rn->elfreloc = elfrel;
  addtail(&rl->l,&rn->n);
}


size_t elf_addrela(struct GlobalVars *gv,struct LinkedSection *ls,
                   struct Reloc *rel,bool be,struct RelocList *reloclist,
                   uint8_t (*reloc_vlink2elf)(struct Reloc *))
{
  uint32_t symidx;
  uint8_t rtype;

  if (rel->flags & RELF_INTERNAL)
    return 0;  /* internal relocations will never be exported */

  if (rel->xrefname) {
    symidx = elf_extsymidx(&elfsymlist,rel->xrefname);
  }
  else {
    if (rel->relocsect.lnk == NULL) {
      if (!(rel->flags & RELF_DYNLINK))
        return 0;  /* ignore, because it was resolved by a shared object */
      else
        ierror("elf_addrela(): Reloc type %d (%s) at %s+0x%lx (addend 0x%llx)"
               " is missing a relocsect.lnk",(int)rel->rtype,
               reloc_name[rel->rtype],ls->name,rel->offset,rel->addend);
    }
    symidx = (uint32_t)(rel->relocsect.lnk->index + secsyms);
  }

  if (!(rtype = reloc_vlink2elf(rel))) {
    struct RelocInsert *ri;

    if (ri = rel->insert)
      error(32,fff[gv->dest_format]->tname,reloc_name[rel->rtype],
            (int)ri->bpos,(int)ri->bsiz,ri->mask,ls->name,rel->offset);
    else
      ierror("elf_addrela(): Reloc without insert-field");
  }

  elf_addrelocnode(reloclist,ls->base+rel->offset,rel->addend,symidx,rtype,be);
  writesection(gv,ls->data+rel->offset,rel,
               gv->reloctab_format==RTAB_ADDEND ? 0 : rel->addend);
  return reloclist->writesize;
}
      

void elf_initoutput(struct GlobalVars *gv,
                    uint32_t init_file_offset,int8_t output_endianess)
/* initialize section header, program header, relocation, symbol, */
/* string and section header string lists */
{
  elf_endianess = output_endianess;
  elfoffset = init_file_offset;
  elf_file_hdr_gap = 0;

  if (gv->phdrlist == NULL) {
    /* we need to provide at least one dummy PHDR, even for reloc-objects */
    struct Phdr *p = alloczero(sizeof(struct Phdr));

    p->type = PT_LOAD;
    p->flags = PF_X|PF_W|PF_R|PHDR_USED;
    p->mem_end = p->file_end = 0xffffffff;
    p->offset = fff[gv->dest_format]->headersize(gv);
    gv->phdrlist = p;
  }

  initlist(&shdrlist);
  initlist(&phdrlist);
  elfshdridx = 0;

  elfsymtabidx = elf_addshdrstr(".symtab");
  elfstrtabidx = elf_addshdrstr(".strtab");
  elfshstrtabidx = elf_addshdrstr(".shstrtab");
}


void elf_initsymtabs(size_t symsize,
                     void (*init)(void *,uint32_t,uint64_t,uint64_t,
                                  uint8_t,uint8_t,uint16_t,bool))
{
  if (elfsymlist.htabsize == 0)
    elf_initsymlist(&elfsymlist,&elfstringlist,SYMHTABSIZE,symsize,init);

  if (elfdsymlist.htabsize == 0)
    elf_initsymlist(&elfdsymlist,&elfdstrlist,DYNSYMHTABSIZE,symsize,init);
}


void elf_writesegments(struct GlobalVars *gv,FILE *f)
/* write all PT_LOAD segments, with alignment gaps, etc. */
{
  struct Phdr *p;
  struct LinkedSection *ls;

  for (p=gv->phdrlist; p; p=p->next) {
    if (p->type==PT_LOAD && (p->flags&PHDR_USED) &&
        p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {
      /* write page-alignment gap */
      fwritegap(f,p->alignment_gap);

      /* write section contents */
      for (ls=(struct LinkedSection *)gv->lnksec.first;
           ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
        if (ls->copybase>=(unsigned long)p->start &&
            (ls->copybase+ls->size)<=(unsigned long)p->mem_end &&
            (ls->flags & SF_ALLOC)) {
          if (ls->filesize)
            fwritex(f,ls->data,ls->filesize);  /* section's contents */
          if (ls->gapsize)
            fwritegap(f,ls->gapsize);  /* inter-section alignment gap */
        }
      }
    }
  }

  /* unallocated sections at last */
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    if (!(ls->flags & SF_ALLOC)) {
      if (!(ls->flags & SF_UNINITIALIZED))
        fwritex(f,ls->data,ls->size);
    }
  }
}


void elf_writesections(struct GlobalVars *gv,FILE *f)
/* write all linked sections */
{
  struct LinkedSection *ls;

  /* write all allocated sections */
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    if (ls->flags & SF_ALLOC) {
      if (!(ls->flags & SF_UNINITIALIZED))
        fwritex(f,ls->data,ls->size);
    }
  }
  /* unallocated sections at last */
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    if (!(ls->flags & SF_ALLOC)) {
      if (!(ls->flags & SF_UNINITIALIZED))
        fwritex(f,ls->data,ls->size);
    }
  }
}


void elf_writestrtab(FILE *f,struct StrTabList *sl)
{
  struct StrTabNode *stn;

  while (stn = (struct StrTabNode *)remhead(&sl->l))
    fwritex(f,stn->str,strlen(stn->str)+1);
}


void elf_writesymtab(FILE *f,struct SymTabList *sl)
{
  size_t sz = sl->elfsymsize;
  struct SymbolNode *sym;

  while (sym = (struct SymbolNode *)remhead(&sl->l))
    fwritex(f,sym->elfsym,sz);
}


void elf_writerelocs(FILE *f,struct RelocList *rl)
{
  size_t sz = rl->writesize;
  struct RelocNode *rn;

  while (rn = (struct RelocNode *)remhead(&rl->l))
    fwritex(f,rn->elfreloc,sz);
}


#endif  /* ELF32 || ELF64 */
