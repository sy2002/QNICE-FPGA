/* $VER: vlink t_elf32.c V0.14 (29.07.11)
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
#ifdef ELF32
#define T_ELF32_C
#include "vlink.h"
#include "elf32.h"
#include "stabdefs.h"


/* static data required for output file generation */
static struct RelocList *reloclist;
static struct Section *dynamic;
/* .hash table */
static struct SymbolNode **dyn_hash;
static size_t dyn_hash_entries;
/* stabs */
static struct ShdrNode *stabshdr;
static struct list stabcompunits;
static uint32_t stabdebugidx;



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static struct Elf32_Shdr *elf32_shdr(struct LinkFile *lf,
                                     struct Elf32_Ehdr *ehdr,uint16_t idx)
/* return pointer to section header #idx */
{
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct Elf32_Shdr *shdr;

  if (idx < read16(be,ehdr->e_shnum)) {
    shdr = (struct Elf32_Shdr *)(((char *)ehdr) + ((read32(be,ehdr->e_shoff) +
           (uint32_t)read16(be,ehdr->e_shentsize) * (uint32_t)idx)));
    if (((uint8_t *)shdr < lf->data) ||
        (((uint8_t *)shdr)+read16(be,ehdr->e_shentsize) > lf->data+lf->length))
      /* section header #x has illegal offset */
      error(44,lf->pathname,(int)idx,lf->objname);
    return shdr;
  }
  else  /* Invalid ELF section header index */
    error(43,lf->pathname,(int)idx,lf->objname);
  return NULL;  /* not reached, for compiler's sake */
}


static char *elf32_shstrtab(struct LinkFile *lf,struct Elf32_Ehdr *ehdr)
/* returns a pointer to the section header string table, if present, */
/* or NULL, otherwise */
{
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  uint16_t i;
  struct Elf32_Shdr *shdr;
  char *stab;

  if (i = read16(be,ehdr->e_shstrndx)) {
    shdr = elf32_shdr(lf,ehdr,i);
    if (read32(be,shdr->sh_type) != SHT_STRTAB)
      error(45,lf->pathname,lf->objname);  /* illegal type */
    stab = ((char *)ehdr) + read32(be,shdr->sh_offset);
    if (((uint8_t *)stab < lf->data) || 
        ((uint8_t *)stab + read32(be,shdr->sh_size) > lf->data + lf->length))
      error(46,lf->pathname,lf->objname);  /* illegal offset */
    else
      return stab;
  }
  return NULL;
}


static char *elf32_strtab(struct LinkFile *lf,struct Elf32_Ehdr *ehdr,int idx)
/* returns a pointer to the string table */
{
  static char *tabname = "string";
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct Elf32_Shdr *shdr;
  char *stab;

  shdr = elf32_shdr(lf,ehdr,idx);
  if (read32(be,shdr->sh_type) != SHT_STRTAB)
     error(50,lf->pathname,tabname,lf->objname);  /* illegal type */
  stab = ((char *)ehdr) + read32(be,shdr->sh_offset);
  elf_check_offset(lf,tabname,stab,read32(be,shdr->sh_size));
  return stab;
}


static struct Elf32_Sym *elf32_symtab(struct LinkFile *lf,
                                      struct Elf32_Ehdr *ehdr,int idx)
/* returns a pointer to the symbol table */
{
  static char *tabname = "symbol";
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct Elf32_Shdr *shdr;
  struct Elf32_Sym *symtab;
  uint32_t shtype;

  shdr = elf32_shdr(lf,ehdr,idx);
  shtype = read32(be,shdr->sh_type);
  if (shtype!=SHT_SYMTAB && shtype!=SHT_DYNSYM)
     error(50,lf->pathname,tabname,lf->objname);  /* illegal type */
  symtab = (struct Elf32_Sym *)((uint8_t *)ehdr + read32(be,shdr->sh_offset));
  elf_check_offset(lf,tabname,symtab,read32(be,shdr->sh_size));
  return symtab;
}


static void elf32_section(struct GlobalVars *gv,struct Elf32_Ehdr *ehdr,
                          struct ObjectUnit *ou,struct Elf32_Shdr *shdr,
                          int shndx,char *shstrtab)
/* create a new section */
{
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct Section *s;

  if (s = elf_add_section(gv,ou,
                          shstrtab+read32(be,shdr->sh_name),
                          (uint8_t *)ehdr+read32(be,shdr->sh_offset),
                          read32(be,shdr->sh_size),
                          read32(be,shdr->sh_type),
                          read32(be,shdr->sh_flags),
                          shiftcnt(read32(be,shdr->sh_addralign)))) {
    s->link = read32(be,shdr->sh_link);  /* save link for later use */
    s->id = shndx;  /* use section header index for identification */
  }
}


static void elf32_symbols(struct GlobalVars *gv,struct Elf32_Ehdr *ehdr,
                          struct ObjectUnit *ou,struct Elf32_Shdr *shdr)
/* convert ELF symbol definitions into internal format */
{
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct LinkFile *lf = ou->lnkfile;
  uint8_t *data = (uint8_t *)ehdr + read32(be,shdr->sh_offset);
  unsigned long entsize = read32(be,shdr->sh_entsize);
  int nsyms = (int)(read32(be,shdr->sh_size) / (uint32_t)entsize);
  char *strtab = elf32_strtab(lf,ehdr,read32(be,shdr->sh_link));

  elf_check_offset(lf,"symbol",data,read32(be,shdr->sh_size));

  /* read ELF xdef symbols and convert to internal format */
  while (--nsyms > 0) {
    struct Elf32_Sym *elfsym;
    char *symname;

    elfsym = (struct Elf32_Sym *)(data += entsize);
    symname = strtab + read32(be,elfsym->st_name);
    if (symname<(char *)lf->data || symname>(char *)lf->data+lf->length)
      error(127,lf->pathname,read32(be,elfsym->st_name),lf->objname);

    elf_add_symbol(gv,ou,symname,
                   (read32(be,shdr->sh_type)==SHT_DYNSYM) ? SYMF_SHLIB : 0,
                   read16(be,elfsym->st_shndx),
                   read32(be,shdr->sh_type),
                   ELF32_ST_TYPE(*elfsym->st_info),
                   ELF32_ST_BIND(*elfsym->st_info),
                   (int32_t)read32(be,elfsym->st_value),
                   read32(be,elfsym->st_size));
  }
}


static void elf32_dynrefs(struct GlobalVars *gv,struct Elf32_Ehdr *ehdr,
                          struct ObjectUnit *ou,struct Elf32_Shdr *shdr,
                          bool be,
                          uint8_t (*reloc_elf2vlink)(uint8_t,struct RelocInsert *))
/* Find all relocs in a shared object which refer to an undefined symbol. */
{
  uint8_t *data = (uint8_t *)ehdr + read32(be,shdr->sh_offset);
  unsigned long entsize = read32(be,shdr->sh_entsize);
  uint32_t symndx = read32(be,shdr->sh_link);
  int nrelocs = (int)(read32(be,shdr->sh_size) / (uint32_t)entsize);
  struct LinkFile *lf = ou->lnkfile;
  struct Section *sec;
  struct Reloc *r;

  elf_check_offset(lf,"reloc",data,read32(be,shdr->sh_size));

  /* just put all xrefs into the first section of the shared object */
  sec = abs_section(ou);

  for (; nrelocs; nrelocs--,data+=entsize) {
    struct Elf32_Rela *elfrel = (struct Elf32_Rela *)data;
    struct Elf32_Shdr *symhdr = elf32_shdr(lf,ehdr,symndx);
    struct Elf32_Sym *sym = elf32_symtab(lf,ehdr,symndx) +
                            ELF32_R_SYM(read32(be,elfrel->r_info));
    uint32_t shndx = (uint32_t)read16(be,sym->st_shndx);
    struct RelocInsert ri,*ri_ptr;
    uint8_t rtype;

    if (shndx == SHN_UNDEF || shndx == SHN_COMMON) {
      memset(&ri,0,sizeof(struct RelocInsert));
      rtype = reloc_elf2vlink(ELF32_R_TYPE(read32(be,elfrel->r_info)),&ri);
      if (rtype == R_NONE)
        continue;
      r = newreloc(gv,sec,elf32_strtab(lf,ehdr,read32(be,symhdr->sh_link))
                   + read32(be,sym->st_name),
                   NULL,0,read32(be,elfrel->r_offset),rtype,0);
      for (ri_ptr=&ri; ri_ptr; ri_ptr=ri_ptr->next)
        addreloc(sec,r,ri_ptr->bpos,ri_ptr->bsiz,ri_ptr->mask);

      /* referenced symbol is weak? */
      if (ELF32_ST_BIND(*sym->st_info)==STB_WEAK)
        r->flags |= RELF_WEAK;
    }
  }
}


static void elf32_reloc(struct GlobalVars *gv,struct Elf32_Ehdr *ehdr,
                        struct ObjectUnit *ou,struct Elf32_Shdr *shdr,
                        char *shstrtab,bool be,
                        uint8_t (*reloc_elf2vlink)(uint8_t,struct RelocInsert *))
/* Read ELF32 relocations, which are relative to a defined symbol, into
   the section's reloc-list. If the symbol is undefined, create an
   external reference on it, with the supplied relocation type. */
{
  uint8_t *data = (uint8_t *)ehdr + read32(be,shdr->sh_offset);
  bool is_rela = read32(be,shdr->sh_type) == SHT_RELA;
  unsigned long entsize = read32(be,shdr->sh_entsize);
  uint32_t symndx = read32(be,shdr->sh_link);
  int nrelocs = (int)(read32(be,shdr->sh_size) / (uint32_t)entsize);
  char *sec_name = shstrtab + read32(be,shdr->sh_name);
  struct LinkFile *lf = ou->lnkfile;
  struct Section *sec;

  if (gv->strip_symbols>=STRIP_DEBUG &&
      (!strncmp(sec_name,".rel.debug",10) ||
       !strncmp(sec_name,".rel.stab",9) ||
       !strncmp(sec_name,".rela.debug",11) ||
       !strncmp(sec_name,".rela.stab",10)))
    return;   /* ignore debugging sections when -S or -s is given */

  elf_check_offset(lf,"reloc",data,read32(be,shdr->sh_size));

  if (!(sec = find_sect_id(ou,read32(be,shdr->sh_info)))) {
    /* a section with this index doesn't exist! */
    error(52,lf->pathname,shstrtab + read32(be,shdr->sh_name),
          getobjname(ou),(int)read32(be,shdr->sh_info));
  }

  for (; nrelocs; nrelocs--,data+=entsize) {
    struct Elf32_Rela *elfrel = (struct Elf32_Rela *)data;
    struct Elf32_Shdr *symhdr = elf32_shdr(lf,ehdr,symndx);
    struct Elf32_Sym *sym = elf32_symtab(lf,ehdr,symndx) +
                            ELF32_R_SYM(read32(be,elfrel->r_info));
    uint32_t offs = read32(be,elfrel->r_offset);
    uint32_t shndx = (uint32_t)read16(be,sym->st_shndx);
    char *xrefname = NULL;
    struct Section *relsec=NULL;
    struct Reloc *r;
    struct RelocInsert ri,*ri_ptr;
    lword a;
    uint8_t rtype;

    memset(&ri,0,sizeof(struct RelocInsert));
    rtype = reloc_elf2vlink(ELF32_R_TYPE(read32(be,elfrel->r_info)),&ri);
    if (rtype == R_NONE)
      continue;

    /* if addend is not defined in Reloc, read it directly from the section */
    if (is_rela)
      a = (int32_t)read32(be,elfrel->r_addend);
    else
      a = (int32_t)readsection(gv,rtype,sec->data+offs,ri.bpos,ri.bsiz,ri.mask);

    if (shndx == SHN_UNDEF || shndx == SHN_COMMON) {
      /* undefined or common symbol - create external reference */
      xrefname = elf32_strtab(lf,ehdr,read32(be,symhdr->sh_link)) +
                              read32(be,sym->st_name);
      relsec = NULL;
    }
    else if (ELF32_ST_TYPE(*sym->st_info) == STT_SECTION) {
      /* a normal relocation, with an offset relative to a section base */
      relsec = find_sect_id(ou,shndx);
    }
    else if (ELF32_ST_TYPE(*sym->st_info)<STT_SECTION && shndx<SHN_ABS) {
      /* relocations, which are relative to a known symbol */
      relsec = find_sect_id(ou,shndx);
      a += (lword)read32(be,sym->st_value);
    }
    else
      ierror("elf32_reloc(): %s (%s): Only relocations which are relative "
             "to a section, function or object are supported "
             "(sym=%s, ST_TYPE=%d)",lf->pathname,lf->objname,
             elf32_strtab(lf,ehdr,read32(be,symhdr->sh_link)) +
                          read32(be,sym->st_name),
             ELF32_ST_TYPE(*sym->st_info));

    r = newreloc(gv,sec,xrefname,relsec,0,(unsigned long)offs,rtype,a);
    for (ri_ptr=&ri; ri_ptr; ri_ptr=ri_ptr->next)
      addreloc(sec,r,ri_ptr->bpos,ri_ptr->bsiz,ri_ptr->mask);

    /* referenced symbol is weak? */
    if (xrefname!=NULL && ELF32_ST_BIND(*sym->st_info)==STB_WEAK)
      r->flags |= RELF_WEAK;

    /* make sure that section data reflects this addend for other formats */
    if (is_rela)
      writesection(gv,sec->data+offs,r,a);
  }
}


static void elf32_stabs(struct GlobalVars *gv,struct LinkFile *lf,
                        struct Elf32_Ehdr *ehdr,struct ObjectUnit *ou)
/* find .stabstr belonging to .stab, convert everything (including
   .rela.stab) into internal format and delete *.stab* afterwards. */
{
  static const char *fn = "elf32_stabs";
  static const char *stabname = "stab";
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct Section *stabsec;

  if (stabsec = find_sect_name(ou,".stab")) {
    char *strtab = elf32_strtab(lf,ehdr,stabsec->link);
    struct nlist32 *nlst = (struct nlist32 *)stabsec->data;
    long nlstlen = (long)stabsec->size;

    while (nlstlen >= sizeof(struct nlist32)) {
      /* next compilation unit: */
      /* read number of nlist records and size of string table */
      int cnt = (int)read16(be,&nlst->n_desc);
      uint32_t strtabsize = read32(be,&nlst->n_value);
      uint32_t funstart = 0;  /* start address of last function definition */
      struct Section *funsec = NULL;

      nlst++;
      nlstlen -= sizeof(struct nlist32);

      while (cnt--) {
        struct Reloc *r;
        struct Section *relsec;
        char *name;
        uint32_t val;

        if (nlstlen < sizeof(struct nlist32))
          error(118,lf->pathname,stabname,lf->objname);  /* malformatted */

        if (nlst->n_strx)
          name = strtab + read32(be,&nlst->n_strx);
        else
          name = NULL;

        switch (nlst->n_type & N_TYPE) {
          case N_TEXT:
          case N_DATA:
          case N_BSS:
            if (r = findreloc(stabsec,
                              (uint8_t *)&nlst->n_value - stabsec->data)) {
              if (r->rtype!=R_ABS || r->insert->bsiz!=32)
                ierror("%s: Bad .stab relocation",fn);
              relsec = r->relocsect.ptr;
              val = (uint32_t)r->addend;
              break;
            }
          default:
            relsec = NULL;
            val = read32(be,&nlst->n_value);
            break;
        }

        switch (nlst->n_type) {
          case N_FUN:
            if (nlst->n_strx) {
              if (relsec) {  /* function start is always relocatable */
                funsec = relsec;
                funstart = val;
              }
              else
                ierror("%s: N_FUN without relocatable address",fn);
            }
            else {  /* no name marks function end, still relative */
              relsec = funsec;
              val += funstart;
            }
            break;
          case N_SLINE:
            if (relsec == NULL) {
              relsec = funsec;
              val += funstart;
            }
            break;
        }

        addstabs(ou,relsec,name,nlst->n_type,nlst->n_other,
                 (int16_t)read16(be,&nlst->n_desc),val);
        nlst++;
        nlstlen -= sizeof(struct nlist32);
      }

      strtab += strtabsize;
    }
    if (nlstlen)
      error(118,lf->pathname,stabname,lf->objname);  /* ignoring junk */

    /* remove .stab from this object unit - will be recreated later */
    remnode(&stabsec->n);
  }
}


void elf32_parse(struct GlobalVars *gv,struct LinkFile *lf,
                 struct Elf32_Ehdr *ehdr,
                 uint8_t (*reloc_elf2vlink)(uint8_t,struct RelocInsert *))
/* parses a complete ELF file and converts into vlink-internal format */
{
  static const char *fn = "elf32_parse(): ";
  bool be = (ehdr->e_ident[EI_DATA] == ELFDATA2MSB);
  struct ObjectUnit *u;
  struct Elf32_Shdr *shdr;
  uint16_t i,num_shdr,dynstr_idx,dynsym_idx;
  char *shstrtab,*dynstrtab;
  struct Elf32_Dyn *dyn;

  shstrtab = elf32_shstrtab(lf,ehdr);
  u = create_objunit(gv,lf,lf->objname);

  switch (read16(be,ehdr->e_type)) {

    case ET_REL:  /* relocatable object file */
      if (read16(be,ehdr->e_phnum) > 0)
        error(47,lf->pathname,lf->objname);  /* ignoring program hdr. tab */
      num_shdr = read16(be,ehdr->e_shnum);

      /* create vlink sections */
      for (i=1; i<num_shdr; i++) {
        shdr = elf32_shdr(lf,ehdr,i);

        switch (read32(be,shdr->sh_type)) {
          case SHT_PROGBITS:
          case SHT_NOBITS:
          case SHT_NOTE:
            /* create a new section */
            elf32_section(gv,ehdr,u,shdr,i,shstrtab);
          default:
            break;
        }
      }

      /* parse the other section headers */
      for (i=1; i<num_shdr; i++) {
        shdr = elf32_shdr(lf,ehdr,i);

        switch (read32(be,shdr->sh_type)) {
          case SHT_NULL:
          case SHT_STRTAB:
          case SHT_NOTE:
          case SHT_PROGBITS:
          case SHT_NOBITS:
            break;
          case SHT_SYMTAB:
            elf32_symbols(gv,ehdr,u,shdr);  /* symbol definitions */
            break;
          case SHT_REL:
          case SHT_RELA:
            elf32_reloc(gv,ehdr,u,shdr,shstrtab,be,reloc_elf2vlink);
            break;
          default:
            /* section header type not needed in relocatable objects */
            error(48,lf->pathname,read32(be,shdr->sh_type),lf->objname);
            break;
        }
      }

      elf32_stabs(gv,lf,ehdr,u);  /* convert .stab into internal format */
      break;


    case ET_DYN:  /* shared object file */
      dynstrtab = NULL;
      dyn = NULL;
      dynstr_idx = dynsym_idx = 0;
      num_shdr = read16(be,ehdr->e_shnum);

      /* create vlink sections */
      for (i=1; i<num_shdr; i++) {
        shdr = elf32_shdr(lf,ehdr,i);

        switch (read32(be,shdr->sh_type)) {
          case SHT_DYNAMIC:
            /* remember pointer to .dynamic section contents */
            dyn = (struct Elf32_Dyn *)((uint8_t *)ehdr
                                       + read32(be,shdr->sh_offset));
            break;
          case SHT_DYNSYM:
            dynsym_idx = i;
            break;
          case SHT_PROGBITS:
          case SHT_NOBITS:
            /* create a new section */
            elf32_section(gv,ehdr,u,shdr,i,shstrtab);
          default:
            break;
        }
      }

      /* parse the other section headers */
      for (i=1; i<num_shdr; i++) {
        shdr = elf32_shdr(lf,ehdr,i);

        switch (read32(be,shdr->sh_type)) {
          case SHT_NULL:
          case SHT_STRTAB:
          case SHT_NOTE:
          case SHT_PROGBITS:
          case SHT_NOBITS:
          case SHT_HASH:
          case SHT_DYNAMIC:
          case SHT_SYMTAB:
            break;
          case SHT_DYNSYM:
            dynstr_idx = read32(be,shdr->sh_link);
            elf32_symbols(gv,ehdr,u,shdr);  /* symbol definitions */
            break;
          case SHT_REL:
          case SHT_RELA:
            if (fff[gv->dest_format]->flags & FFF_DYN_RESOLVE_ALL) {
              /* The dynamic link editor is limited, so we even have to
                 resolve references from the shared object at link time.
                 But only those which are linked to .dynsym. */
              if (read32(be,shdr->sh_link) == dynsym_idx)
                elf32_dynrefs(gv,ehdr,u,shdr,be,reloc_elf2vlink);
            }
            break;
          default:
            /* section header type not needed in shared objects */
            error(60,lf->pathname,read32(be,shdr->sh_type),lf->objname);
            break;
        }
      }

      if (dynstr_idx!=0 && dyn!=NULL) {
        /* set ObjectUnit's objname to the SONAME of the shared object */
        uint32_t tag;

        shdr = elf32_shdr(lf,ehdr,dynstr_idx);  /* .dynstr */
        while (tag = read32(be,dyn->d_tag)) {
          if (tag == DT_SONAME) {
            u->objname = (char *)ehdr + read32(be,shdr->sh_offset)
                         + read32(be,dyn->d_val);
            break;
          }
          dyn++;
        }
      }
      break;


    case ET_EXEC: /* executable file */
      /* @@@ */
      ierror("%s%s: Executables are currently not supported",fn,lf->pathname);
      break;


    default:
      error(41,lf->pathname,lf->objname);  /* illegal fmt./file corrupted */
      break;
  }

  /* add new object unit to the appropriate list */
  add_objunit(gv,u,FALSE);
}



/*****************************************************************/
/*                          Link ELF                             */
/*****************************************************************/


static void elf32_initsym(void *p,uint32_t nameoff,uint64_t value,
                          uint64_t size,uint8_t bind,uint8_t type,
                          uint16_t shndx,bool be)
{
  struct Elf32_Sym *s = (struct Elf32_Sym *)p;

  write32(be,s->st_name,nameoff);
  write32(be,s->st_value,(uint32_t)value);
  write32(be,s->st_size,(uint32_t)size);
  s->st_info[0] = ELF32_ST_INFO(bind,type);
  s->st_other[0] = 0;
  write16(be,s->st_shndx,shndx);
}


static void elf32_initreloc(void *p,uint64_t offset,uint64_t addend,
                            uint32_t symidx,uint32_t type,bool be)
{
  struct Elf32_Rela *r = (struct Elf32_Rela *)p;

  write32(be,r->r_offset,(uint32_t)offset);
  write32(be,r->r_addend,(uint32_t)addend);
  write32(be,r->r_info,ELF32_R_INFO(symidx,type));
}


void elf32_initdynlink(struct GlobalVars *gv)
{
  elf_initsymtabs(sizeof(struct Elf32_Sym),elf32_initsym);
  dynamic = elf_initdynlink(gv);
}


struct Symbol *elf32_pltgotentry(struct GlobalVars *gv,struct Section *sec,
                                 DynArg a,uint8_t entrysymtype,
                                 unsigned long offsadd,unsigned long sizeadd,
                                 int etype)
/* Make a table entry for indirectly accessing a location from an external
   symbol defintion (GOT_ENTRY/PLT_ENTRY) or a local relocation (GOT_LOCAL).
   The entry has a size of offsadd bytes, while the table section sec will
   become sizeadd bytes larger per entry. */
{
  bool relaflag = gv->reloctab_format == RTAB_ADDEND;

  return elf_pltgotentry(gv,sec,a,entrysymtype,offsadd,sizeadd,etype,relaflag,
                         relaflag ?
                         sizeof(struct Elf32_Rela) : sizeof(struct Elf32_Rel),
                         32);
}


struct Symbol *elf32_bssentry(struct GlobalVars *gv,const char *secname,
                              struct Symbol *xdef)
/* Allocate space for a copy-object in a .bss or .sbss section and create
   a R_COPY relocation to the original symbol in the shared object. */
{
  bool relaflag = gv->reloctab_format == RTAB_ADDEND;

  return elf_bssentry(gv,secname,xdef,relaflag,relaflag ?
                      sizeof(struct Elf32_Rela) : sizeof(struct Elf32_Rel),
                      32);
}


void elf32_dynamicentry(struct GlobalVars *gv,uint32_t tag,uint32_t val,
                        struct Section *relsec)
/* store another entry into the .dynamic section, make new relocation with
   relsec in value-field, when nonzero */
{
  if (dynamic) {
    bool be = elf_endianess == _BIG_ENDIAN_;
    struct Elf32_Dyn dyn;
    unsigned long offs = dynamic->size;

    write32(be,dyn.d_tag,tag);
    write32(be,dyn.d_val,val);
    dynamic->data = re_alloc(dynamic->data,
                             dynamic->size+sizeof(struct Elf32_Dyn));
    memcpy(dynamic->data+offs,&dyn,sizeof(struct Elf32_Dyn));
    dynamic->size += sizeof(struct Elf32_Dyn);

    if (relsec) {
      /* we need a 32-bit R_ABS relocation for d_val */
      struct Reloc *r;
      int o = offsetof(struct Elf32_Dyn,d_val);

      r = newreloc(gv,dynamic,NULL,relsec,0,offs+o,R_ABS,(lword)val);
      r->flags |= RELF_INTERNAL;  /* just for calculating the address */
      addreloc(dynamic,r,0,32,-1);
    }
  }
  else
    ierror("elf32_dynamicentry(): .dynamic was never created");
}


static void elf32_makehash(struct GlobalVars *gv)
/* Allocate and populate .hash section. */
{
  bool be = elf_endianess == _BIG_ENDIAN_;
  size_t nsyms = elfdsymlist.nextindex;
  size_t nbuckets = elf_num_buckets(nsyms);
  struct Section *hashsec = find_sect_name(gv->dynobj,hash_name);

  if (hashsec) {
    struct SymbolNode *sn;
    uint32_t *hdata;

    /* .hash layout: nbuckets, nsyms, [buckets], [sym-indexes] */
    hashsec->size = (2 + nbuckets + nsyms) * sizeof(uint32_t);
    hashsec->data = alloczero(hashsec->size);
    hdata = (uint32_t *)hashsec->data;
    write32(be,&hdata[0],nbuckets);
    write32(be,&hdata[1],nsyms);
    for (sn=(struct SymbolNode *)elfdsymlist.l.first;
         sn->n.next!=NULL; sn=(struct SymbolNode *)sn->n.next) {
      uint32_t *i = &hdata[2 + elf_hash(sn->name) % nbuckets];
      uint32_t j;

      while (j = read32(be,i))
        i = &hdata[2 + nbuckets + j];
      write32(be,i,sn->index);
    }      
  }
  else
    ierror("elf32_makehash(): no %s",hash_name);
}


void elf32_dyncreate(struct GlobalVars *gv,const char *pltgot_name)
/* generate .hash, populate .dynstr and .dynamic, allocate .dynsym,
   so that all sections have a valid size for the address calculation */
{
  const char *fn = "elf32_dyncreate():";
  struct Section *dynstr,*dynsym,*pltgot;
  struct LibPath *lpn;

  if (gv->dynobj == NULL)
    ierror("%s no dynobj",fn);

  /* write SONAME and RPATHs */
  if (gv->soname && gv->dest_sharedobj)
    elf32_dynamicentry(gv,DT_SONAME,elf_adddynstr(gv->soname),NULL);
  for (lpn=(struct LibPath *)gv->rpaths.first; lpn->n.next!=NULL;
       lpn=(struct LibPath *)lpn->n.next) {
    elf32_dynamicentry(gv,DT_RPATH,elf_adddynstr(lpn->path),NULL);
  }

  /* generate .hash section */
  elf32_makehash(gv);

  /* allocate and populate .dynstr section */
  if (dynstr = find_sect_name(gv->dynobj,dynstr_name)) {
    dynstr->size = elfdstrlist.nextindex;
    dynstr->data = alloc(dynstr->size);
    elf_putstrtab(dynstr->data,&elfdstrlist);
  }
  else
    ierror("%s %s missing",fn,dynstr_name);

  /* allocate .dynsym section - populate it later, when addresses are fixed */
  if (dynsym = find_sect_name(gv->dynobj,dynsym_name)) {
    dynsym->size = elfdsymlist.nextindex * sizeof(struct Elf32_Sym);
    dynsym->data = alloc(dynsym->size);
  }
  else
    ierror("%s %s missing",fn,dynsym_name);

  /* finish .dynamic section */
  elf32_dynamicentry(gv,DT_HASH,0,find_sect_name(gv->dynobj,hash_name));
  elf32_dynamicentry(gv,DT_STRTAB,0,dynstr);
  elf32_dynamicentry(gv,DT_SYMTAB,0,dynsym);
  elf32_dynamicentry(gv,DT_STRSZ,dynstr->size,NULL);
  elf32_dynamicentry(gv,DT_SYMENT,sizeof(struct Elf32_Sym),NULL);
  elf32_dynamicentry(gv,DT_DEBUG,0,NULL); /* needed? */
  /* do we have a .plt or .got section (target dependant) */
  if (pltgot = find_sect_name(gv->dynobj,pltgot_name)) {
    elf32_dynamicentry(gv,DT_PLTGOT,0,pltgot);    
  }
  /* do we have .plt relocations? */
  if (elfpltrelocs) {
    elf32_dynamicentry(gv,DT_PLTRELSZ,elfpltrelocs->size,NULL);
    elf32_dynamicentry(gv,DT_PLTREL,
                       gv->reloctab_format==RTAB_ADDEND?DT_RELA:DT_REL,
                       NULL);
    elf32_dynamicentry(gv,DT_JMPREL,0,elfpltrelocs);
  }
  /* do we have any other dynamic relocations? */
  if (elfdynrelocs) {
    if (gv->reloctab_format == RTAB_ADDEND) {
      elf32_dynamicentry(gv,DT_RELA,0,elfdynrelocs);
      elf32_dynamicentry(gv,DT_RELASZ,elfdynrelocs->size,NULL);
      elf32_dynamicentry(gv,DT_RELAENT,sizeof(struct Elf32_Rela),NULL);
    }
    else {
      elf32_dynamicentry(gv,DT_REL,0,elfdynrelocs);
      elf32_dynamicentry(gv,DT_RELSZ,elfdynrelocs->size,NULL);
      elf32_dynamicentry(gv,DT_RELENT,sizeof(struct Elf32_Rel),NULL);
    }
  }
  /* end tag */
  elf32_dynamicentry(gv,DT_NULL,0,NULL);
}



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


unsigned long elf32_headersize(struct GlobalVars *gv)
{
  return sizeof(struct Elf32_Ehdr) +
         elf_numsegments(gv) * sizeof(struct Elf32_Phdr);
}


static void elf32_header(FILE *f,uint16_t type,uint16_t mach,uint32_t entry,
                         uint32_t phoff,uint32_t shoff,uint32_t flags,
                         uint16_t phnum,uint16_t shnum,uint16_t shstrndx,
                         bool be)
/* write 32-bit ELF header */
{
  struct Elf32_Ehdr eh;

  memset(&eh,0,sizeof(struct Elf32_Ehdr));
  elf_ident(&eh,be,ELFCLASS32,type,mach);
  write32(be,eh.e_entry,entry);
  write32(be,eh.e_phoff,phoff);
  write32(be,eh.e_shoff,shoff);
  write32(be,eh.e_flags,flags);
  write16(be,eh.e_ehsize,sizeof(struct Elf32_Ehdr));
  write16(be,eh.e_phentsize,phnum ? sizeof(struct Elf32_Phdr):0);
  write16(be,eh.e_phnum,phnum);
  write16(be,eh.e_shentsize,shnum ? sizeof(struct Elf32_Shdr):0);
  write16(be,eh.e_shnum,shnum);
  write16(be,eh.e_shstrndx,shstrndx);
  fwritex(f,&eh,sizeof(struct Elf32_Ehdr));
}


static struct ShdrNode *elf32_newshdr(void)
{
  struct ShdrNode *s = alloczero(sizeof(struct ShdrNode));

  addtail(&shdrlist,&s->n);
  ++elfshdridx;
  return s;
}


static struct ShdrNode *elf32_addshdr(uint32_t name,uint32_t type,
                                      uint32_t flags,uint32_t addr,
                                      uint32_t offset,uint32_t size,
                                      uint32_t link,uint32_t info,
                                      uint32_t align,uint32_t entsize,bool be)
{
  struct ShdrNode *shn = elf32_newshdr();

  write32(be,shn->s.sh_name,name);
  write32(be,shn->s.sh_type,type);
  write32(be,shn->s.sh_flags,flags);
  write32(be,shn->s.sh_addr,addr);
  write32(be,shn->s.sh_offset,offset);
  write32(be,shn->s.sh_size,size);
  write32(be,shn->s.sh_link,link);
  write32(be,shn->s.sh_info,info);
  write32(be,shn->s.sh_addralign,align);
  write32(be,shn->s.sh_entsize,entsize);
  return shn;
}


static void elf32_writephdrs(struct GlobalVars *gv,FILE *f)
/* write 32-bit ELF Program Header (PHDR) */
{
  bool be = elf_endianess == _BIG_ENDIAN_;
  long gapsize = elf_file_hdr_gap;
  struct Elf32_Phdr phdr;
  struct Phdr *p;

  for (p=gv->phdrlist; p; p=p->next) {
    if (p->flags & PHDR_USED) {
      if (p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {
        write32(be,phdr.p_type,p->type);
        write32(be,phdr.p_offset,p->offset);
        write32(be,phdr.p_vaddr,p->start_vma);
        write32(be,phdr.p_paddr,p->start);
        write32(be,phdr.p_filesz,p->file_end - p->start);
        write32(be,phdr.p_memsz,p->mem_end - p->start);
        write32(be,phdr.p_flags,p->flags & PHDR_PFMASK);
        write32(be,phdr.p_align,1L<<p->alignment);
        fwritex(f,&phdr,sizeof(struct Elf32_Phdr));
      }
      else
        gapsize += sizeof(struct Elf32_Phdr);
    }
  }
  fwritegap(f,gapsize);  /* gap at the end, for unused PHDRs */
}


static void elf32_writeshdrs(struct GlobalVars *gv,FILE *f,
                             uint32_t reloffset,uint32_t stabndx)
/* write all section headers */
{
  const char *fn = "elf32_writeshdrs():";
  bool be = elf_endianess == _BIG_ENDIAN_;
  struct LinkedSection *ls;
  struct ShdrNode *shn;
  uint32_t type;

  while (shn = (struct ShdrNode *)remhead(&shdrlist)) {
    type = read32(be,shn->s.sh_type);

    /* handle REL and RELA sections */
    if (type == SHT_RELA || type == SHT_REL) {
      if (read32(be,shn->s.sh_flags) & SHF_ALLOC) {
        /* allocated, so probably dynamic relocs: link to .dynsym */
        if (ls = find_lnksec(gv,dynsym_name,0,0,0,0))
          write32(be,shn->s.sh_link,(uint32_t)ls->index);
        else
          ierror("%s %s",fn,dynsym_name);

        if (read32(be,shn->s.sh_info) != 0) {
          /* link to .plt requested in info field */
          if (ls = find_lnksec(gv,plt_name,0,0,0,0))
            write32(be,shn->s.sh_info,(uint32_t)ls->index);
          else
            ierror("%s %s",fn,plt_name);
        }
      }
      else {
        /* patch correct sh_offset and sh_link for reloc header */
        write32(be,shn->s.sh_offset,read32(be,shn->s.sh_offset)+reloffset);
        write32(be,shn->s.sh_link,stabndx);
      }
    }

    /* handle HASH sections, which need a .dynsym link */
    else if (type == SHT_HASH) {
      if (ls = find_lnksec(gv,dynsym_name,0,0,0,0))
        write32(be,shn->s.sh_link,(uint32_t)ls->index);
      else
        ierror("%s %s",fn,dynsym_name);
    }

    /* handle DYNAMIC and DYNSYM sections */
    else if (type==SHT_DYNAMIC || type==SHT_DYNSYM) {
      /* write .dynstr link */
      if (ls = find_lnksec(gv,dynstr_name,0,0,0,0))
        write32(be,shn->s.sh_link,(uint32_t)ls->index);
      else
        ierror("%s %s",fn,dynstr_name);

      if (type == SHT_DYNSYM) {
        write32(be,shn->s.sh_info,1);  /* @@ FIXME! number of local symbols */
      }
    }

    fwritex(f,&shn->s,sizeof(struct Elf32_Shdr));
  }
}


static void elf32_sec2shdr(struct LinkedSection *ls,bool bss,uint64_t f)
{
  struct ShdrNode *shn;
  uint32_t type = bss ? SHT_NOBITS : SHT_PROGBITS;
  uint32_t info = 0;
  uint32_t entsize = 0;

  if (!strncmp(ls->name,note_name,strlen(note_name)))
    type = SHT_NOTE;
  else if (!strncmp(ls->name,".rela",5)) {
    type = SHT_RELA;
    entsize = sizeof(struct Elf32_Rela);
  }
  else if (!strncmp(ls->name,".rel",4)) {
    type = SHT_REL;
    entsize = sizeof(struct Elf32_Rel);
  }
  else if (!strcmp(ls->name,hash_name)) {
    type = SHT_HASH;
    entsize = sizeof(uint32_t);
  }
  else if (!strcmp(ls->name,dynsym_name)) {
    type = SHT_DYNSYM;
    entsize = sizeof(struct Elf32_Sym);
  }
  else if (!strcmp(ls->name,dyn_name)) {
    type = SHT_DYNAMIC;
    entsize = sizeof(struct Elf32_Dyn);
  }
  else if (!strcmp(ls->name,dynstr_name))
    type = SHT_STRTAB;
  else if (!strncmp(ls->name,got_name,strlen(got_name)))
    entsize = sizeof(uint32_t);

  if (!strcmp(ls->name,pltrel_name[0]) || !strcmp(ls->name,pltrel_name[1]))
    info = ~0;  /* request .plt index in info field for .rel(a).plt */

  shn = elf32_addshdr(elf_addshdrstr(ls->name),type,(uint32_t)f,ls->base,
                      elfoffset,ls->size,0,info,1<<(uint32_t)ls->alignment,
                      entsize,elf_endianess);


  if (stabdebugidx && !strcmp(ls->name,".stab"))
    stabshdr = shn;  /* patch sh_link field for .stabstr later */
}


static void elf32_addrelocs(struct GlobalVars *gv,
                            uint8_t (*reloc_vlink2elf)(struct Reloc *))
/* creates relocations for all sections */
{
  bool be = elf_endianess == _BIG_ENDIAN_;
  struct LinkedSection *ls;
  struct Reloc *rel;
  uint32_t sroffs=0,roffs=0;

  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    sroffs = roffs;

    /* relocations */
    for (rel=(struct Reloc *)ls->relocs.first;
         rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next)
      roffs += elf_addrela(gv,ls,rel,be,reloclist,reloc_vlink2elf);

    /* external references */
    for (rel=(struct Reloc *)ls->xrefs.first;
         rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next)
      roffs += elf_addrela(gv,ls,rel,be,reloclist,reloc_vlink2elf);

    if (roffs != sroffs) {
      /* create ".rel(a).name" header */
      char *relname = (char *)alloc(strlen(ls->name)+6);

      sprintf(relname,".%s%s",
              gv->reloctab_format==RTAB_ADDEND ? "rela" : "rel",
              ls->name);
      elf32_addshdr(elf_addshdrstr(relname),
                    gv->reloctab_format==RTAB_ADDEND ? SHT_RELA : SHT_REL,
                    0,0,sroffs,roffs-sroffs,0,(uint32_t)ls->index,4,
                    gv->reloctab_format==RTAB_ADDEND ?
                      sizeof(struct Elf32_Rela) : sizeof(struct Elf32_Rel),
                    be);
      /* sroffs is relative and will be corrected later */
      /* sh_link will be initialized, when .symtab exists */
    }
  }
}


static void elf32_makeshstrtab(void)
/* creates .shstrtab */
{
  bool be = elf_endianess == _BIG_ENDIAN_;

  elf32_addshdr(elfshstrtabidx,SHT_STRTAB,0,0,elfoffset,
                elfshstrlist.nextindex,0,0,1,0,be);
  elfoffset += elfshstrlist.nextindex;
  elfoffset += align(elfoffset,2);
}


static void elf32_makestrtab(void)
/* creates .strtab */
{
  bool be = elf_endianess == _BIG_ENDIAN_;

  elf32_addshdr(elfstrtabidx,SHT_STRTAB,0,0,elfoffset,
                elfstringlist.nextindex,0,0,1,0,be);
  elfoffset += elfstringlist.nextindex;
  elfoffset += align(elfoffset,2);
}


static void elf32_makestabstr(void)
/* create .stabstr */
{
  if (stabdebugidx) {
    bool be = elf_endianess == _BIG_ENDIAN_;
    uint32_t size = 0;
    struct StabCompUnit *cu;

    for (cu=(struct StabCompUnit *)stabcompunits.first;
         cu->n.next!=NULL; cu=(struct StabCompUnit *)cu->n.next)
      size += cu->strtab.nextindex;

    if (stabshdr) {
      /* patch sh_link field of .stab */
      write32(be,stabshdr->s.sh_link,elfshdridx);
    }
    elf32_addshdr(stabdebugidx,SHT_STRTAB,0,0,elfoffset,size,0,0,1,0,be);
    elfoffset += size;
  }
}


static void elf32_makesymtab(uint32_t strtabindex)
/* creates .symtab */
{
  bool be = elf_endianess == _BIG_ENDIAN_;

  elf32_addshdr(elfsymtabidx,SHT_SYMTAB,0,0,elfoffset,
                elfsymlist.nextindex * sizeof(struct Elf32_Sym),
                strtabindex,elfsymlist.globalindex,4,
                sizeof(struct Elf32_Sym),be);
  elfoffset += elfsymlist.nextindex * sizeof(struct Elf32_Sym);
}


static size_t elf32_putdynreloc(struct GlobalVars *gv,struct LinkedSection *ls,
                                struct Reloc *rel,void *dst,
                                uint8_t (*reloc_vlink2elf)(struct Reloc *),
                                bool rela,bool be)
{
  const char *fn = "elf32_putdynreloc()";
  struct Elf32_Rela *rp = (struct Elf32_Rela *)dst;
  uint32_t symidx;
  uint8_t rtype;

  if (rel->xrefname) {
    struct SymbolNode *sn;

    sn = elf_findSymNode(&elfdsymlist,rel->xrefname);
    if (sn == NULL)
      ierror("%s no symbol <%s> in dyn.table",fn,rel->xrefname);
    symidx = sn->index;
  }
  else
    ierror("%s no symbol base",fn);

  if (!(rtype = reloc_vlink2elf(rel))) {
    struct RelocInsert *ri;

    if (ri = rel->insert)
      error(32,fff[gv->dest_format]->tname,reloc_name[rel->rtype],
            (int)ri->bpos,(int)ri->bsiz,ri->mask,ls->name,rel->offset);
    else
      ierror("%s Reloc without insert-field",fn);
  }

  write32(be,rp->r_offset,(uint32_t)(ls->base + rel->offset));
  write32(be,rp->r_info,ELF32_R_INFO(symidx,(uint32_t)rtype));

  if (rela) {
    write32(be,rp->r_addend,(uint32_t)rel->addend);
    writesection(gv,ls->data+rel->offset,rel,0);
    return sizeof(struct Elf32_Rela);
  }
  writesection(gv,ls->data+rel->offset,rel,rel->addend);
  return sizeof(struct Elf32_Rel);
}


static void elf32_makedynamic(struct GlobalVars *gv,
                              uint8_t (*reloc_vlink2elf)(struct Reloc *))
{
  if (gv->dynamic) {
    const char *fn = "elf32_makedynamic():";
    bool be = elf_endianess == _BIG_ENDIAN_;
    int rela = gv->reloctab_format==RTAB_ADDEND ? 1 : 0;
    struct LinkedSection *ls;
    uint8_t *dynp,*pltp;

    if (ls = find_lnksec(gv,dynrel_name[rela],0,0,0,0))
      dynp = ls->data;
    else
      dynp = NULL;
    if (ls = find_lnksec(gv,pltrel_name[rela],0,0,0,0))
      pltp = ls->data;
    else
      pltp = NULL;

    /* write dynamic relocations */
    for (ls=(struct LinkedSection *)gv->lnksec.first;
         ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
      struct Reloc *rel = (struct Reloc *)ls->xrefs.first;
      struct Reloc *nextrel;

      while (nextrel = (struct Reloc *)rel->n.next) {
        if (rel->flags & RELF_DYN) {
          if (dynp == NULL)
            ierror("%s %s lost",fn,dynrel_name[rela]);
          dynp += elf32_putdynreloc(gv,ls,rel,dynp,reloc_vlink2elf,rela,be);
          remnode(&rel->n);
          /* free rel */
        }
        else if (rel->flags & RELF_PLT) {
          if (pltp == NULL)
            ierror("%s %s lost",fn,pltrel_name[rela]);
          pltp += elf32_putdynreloc(gv,ls,rel,pltp,reloc_vlink2elf,rela,be);
          remnode(&rel->n);
          /* free rel */
        }
        rel = nextrel;
      }
    }

    /* write dynamic symbols to .dynsym and fix their values */
    if (ls = find_lnksec(gv,dynsym_name,0,0,0,0)) {
      struct Elf32_Sym *tab = (struct Elf32_Sym *)ls->data;
      struct DynSymNode *dsn;

      elf_putsymtab(ls->data,&elfdsymlist);
      while (dsn = (struct DynSymNode *)remhead(&elfdynsymlist)) {
        uint8_t symtype = elf_getinfo(dsn->sym);

        write32(be,tab[dsn->idx].st_value,dsn->sym->value);
        write16(be,tab[dsn->idx].st_shndx,elf_getshndx(gv,dsn->sym,symtype));
        /* free dsn? */
      }
    }
    else
      ierror("%s %s lost",fn,dynsym_name);
  }
}


static struct StabCompUnit *newCompUnit(void)
{
  struct StabCompUnit *scu = alloczero(sizeof(struct StabCompUnit));

  initlist(&scu->stabs);
  scu->strtab.htabsize = STABHTABSIZE;
  return scu;
}


static void write_nlist(bool be,struct nlist32 *n,long strx,
                        uint8_t type,int8_t othr,int16_t desc,uint32_t val)
{
  write32(be,&n->n_strx,strx);
  n->n_type = type;
  n->n_other = othr;
  write16(be,&n->n_desc,desc);
  write32(be,&n->n_value,val);
}


static void elf32_writestabstr(FILE *f)
{
  if (stabdebugidx) {
    struct StabCompUnit *cu;

    for (cu=(struct StabCompUnit *)stabcompunits.first;
         cu->n.next!=NULL; cu=(struct StabCompUnit *)cu->n.next)
      elf_writestrtab(f,&cu->strtab);
  }
}


static void elf32_makestabs(struct GlobalVars *gv)
/* create .stab, .stabstr und .rela.stab sections from StabDebug records */
{
  static const char *fn = "elf32_makestabs";
  bool be = elf_endianess == _BIG_ENDIAN_;

  stabdebugidx = 0;
  initlist(&stabcompunits);

  if (gv->strip_symbols < STRIP_DEBUG) {
    struct StabCompUnit *cu = NULL;
    bool so_found = FALSE;
    struct LinkedSection *ls;
    struct ObjectUnit *obj;
    struct StabDebug *stab;
    unsigned long stabsize = 0;

    /* determine size of .stab section to generate */
    for (obj=(struct ObjectUnit *)gv->selobjects.first,stabsize=0;
         obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {

      while (stab=(struct StabDebug *)remhead(&obj->stabs)) {

        if (stab->n_type==N_SO && stab->name.ptr!=NULL) {
          if (*stab->name.ptr != '\0') {
            if (!so_found) {
              /* allocate and initialize new compilation unit */
              stabsize += sizeof(struct nlist32);  /* comp.unit header */
              cu = newCompUnit();
              addtail(&stabcompunits,&cu->n);
              so_found = TRUE;
            }
          }
        }
        else
          so_found = FALSE;

        if (cu == NULL)
          ierror("%s: N_SO missing",fn);
        if (cu->entries >= 0x7fff)
          ierror("%s: too many stab-entries for compilation unit",fn);
        stabsize += sizeof(struct nlist32);  /* stab entry */
        cu->entries++;

        /* register symbol name in comp.unit's string table */
        if (stab->name.ptr)
          stab->name.idx = elf_addstrlist(&cu->strtab,stab->name.ptr);
        else
          stab->name.idx = 0;

        if (so_found)
          cu->nameidx = stab->name.idx;  /* set comp.unit name */

        /* append stab entry to current comp.unit */
        addtail(&cu->stabs,&stab->n);
      }
    }

    if (stabsize) {
      /* create .stab section with contents for real */
      struct nlist32 *nlst = alloc(stabsize);

      if (ls = find_lnksec(gv,".stab",0,0,0,0)) {
        if (ls->size > 0)
          ierror("%s: .stab already in use",fn);
      }
      else
        ls = create_lnksect(gv,".stab",ST_DATA,0,SP_READ,2,0);
      ls->size = ls->filesize = stabsize;
      ls->data = (uint8_t *)nlst;

      /* allocate SHDR name for .stabstr */
      stabdebugidx = elf_addshdrstr(".stabstr");

      /* transfer nodes from compilation units to section's data area */
      for (cu=(struct StabCompUnit *)stabcompunits.first;
           cu->n.next!=NULL; cu=(struct StabCompUnit *)cu->n.next) {
        bool within_fun = FALSE;
        uint32_t fun_addr = 0;

        /* write compilation unit stab header containing number
           of stabs and length of string-table */
        write_nlist(be,nlst++,cu->nameidx,0,0,cu->entries,
                    cu->strtab.nextindex);

        /* write comp.unit's stabs */
        for (stab=(struct StabDebug *)cu->stabs.first;
             stab->n.next!=NULL; stab=(struct StabDebug *)stab->n.next) {

          switch (stab->n_type) {
            case N_SO:
              within_fun = FALSE;
              break;
            case N_FUN:
              if (stab->name.idx) {
                within_fun = TRUE;
                fun_addr = stab->n_value;
              }
              else {  /* function end address needs to be relative (size) */
                within_fun = FALSE;
                stab->n_value -= fun_addr;
                stab->relsect = NULL;
              }
              break;
            case N_SLINE:
              if (within_fun && stab->relsect) {
                /* convert address into a function-offset */
                stab->n_value -= fun_addr;
                stab->relsect = NULL;
              }
              break;
          }

          /* add relocation, if required */
          if (stab->relsect) {
            struct Reloc *r = alloczero(sizeof(struct Reloc));

            stab->n_value += stab->relsect->offset;
            r->relocsect.lnk = stab->relsect->lnksec;
            r->offset = (uint8_t *)&nlst->n_value - ls->data;
            r->addend = (lword)stab->n_value;
            r->rtype = R_ABS;
            addreloc(NULL,r,0,32,-1);
            addtail(&ls->relocs,&r->n);
          }

          /* write stab entry to section */
          write_nlist(be,nlst++,stab->name.idx,stab->n_type,
                      stab->n_othr,stab->n_desc,stab->n_value);
        }
      }
    }
  }
}


static void elf32_initoutput(struct GlobalVars *gv,uint32_t init_file_offset,
                             int8_t output_endianess)
/* initialize section header, program header, relocation, symbol, */
/* string and section header string lists */
{
  elf_initoutput(gv,init_file_offset,output_endianess);
  elf_initsymtabs(sizeof(struct Elf32_Sym),elf32_initsym);

  reloclist = elf_newreloclist(sizeof(struct Elf32_Rela),
                               gv->reloctab_format!=RTAB_ADDEND ?
                               sizeof(struct Elf32_Rel) :
                               sizeof(struct Elf32_Rela),
                               elf32_initreloc);
  elf32_newshdr();          /* first Shdr is always zero */
}


void elf32_writeobject(struct GlobalVars *gv,FILE *f,uint16_t m,int8_t endian,
                       uint8_t (*reloc_vlink2elf)(struct Reloc *))
/* creates an ELF32 relocatable object file */
{
  uint32_t sh_off,shstrndx,stabndx;

  elf32_initoutput(gv,sizeof(struct Elf32_Ehdr),endian);
  elf32_makestabs(gv);
  elf_stdsymtab(gv,STB_LOCAL,STT_FILE);

  elf_makeshdrs(gv,elf32_sec2shdr);
  elf_stdsymtab(gv,STB_LOCAL,0);
  elfsymlist.globalindex = elfsymlist.nextindex;
  elf_stdsymtab(gv,STB_WEAK,0);
  elf_stdsymtab(gv,STB_GLOBAL,0);
  elf32_addrelocs(gv,reloc_vlink2elf);

  elf32_makestabstr();
  shstrndx = elfshdridx;
  elf32_makeshstrtab();
  sh_off = elfoffset;
  stabndx = elfshdridx;
  elfoffset += (elfshdridx+2) * sizeof(struct Elf32_Shdr);
  elf32_makesymtab(elfshdridx+1);
  elf32_makestrtab();

  elf32_header(f,ET_REL,m,0,0,sh_off,0,0,elfshdridx,
               shstrndx,endian==_BIG_ENDIAN_);
  elf_writesections(gv,f);
  elf32_writestabstr(f);
  elf_writestrtab(f,&elfshstrlist);
  fwrite_align(f,2,ftell(f));
  elf32_writeshdrs(gv,f,elfoffset,stabndx);
  elf_writesymtab(f,&elfsymlist);
  elf_writestrtab(f,&elfstringlist);
  fwrite_align(f,2,ftell(f));
  elf_writerelocs(f,reloclist);
}


void elf32_writeexec(struct GlobalVars *gv,FILE *f,uint16_t m,int8_t endian,
                     uint8_t (*reloc_vlink2elf)(struct Reloc *))
/* creates an ELF32 executable file (page-aligned with absolute addresses) */
{
  uint32_t sh_off,shstrndx,stabndx,phnum;
  struct LinkedSection *ls;

  elf32_initoutput(gv,elf32_headersize(gv),endian);
  elf32_makestabs(gv);
  phnum = elf_segmentcheck(gv,sizeof(struct Elf32_Ehdr));
  elf_stdsymtab(gv,STB_LOCAL,STT_FILE);

  elf_makeshdrs(gv,elf32_sec2shdr);
  elf32_makedynamic(gv,reloc_vlink2elf);

  elf_stdsymtab(gv,STB_LOCAL,0);
  elfsymlist.globalindex = elfsymlist.nextindex;
  elf_stdsymtab(gv,STB_WEAK,0);
  elf_stdsymtab(gv,STB_GLOBAL,0);

  if (gv->keep_relocs)
    elf32_addrelocs(gv,reloc_vlink2elf);
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    calc_relocs(gv,ls);
  }

  elf32_makestabstr();
  shstrndx = elfshdridx;
  elf32_makeshstrtab();
  sh_off = elfoffset;
  stabndx = elfshdridx;
  elfoffset += (elfshdridx+2) * sizeof(struct Elf32_Shdr);
  elf32_makesymtab(elfshdridx+1);
  elf32_makestrtab();

  elf32_header(f,gv->dest_sharedobj?ET_DYN:ET_EXEC,m,
               (uint32_t)entry_address(gv),sizeof(struct Elf32_Ehdr),sh_off,0,
               phnum,elfshdridx,shstrndx,endian==_BIG_ENDIAN_);
  elf32_writephdrs(gv,f);
  elf_writesegments(gv,f);
  elf32_writestabstr(f);
  elf_writestrtab(f,&elfshstrlist);
  fwrite_align(f,2,ftell(f));
  elf32_writeshdrs(gv,f,elfoffset,stabndx);
  elf_writesymtab(f,&elfsymlist);
  elf_writestrtab(f,&elfstringlist);
  if (gv->keep_relocs) {
    fwrite_align(f,2,ftell(f));
    elf_writerelocs(f,reloclist);
  }
}

#endif /* ELF32 */
