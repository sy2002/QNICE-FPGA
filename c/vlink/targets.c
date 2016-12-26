/* $VER: vlink targets.c V0.15a (04.02.16)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2016  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2016 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#define TARGETS_C
#include "vlink.h"


struct FFFuncs *fff[] = {
#ifdef ADOS
  &fff_amigahunk,
#endif
#ifdef EHF
  &fff_ehf,
#endif
#ifdef ATARI_TOS
  &fff_ataritos,
#endif
#ifdef ELF32_PPC_BE
  &fff_elf32ppcbe,
#endif
#ifdef ELF32_AMIGA
  &fff_elf32powerup,
  &fff_elf32morphos,
  &fff_elf32amigaos,
#endif
#ifdef ELF32_M68K
  &fff_elf32m68k,
#endif
#ifdef ELF32_386
  &fff_elf32i386,
#endif
#ifdef ELF32_AROS
  &fff_elf32aros,
#endif
#ifdef ELF32_ARM_LE
  &fff_elf32armle,
#endif
#ifdef ELF32_JAG
  &fff_elf32jag,
#endif
#ifdef ELF64_X86
  &fff_elf64x86,
#endif
#ifdef AOUT_NULL
  &fff_aoutnull,
#endif
#ifdef AOUT_SUN010
  &fff_aoutsun010,
#endif
#ifdef AOUT_SUN020
  &fff_aoutsun020,
#endif
#ifdef AOUT_BSDM68K
  &fff_aoutbsd68k,
#endif
#ifdef AOUT_BSDM68K4K
  &fff_aoutbsd68k4k,
#endif
#ifdef AOUT_MINT
  &fff_aoutmint,
#endif
#ifdef AOUT_BSDI386
  &fff_aoutbsdi386,
#endif
#ifdef AOUT_PC386
  &fff_aoutpc386,
#endif
#ifdef AOUT_JAGUAR
  &fff_aoutjaguar,
#endif
#ifdef VOBJ
  &fff_vobj_le,
  &fff_vobj_be,
#endif

/* the raw binary file formats *must* be the last ones */
#ifdef RAWBIN1
  &fff_rawbin1,
#endif
#ifdef RAWBIN2
  &fff_rawbin2,
#endif
#ifdef AMSDOS
  &fff_amsdos,
#endif
#ifdef CBMPRG
  &fff_cbmprg,
#endif
#ifdef SREC19
  &fff_srec19,
#endif
#ifdef SREC28
  &fff_srec28,
#endif
#ifdef SREC37
  &fff_srec37,
#endif
#ifdef IHEX
  &fff_ihex,
#endif
#ifdef SHEX1
  &fff_shex1,
#endif
#ifdef RAWSEG
  &fff_rawseg,
#endif
  NULL
};

const char *sym_type[] = { "undef","abs","reloc","common","indirect" };
const char *sym_info[] = { ""," object"," function"," section"," file" };
const char *sym_bind[] = { "","local ","global ","weak " };

const char *reloc_name[] = {
  "R_NONE",
  "R_ABS",
  "R_PC",
  "R_GOT",
  "R_GOTPC",
  "R_GOTOFF",
  "R_GLOBDAT",
  "R_PLT",
  "R_PLTPC",
  "R_PLTOFF",
  "R_SD",
  "R_UABS",
  "R_LOCALPC",
  "R_LOADREL",
  "R_COPY",
  "R_JMPSLOT",
  "R_SECOFF",
  "","","","","","","","","","","","","","",""
  "R_SD2",
  "R_SD21",
  "R_SECOFF",
  "R_MOSDREL",
  "R_AOSBREL",
  NULL
};


/* common section names */
const char text_name[] = ".text";
const char data_name[] = ".data";
const char bss_name[] = ".bss";
const char sdata_name[] = ".sdata";
const char sbss_name[] = ".sbss";
const char sdata2_name[] = ".sdata2";
const char sbss2_name[] = ".sbss2";
const char ctors_name[] = ".ctors";
const char dtors_name[] = ".dtors";
const char got_name[] = ".got";
const char plt_name[] = ".plt";

const char sdabase_name[] = "_SDA_BASE_";
const char sda2base_name[] = "_SDA2_BASE_";
const char gotbase_name[] = "__GLOBAL_OFFSET_TABLE_";
const char pltbase_name[] = "__PROCEDURE_LINKAGE_TABLE_";
const char dynamic_name[] = "__DYNAMIC";
const char r13init_name[] = "__r13_init";

const char noname[] = "";



struct Symbol *findsymbol(struct GlobalVars *gv,struct Section *sec,
                          const char *name)
/* Return pointer to Symbol, otherwise return NULL.
   Make sure to prefer symbols from sec's ObjectUnit. */
{
  if (fff[gv->dest_format]->fndsymbol) {
    return fff[gv->dest_format]->fndsymbol(gv,sec,name);
  }
  else {
    struct Symbol *sym = gv->symbols[elf_hash(name)%SYMHTABSIZE];
    struct Symbol *found = NULL;

    while (sym) {
      if (!strcmp(name,sym->name)) {
        if (found && sec) {
          /* ignore, when not from the refering ObjectUnit */
          if (sym->relsect->obj == sec->obj)
            found = sym;
        }
        else
          found = sym;
      }
      sym = sym->glob_chain;
    }
    if (found!=NULL && found->type==SYM_INDIR)
      return findsymbol(gv,sec,found->indir_name);
    return found;
  }
  return NULL;
}


bool check_protection(struct GlobalVars *gv,const char *name)
/* checks if symbol name is protected against stripping */
{
  struct SymNames *sn = gv->prot_syms;

  while (sn) {
    if (!strcmp(sn->name,name))
      return TRUE;
    sn = sn->next;
  }
  return FALSE;
}


static void unlink_objsymbol(struct Symbol *delsym)
/* unlink a symbol from an object unit's hash chain */
{
  const char *fn = "unlink_objsymbol():";
  struct ObjectUnit *ou = delsym->relsect ? delsym->relsect->obj : NULL;

  if (ou) {
    struct Symbol **chain = &ou->objsyms[elf_hash(delsym->name)%OBJSYMHTABSIZE];
    struct Symbol *sym;

    while (sym = *chain) {
      if (sym == delsym)
        break;
      chain = &sym->obj_chain;
    }
    if (sym) {
      /* unlink the symbol node from the chain */
      *chain = delsym->obj_chain;
      delsym->obj_chain = NULL;
    }
    else
      ierror("%s %s could not be found in any object",fn,delsym->name);
  }
  else
    ierror("%s %s has no object or section",fn,delsym->name);
}


static void remove_obj_symbol(struct Symbol *delsym)
/* delete a symbol from an object unit */
{
  unlink_objsymbol(delsym);
  free(delsym);
}


bool addglobsym(struct GlobalVars *gv,struct Symbol *newsym)
/* insert symbol into global symbol hash table */
{
  struct Symbol **chain = &gv->symbols[elf_hash(newsym->name)%SYMHTABSIZE];
  struct Symbol *sym;
  struct ObjectUnit *newou = newsym->relsect ? newsym->relsect->obj : NULL;

  while (sym = *chain) {
    if (!strcmp(newsym->name,sym->name)) {

      if (newsym->type==SYM_ABS && sym->type==SYM_ABS &&
          newsym->value == sym->value)
        return FALSE;  /* absolute symbols with same value are ignored */

      if (newsym->relsect == NULL || sym->relsect == NULL) {
        /* redefined linker script symbol */
        if (newou!=NULL && newou->lnkfile->type<ID_LIBBASE) {
          static const char *objname = "ldscript";

          error(19,newou ? newou->lnkfile->pathname : objname,
                newsym->name, newou ? getobjname(newou) : objname,
                sym->relsect ? getobjname(sym->relsect->obj) : objname);
        }
        /* redefinitions in libraries are silently ignored */
        return FALSE;
      }

      if (sym->bind == SYMB_GLOBAL) {
        /* symbol already defined with global binding */

        if (newsym->bind == SYMB_GLOBAL) {
          if (newou->lnkfile->type < ID_LIBBASE) {
            if (newsym->type==SYM_COMMON && sym->type==SYM_COMMON) {
              if ((newsym->size>sym->size && newsym->value>=sym->value) ||
                  (newsym->size>=sym->size && newsym->value>sym->value)) {
                /* replace by common symbol with bigger size or alignment */
                newsym->glob_chain = sym->glob_chain;
                remove_obj_symbol(sym);  /* delete old symbol in object unit */
                break;
              }
            }
            else {
              /* Global symbol "x" is already defined in... */
              error(19,newou->lnkfile->pathname,newsym->name,
                    getobjname(newou),getobjname(sym->relsect->obj));
            }
            return FALSE;  /* ignore this symbol */
          }
          /* else: add global library symbol with same name to the chain -
             some targets may want to choose between them! */
        }
        else
          return FALSE;  /* don't replace global by nonglobal symbols */
      }

      else {
        if (newsym->bind == SYMB_WEAK)
          return FALSE;  /* don't replace weak by weak */

        /* replace weak symbol by a global one */
        newsym->glob_chain = sym->glob_chain;
        remove_obj_symbol(sym);  /* delete old symbol in object unit */
        break;
      }
    }

    chain = &sym->glob_chain;
  }

  *chain = newsym;
  if (newou) {
    if (trace_sym_access(gv,newsym->name))
      fprintf(stderr,"Symbol %s defined in section %s in %s\n",
              newsym->name,newsym->relsect->name,getobjname(newou));
  }
  return TRUE;
}


#if 0 /* not used */
void unlink_globsymbol(struct GlobalVars *gv,struct Symbol *sym)
/* remove a symbol from the global symbol list */
{
  static const char *fn = "unlink_globsymbol(): ";

  if (gv->symbols) {
    struct Symbol *cptr;
    struct Symbol **chain = &gv->symbols[elf_hash(sym->name)%SYMHTABSIZE];

    while (cptr = *chain) {
      if (cptr == sym)
        break;
      chain = &cptr->glob_chain;
    }
    if (cptr) {
      /* delete the symbol node from the chain */
      *chain = sym->glob_chain;
      sym->glob_chain = NULL;
    }
    else
      ierror("%s%s could not be found in global symbols list",fn,sym->name);
  }
  else
    ierror("%ssymbols==NULL",fn);
}
#endif


void hide_shlib_symbols(struct GlobalVars *gv)
/* scan for all unreferenced SYMF_SHLIB symbols in the global symbol list
   and remove them - they have to be invisible for the file we create */
{
  int i;

  for (i=0; i<SYMHTABSIZE; i++) {
    struct Symbol *sym;
    struct Symbol **chain = &gv->symbols[i];

    while (sym = *chain) {
      if ((sym->flags & SYMF_SHLIB) && !(sym->flags & SYMF_REFERENCED)) {
        /* remove from global symbol list */
        *chain = sym->glob_chain;
        sym->glob_chain = NULL;
      }
      else
        chain = &sym->glob_chain;
    }        
  }
}


static void add_objsymbol(struct ObjectUnit *ou,struct Symbol *newsym)
/* Add a symbol to an object unit's symbol table. The symbol name
   must be unique within the object, otherwise an internal error
   will occur! */
{
  struct Symbol *sym;
  struct Symbol **chain = &ou->objsyms[elf_hash(newsym->name)%OBJSYMHTABSIZE];

  while (sym = *chain) {
    if (!strcmp(newsym->name,sym->name))
      ierror("add_objsymbol(): %s defined twice",newsym->name);
    chain = &sym->obj_chain;
  }
  *chain = newsym;
}


struct Symbol *addsymbol(struct GlobalVars *gv,struct Section *s,
                         const char *name,const char *iname,lword val,
                         uint8_t type,uint8_t flags,uint8_t info,uint8_t bind,
                         uint32_t size,bool chkdef)
/* Define a new symbol. If defined twice in the same object unit, then */
/* return a pointer to its first definition. Defining the symbol twice */
/* globally is only allowed in different object units of a library. */
{
  struct Symbol *sym;
  struct ObjectUnit *ou = s->obj;
  struct Symbol **chain = &ou->objsyms[elf_hash(name)%OBJSYMHTABSIZE];

  while (sym = *chain) {
    if (!strcmp(name,sym->name)) {
      if (chkdef)  /* do we have to warn about multiple def. ourselves? */
        error(56,ou->lnkfile->pathname,name,getobjname(ou));
      return sym;  /* return first definition to caller */
    }
    chain = &sym->obj_chain;
  }

  sym = alloczero(sizeof(struct Symbol));
  sym->name = name;
  sym->indir_name = iname;
  sym->value = val;
  sym->relsect = s;
  sym->type = type;
  sym->flags = flags;
  sym->info = info;
  sym->bind = bind;
  sym->size = size;

  if (type == SYM_COMMON) {
    /* alignment of .common section must suit the biggest common-alignment */
    uint8_t com_alignment = lshiftcnt(val);

    if (com_alignment > s->alignment)
      s->alignment = com_alignment;
  }

  if (check_protection(gv,name))
    sym->flags |= SYMF_PROTECTED;

  if (bind==SYMB_GLOBAL || bind==SYMB_WEAK) {
    uint16_t flags = ou->lnkfile->flags;

    if (flags & IFF_DELUNDERSCORE) {
      if (*name == '_')
        sym->name = name + 1;  /* delete preceding underscore, if present */
    }
    else if (flags & IFF_ADDUNDERSCORE) {
      char *new_name = alloc(strlen(name) + 2);
      
      *new_name = '_';
      strcpy(new_name+1,name);
      sym->name = new_name;
    }

    if (!addglobsym(gv,sym)) {
      free(sym);
      return NULL;
    }
  }

  *chain = sym;
  return NULL;  /* ok, symbol exists only once in this object */
}


struct Symbol *findlocsymbol(struct GlobalVars *gv,struct ObjectUnit *ou,
                             const char *name)
/* find a symbol which is local to the provided ObjectUnit */
{
  struct Symbol *sym;
  struct Symbol **chain = &ou->objsyms[elf_hash(name)%OBJSYMHTABSIZE];

  while (sym = *chain) {
    if (!strcmp(sym->name,name))
      return sym;
    chain = &sym->obj_chain;
  }
  return NULL;
}


void addlocsymbol(struct GlobalVars *gv,struct Section *s,char *name,
                  char *iname,lword val,uint8_t type,uint8_t flags,
                  uint8_t info,uint32_t size)
/* Define a new local symbol. Local symbols are allowed to be */
/* multiply defined. */
{
  struct Symbol *sym;
  struct Symbol **chain = &s->obj->objsyms[elf_hash(name)%OBJSYMHTABSIZE];

  while (sym = *chain)
    chain = &sym->obj_chain;
  *chain = sym = alloczero(sizeof(struct Symbol));
  sym->name = name;
  sym->indir_name = iname;
  sym->value = val;
  sym->relsect = s;
  sym->type = type;
  sym->flags = flags;
  sym->info = info;
  sym->bind = SYMB_LOCAL;
  sym->size = size;
  if (check_protection(gv,name))
    sym->flags |= SYMF_PROTECTED;
}


struct Symbol *addlnksymbol(struct GlobalVars *gv,const char *name,lword val,
                            uint8_t type,uint8_t flags,uint8_t info,
                            uint8_t bind,uint32_t size)
/* Define a new, target-specific, linker symbol. */
{
  struct Symbol *sym;
  struct Symbol **chain;

  if (gv->lnksyms == NULL)
    gv->lnksyms = alloc_hashtable(LNKSYMHTABSIZE);
  chain = &gv->lnksyms[elf_hash(name)%LNKSYMHTABSIZE];

  while (sym = *chain)
    chain = &sym->obj_chain;
  *chain = sym = alloczero(sizeof(struct Symbol));
  sym->name = name;
  sym->value = val;
  sym->type = type;
  sym->flags = flags;
  sym->info = info;
  sym->bind = bind;
  sym->size = size;
  return sym;
}


struct Symbol *findlnksymbol(struct GlobalVars *gv,const char *name)
/* return pointer to Symbol, if present */
{
  struct Symbol *sym;

  if (gv->lnksyms) {
    sym = gv->lnksyms[elf_hash(name)%LNKSYMHTABSIZE];
    while (sym) {
      if (!strcmp(name,sym->name))
        return sym;  /* symbol found! */
      sym = sym->obj_chain;
    }
  }
  return NULL;
}


static void unlink_lnksymbol(struct GlobalVars *gv,struct Symbol *sym)
/* remove a linker-symbol from its list */
{
  static const char *fn = "unlink_lnksymbol(): ";

  if (gv->lnksyms) {
    struct Symbol *cptr;
    struct Symbol **chain = &gv->lnksyms[elf_hash(sym->name)%LNKSYMHTABSIZE];

    while (cptr = *chain) {
      if (cptr == sym)
        break;
      chain = &cptr->obj_chain;
    }
    if (cptr) {
      /* delete the symbol node from the chain */
      *chain = sym->obj_chain;
      sym->obj_chain = NULL;
    }
    else
      ierror("%s%s could not be found in linker-symbols list",fn,sym->name);
  }
  else
    ierror("%slnksyms==NULL",fn);
}


void fixlnksymbols(struct GlobalVars *gv,struct LinkedSection *def_ls)
{
  struct Symbol *sym,*next;
  int i;

  if (gv->lnksyms) {
    for (i=0; i<LNKSYMHTABSIZE; i++) {
      for (sym=gv->lnksyms[i]; sym; sym=next) {
        next = sym->obj_chain;

        if (sym->flags & SYMF_LNKSYM) {
          if (fff[gv->dest_format]->setlnksym) {
            /* do target-specific symbol modificatios (relsect, value, etc.) */
            fff[gv->dest_format]->setlnksym(gv,sym);

            if (sym->relsect==NULL && def_ls!=NULL) {
              /* @@@ attach absolute symbols to the provided default section */
              if (!listempty(&def_ls->sections))
                sym->relsect = (struct Section *)def_ls->sections.first;
            }
            if (sym->type == SYM_RELOC)
              sym->value += sym->relsect->va;
#if 0 /* @@@ not needed? */
            add_objsymbol(sym->relsect->obj,sym);
#endif
            if (sym->bind >= SYMB_GLOBAL)
              addglobsym(gv,sym);  /* make it globally visible */
            /* add to final output section */
            addtail(&sym->relsect->lnksec->symbols,&sym->n);
            if (gv->map_file)
              print_symbol(gv->map_file,sym);
          }
        }
      }
      gv->lnksyms[i] = NULL;  /* clear chain, it's unusable now! */
    }
  }
}


struct Symbol *find_any_symbol(struct GlobalVars *gv,struct Section *sec,
                               const char *name)
/* return pointer to a global symbol or linker symbol */
{
  struct Symbol *sym = findsymbol(gv,sec,name);

  if (sym == NULL)
    sym = findlnksymbol(gv,name);

  return sym;
}


void reenter_global_objsyms(struct GlobalVars *gv,struct ObjectUnit *ou)
/* Check all global symbols of an object unit against the global symbol
   table for redefinitions or common symbols.
   This is required when a new unit has been pulled into the linking
   process to resolve an undefined reference. */
{
  int i;

  for (i=0; i<OBJSYMHTABSIZE; i++) {
    struct Symbol *sym = ou->objsyms[i];

    while (sym) {
      if (sym->bind==SYMB_GLOBAL) {
        struct Symbol **chain = &gv->symbols[elf_hash(sym->name)%SYMHTABSIZE];
        struct Symbol *gsym;

        while (gsym = *chain) {
          if (!strcmp(sym->name,gsym->name))
            break;
          chain = &gsym->glob_chain;
        }

        if (gsym!=NULL && gsym!=sym) {
          if (sym->type==SYM_COMMON && gsym->type==SYM_COMMON) {
            if ((sym->size>gsym->size && sym->value>=gsym->value) ||
                (sym->size>=gsym->size && sym->value>gsym->value)) {
              /* replace by common symbol with bigger size or alignment */
              sym->glob_chain = gsym->glob_chain;
              remove_obj_symbol(gsym);  /* delete old symbol in object unit */
              *chain = sym;
            }
          }
          else {
            if (ou->lnkfile->type < ID_SHAREDOBJ)  {
              /* Global symbol "x" is already defined in... */
              error(19,ou->lnkfile->pathname,sym->name,getobjname(ou),
                    getobjname(gsym->relsect->obj));
            }
            #if 0
            /* This causes problems when using the same symbols for different
               CPUs, as with WarpOS/68k mixed-binaries (target amigaehf) */
            else {
              /* hide library symbol by replacing its name by:
                 __<object unit name>__<symbol name> */
              char buf[10];
              char *oname,*newname;

              if (ou->objname == NULL) {
                sprintf(buf,"o%08lx",(unsigned long)ou);
                oname = buf;
              }
              else
                oname = ou->objname;
              newname = alloc(strlen(oname) + strlen(sym->name) + 5);
              sprintf(newname,"__%s__%s",oname,sym->name);
              sym->name = newname;
            }
            #endif
          }
        }
      }
      sym = sym->obj_chain;
    }
  }
}


struct Reloc *newreloc(struct GlobalVars *gv,struct Section *sec,
                       const char *xrefname,struct Section *rs,uint32_t id,
                       unsigned long offset,uint8_t rtype,lword addend)
/* allocate and init new relocation structure */
{
  struct Reloc *r = alloczero(sizeof(struct Reloc));

  if (r->xrefname = xrefname) {
    if (sec->obj) {
      uint16_t flags = sec->obj->lnkfile->flags;

      if (flags & IFF_DELUNDERSCORE) {
        if (*xrefname == '_')
          r->xrefname = ++xrefname;
      }
      else if (flags & IFF_ADDUNDERSCORE) {
        char *new_name = alloc(strlen(xrefname) + 2);

        *new_name = '_';
        strcpy(new_name+1,xrefname);
        r->xrefname = new_name;
      }
    }
  }
  if (rs)
    r->relocsect.ptr = rs;
  else
    r->relocsect.id = id;
  r->offset = offset;
  r->addend = addend;
  r->rtype = rtype;
  return r;
}


void addreloc(struct Section *sec,struct Reloc *r,
              uint16_t pos,uint16_t siz,lword mask)
/* Add a relocation description of the current type to this relocation,
   which will be inserted into the sections reloc list, if not
   already done. */
{
  struct RelocInsert *new = alloc(sizeof(struct RelocInsert));
  struct RelocInsert *ri = r->insert;

  new->next = NULL;
  new->bpos = pos;
  new->bsiz = siz;
  new->mask = mask;
  if (ri) {
    while (ri->next)
      ri = ri->next;
    ri->next = new;
  }
  else
    r->insert = new;

  if (r->n.next==NULL && sec!=NULL) {
    if (r->xrefname)
      addtail(&sec->xrefs,&r->n);  /* add to current section's XRef list */
    else
      addtail(&sec->relocs,&r->n);  /* add to current section's Reloc list */
  }
}


bool isstdreloc(struct Reloc *r,uint8_t type,uint16_t size)
/* return true when relocation type matches standard requirements */
{
  struct RelocInsert *ri;

  if (r->rtype==type && (ri = r->insert)!=NULL) {
    if (ri->bpos==0 && ri->bsiz==size && ri->mask==-1 && ri->next==NULL)
      return TRUE;
  }
  return FALSE;
}


struct Reloc *findreloc(struct Section *sec,unsigned long offset)
/* return possible relocation at offset */
{
  if (sec) {
    struct Reloc *reloc;

    for (reloc=(struct Reloc *)sec->relocs.first;
         reloc->n.next!=NULL; reloc=(struct Reloc *)reloc->n.next) {
      if (reloc->offset == offset)
        return reloc;
    }
  }
  return NULL;
}


void addstabs(struct ObjectUnit *ou,struct Section *sec,char *name,
              uint8_t type,int8_t other,int16_t desc,uint32_t value)
/* add an stab entry for debugging */
{
  struct StabDebug *stab = alloc(sizeof(struct StabDebug));

  stab->relsect = sec;
  stab->name.ptr = name;
  if (name) {
    if (*name == '\0')
      stab->name.ptr = NULL;
  }
  stab->n_type = type;
  stab->n_othr = other;
  stab->n_desc = desc;
  stab->n_value = value;
  addtail(&ou->stabs,&stab->n);
}


void fixstabs(struct ObjectUnit *ou)
/* fix offsets of relocatable stab entries */
{
  struct StabDebug *stab;

  for (stab=(struct StabDebug *)ou->stabs.first;
       stab->n.next!=NULL; stab=(struct StabDebug *)stab->n.next) {
    if (stab->relsect) {
      stab->n_value += (uint32_t)stab->relsect->va;
    }
  }
}


struct TargetExt *addtargetext(struct Section *s,uint8_t id,uint8_t subid,
                               uint16_t flags,uint32_t size)
/* Add a new TargetExt structure of given type to a section. The contents */
/* of this structure is target-specific. */
{
  struct TargetExt *te,*newte = alloc(size);

  newte->next = NULL;
  newte->id = id;
  newte->sub_id = subid;
  newte->flags = flags;
  if (te = s->special) {
    while (te->next)
      te = te->next;
    te->next = newte;
  }
  else
    s->special = newte;
  return newte;
}


bool checktargetext(struct LinkedSection *ls,uint8_t id,uint8_t subid)
/* Checks if one of the sections in LinkedSection has a TargetExt */
/* block with the given id. If subid = 0 it will be ignored. */
{
  struct Section *sec = (struct Section *)ls->sections.first;
  struct Section *nextsec;
  struct TargetExt *te;

  while (nextsec = (struct Section *)sec->n.next) {
    if (te = sec->special) {
      do {
        if (te->id==id && (te->sub_id==subid || subid==0))
          return TRUE;
      }
      while (te = te->next);
    }
    sec = nextsec;
  }
  return FALSE;
}


lword readsection(struct GlobalVars *gv,uint8_t rtype,uint8_t *p,
                  uint16_t bpos,uint16_t bsiz,lword mask)
/* Read data from section at 'p', using bit-offset 'bpos' and a field-size
   of 'bsiz' bits. The result is denormalized using the supplied mask.
   Complex RelocInsert scenarios are not supported, but this doesn't
   matter as those relocations have their addend information available
   anyway (ELF: .rela section) and don't need to read it from a section. */
{
  lword v = 0;
  int n;

  p += bpos >> 3;
  bpos &= 7;

  if (n = (bpos + bsiz + 7) >> 3) {
    if (gv->endianess == _LITTLE_ENDIAN_) {
      p += n;
      while (n--) {
        v <<= 8;
        v |= (lword)*(--p);
      }
      v >>= bpos;  /* normalize extracted bit-field */
    }
    else {  /* _BIG_ENDIAN_ or undefined */
      while (n--) {
        v <<= 8;
        v |= (lword)*p++;
      }
      v >>= (8 - ((bpos + bsiz) & 7)) & 7; /* normalize extracted bit-field */
    }
    v &= makemask(bsiz);

    /* mask and denormalize the read value using 'mask' */
    n = lshiftcnt(mask);
    mask >>= n;
    v &= mask;
    if (rtype==R_SD || rtype==R_SD2 || rtype==R_SD21)
      v <<= n;
    else
      v = sign_extend(v,(int)bsiz) << n;  /* sign-extend */
  }

  return v;
}


lword writesection(struct GlobalVars *gv,uint8_t *dest,struct Reloc *r,lword v)
/* Write 'v' into the bit-field defined by the relocation type in 'r'.
   Do range checks first, depending on the reloc type.
   Returns 0 on success or the masked and normalized value which failed
   on the range check. */
{
  struct RelocInsert *ri;

  if (r->rtype == R_NONE)
    return 0;

  if (ri = r->insert) {
    lword lastval = 0;  /* add reloc-addends to this value */
    uint8_t t = r->rtype;
    bool signedval = t==R_PC||t==R_GOTPC||t==R_GOTOFF||t==R_PLTPC||t==R_PLTOFF
                     ||t==R_SD||t==R_SD2||t==R_SD21||t==R_MOSDREL;
    bool be = gv->endianess == _BIG_ENDIAN_;

    do {
      /* first mask and normalize the value, then check if it
         fits into the bitfield */
      lword mask = ri->mask;
      lword insval = v & mask;
      uint8_t *p = dest + (ri->bpos >> 3);
      int bpos = (int)ri->bpos & 7;
      int bsiz = (int)ri->bsiz;
      int n;

      insval >>= lshiftcnt(mask);  /* normalize according mask */
      if (mask>=0 && signedval)
        insval = sign_extend(insval,bsiz);
      insval += lastval;
      lastval = insval;
      if (!checkrange(insval,signedval,bsiz))
        return insval;  /* range check failed on 'insval' */

      /* insert into bitfield, obeying target endianess */
      if (n = (bpos + bsiz + 7) >> 3) {
        if (be) {  /* write for big-endian target */
          int sh = (8 - ((bpos + bsiz) & 7)) & 7;
          uint8_t m = 0xff << sh;  /* mask for LSB */
          uint8_t b;

          insval <<= sh;  /* shift to fit bitfield */
          p += n;
          while (n--) {
            if (!n)
              m &= (1 << (8-(bpos&7))) - 1;  /* apply mask for MSB */

            b = *(--p) & ~m;
            *p = b | ((uint8_t)insval & m);
            insval >>= 8;
            m = 0xff;
          }
        }
        else {  /* write for little-endian target */
          uint8_t m = 0xff << bpos;  /* mask for LSB */
          uint8_t b;

          insval <<= bpos;  /* shift to fit bitfield */
          while (n--) {
            if (!n && ((bpos+bsiz)&7)!=0)
              m &= (1 << ((bpos+bsiz)&7)) - 1;  /* apply mask for MSB */

            b = *p & ~m;
            *p++ = b | ((uint8_t)insval & m);
            insval >>= 8;
            m = 0xff;
          }
        }
      }
    }
    while (ri = ri->next);

    return 0;
  }

  ierror("writesection(): Reloc (type=%d offs=%lu add=%lld) without "
         " insert field def.\n",(int)r->rtype,r->offset,r->addend);
  return -1;
}


void calc_relocs(struct GlobalVars *gv,struct LinkedSection *ls)
/* calculate and insert all relocations of a section */
{
  const char *fn = "calc_reloc(): ";
  struct Reloc *r;

  if (ls == NULL)
    return;

  for (r=(struct Reloc *)ls->relocs.first; r->n.next!=NULL;
       r=(struct Reloc *)r->n.next) {
    lword s,a,p,val;

    if (r->relocsect.lnk == NULL) {
      if (r->flags & RELF_DYNLINK)
        continue;  /* NULL, because it was resolved by a shared object */
      else
        ierror("calc_relocs: Reloc type %d (%s) at %s+0x%lx (addend 0x%llx)"
               " is missing a relocsect.lnk",
               (int)r->rtype,reloc_name[r->rtype],ls->name,r->offset,r->addend);
    }

    s = r->relocsect.lnk->base;
    a = r->addend;
    p = ls->base + r->offset;
    val = 0;

    switch (r->rtype) {

      case R_NONE:
        continue;

      case R_ABS:
        val = s+a;
        break;

      case R_PC:
        val = s+a-p;
        break;

#if 0 /* @@@ shouldn't occur - already resolved by linker_relocate() ??? */
      case R_SD:
        val = s+a - _SDA_BASE_; /* @@@ */
        break;
#endif

      default:
        ierror("%sReloc type %d (%s) is currently not supported",
               fn,(int)r->rtype,reloc_name[r->rtype]);
        break;
    }

    if (val = writesection(gv,ls->data+r->offset,r,val)) {
      struct RelocInsert *ri;

      /* Calculated value doesn't fit into relocation type x ... */
      if (ri = r->insert)
        error(35,gv->dest_name,ls->name,r->offset,val,reloc_name[r->rtype],
              (int)ri->bpos,(int)ri->bsiz,ri->mask);
      else
        ierror("%sReloc (%s+%lx), type=%s, without RelocInsert",
               fn,ls->name,r->offset,reloc_name[r->rtype]);
    }
  }
}


static int reloc_offset_cmp(const void *left,const void *right)
/* qsort: compare relocation offsets */
{
  unsigned long offsl = (*(struct Reloc **)left)->offset;
  unsigned long offsr = (*(struct Reloc **)right)->offset;

  return (offsl<offsr) ? -1 : ((offsl>offsr) ? 1 : 0);
}


void sort_relocs(struct list *rlist)
/* sorts a section's relocation list by their section offsets */
{
  struct Reloc *rel,**rel_ptr_array,**p;
  int cnt = 0;

  /* count relocs and make a pointer array */
  for (rel=(struct Reloc *)rlist->first; rel->n.next!=NULL;
       rel=(struct Reloc *)rel->n.next)
    cnt++;
  if (cnt > 1) {
    rel_ptr_array = alloc(cnt * sizeof(void *));
    for (rel=(struct Reloc *)rlist->first,p=rel_ptr_array;
         rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next)
      *p++ = rel;

    /* sort pointer array */
    qsort(rel_ptr_array,cnt,sizeof(void *),reloc_offset_cmp);

    /* rebuild reloc list from sorted pointer array, then free it */
    initlist(rlist);
    for (p=rel_ptr_array; cnt; cnt--) {
      rel = *p++;
      addtail(rlist,&rel->n);
    }
    free(rel_ptr_array);
  }
}


void add_priptrs(struct GlobalVars *gv,struct ObjectUnit *ou)
/* Inserts all PriPointer nodes of an object into the global list. */
/* The node's position depends on 1. section name, 2. list name, */
/* 3. priority. */
{
  struct PriPointer *newpp,*nextpp,*pp;

  while (newpp = (struct PriPointer *)remhead(&ou->pripointers)) {
    pp = (struct PriPointer *)gv->pripointers.first;

    while (nextpp = (struct PriPointer *)pp->n.next) {
      int c;

      if ((c = strcmp(newpp->secname,pp->secname)) > 0)
        break;
      if (!c) {
        if ((c = strcmp(newpp->listname,pp->listname)) > 0)
          break;
        if (!c && newpp->priority < pp->priority)
          break;
      }
      pp = nextpp;
    }

    if (pp->n.pred)
      insertbefore(&newpp->n,&pp->n);
    else
      addhead(&gv->pripointers,&newpp->n);  /* first node in list */
  }
}


static void new_priptr(struct ObjectUnit *ou,const char *sec,const char *label,
                       int pri,const char *xref,lword addend)
/* Inserts a new longword into the object's PriPointers list. */
{
  struct PriPointer *newpp = alloc(sizeof(struct PriPointer));

  newpp->secname = sec;
  newpp->listname = label;
  newpp->priority = pri;
  newpp->xrefname = xref;
  newpp->addend = addend;
  addtail(&ou->pripointers,&newpp->n);
}


static const char *xtors_secname(struct GlobalVars *gv,const char *defname)
{
  const char *name = defname;

  if (gv->collect_ctors_secname) {
    /* required to put constructors/destructors in non-default sections? */
    if (strcmp(gv->collect_ctors_secname,ctors_name) &&
        strcmp(gv->collect_ctors_secname,dtors_name))
      name = gv->collect_ctors_secname;
  }
  else if (gv->collect_ctors_type == CCDT_SASC)
    name = "__MERGED";
  return name;
}


static void add_xtor_sym(struct GlobalVars *gv,int ctor,const char *name)
/* adds a constructor/destructor dummy symbol for linker_resolve() */
{
  if (ctor ? gv->ctor_symbol==NULL : gv->dtor_symbol==NULL) {
    struct Symbol *sym;

    if (sym = addlnksymbol(gv,name,0,SYM_ABS,0,SYMI_OBJECT,SYMB_GLOBAL,0)) {
      if (ctor)
        gv->ctor_symbol = sym;
      else
        gv->dtor_symbol = sym;
    }
    else
      error(59,name);  /* Can't define symbol as ctors/dtors label */
  }
}


static int vbcc_xtors_pri(const char *s)
/* Return priority of a vbcc constructor/destructor function name.
   Its priority may be specified by a number behind the 2nd underscore.
   Example: _INIT_9_OpenLibs (constructor with priority 9) */
{
  if (*s++ == '_')
    if (isdigit((unsigned)*s))
      return atoi(s);
  return 0;
}


static void add_vbcc_xtors(struct GlobalVars *gv,struct list *objlist,
                           const char *cname,const char *dname,
                           const char *csecname,const char *dsecname,
                           const char *clabel,const char *dlabel)
{
  struct ObjectUnit *obj;
  int clen = strlen(cname);
  int dlen = strlen(dname);
  int i;

  for (obj=(struct ObjectUnit *)objlist->first;
       obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
    for (i=0; i<OBJSYMHTABSIZE; i++) {
      struct Symbol *sym = obj->objsyms[i];

      while (sym) {
        if (sym->bind==SYMB_GLOBAL) {
          if (!strncmp(sym->name,cname,clen)) {
            new_priptr(obj,csecname,clabel,vbcc_xtors_pri(sym->name+clen),
                       sym->name,0);
          }
          else if (!strncmp(sym->name,dname,dlen))
            new_priptr(obj,dsecname,dlabel,vbcc_xtors_pri(sym->name+dlen),
                       sym->name,0);
        }
        sym = sym->obj_chain;
      }
    }

    if (objlist == &gv->selobjects)
      add_priptrs(gv,obj);  /* con-/destructors are already known */
  }
}


static int sasc_xtors_pri(const char *s)
/* Return priority of a SAS/C constructor/destructor function name.
   Its priority may be specified by a number behind the 2nd underscore.
   For SAS/C a lower value means higher priority!
   Example: _INIT_110_OpenLibs (constructor with priority 110) */
{
  if (*s++ == '_')
    if (isdigit((unsigned)*s))
      return 30000-atoi(s);  /* 30000 is the default priority, i.e. 0 */
  return 0;
}


static void add_sasc_xtors(struct GlobalVars *gv,struct list *objlist,
                           const char *cname,const char *dname,
                           const char *csecname,const char *dsecname,
                           const char *clabel,const char *dlabel)
{
  struct ObjectUnit *obj;
  int clen = strlen(cname);
  int dlen = strlen(dname);
  int i;

  for (obj=(struct ObjectUnit *)objlist->first;
       obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
    for (i=0; i<OBJSYMHTABSIZE; i++) {
      struct Symbol *sym = obj->objsyms[i];

      while (sym) {
        if (sym->bind==SYMB_GLOBAL) {
          if (!strncmp(sym->name,cname,clen)) {
            new_priptr(obj,csecname,clabel,sasc_xtors_pri(sym->name+clen),
                       sym->name,0);
          }
          else if (!strncmp(sym->name,dname,dlen))
            new_priptr(obj,dsecname,dlabel,sasc_xtors_pri(sym->name+dlen),
                       sym->name,0);
        }
        sym = sym->obj_chain;
      }
    }

    if (objlist == &gv->selobjects)
      add_priptrs(gv,obj);  /* con-/destructors are already known */
  }
}


void collect_constructors(struct GlobalVars *gv)
/* Scan all selected and unselected object modules for constructor-
   and destructor functions of the required type. */
{
  if (!gv->dest_object) {
    const char *sasc_ctor = "__STI";
    const char *sasc_dtor = "__STD";
    const char *vbcc_ctor = "__INIT";
    const char *vbcc_dtor = "__EXIT";
    const char *ctor_label = "___CTOR_LIST__";
    const char *dtor_label = "___DTOR_LIST__";
    const char *csec = xtors_secname(gv,ctors_name);
    const char *dsec = xtors_secname(gv,dtors_name);

    switch (gv->collect_ctors_type) {

      case CCDT_NONE:
        break;

      case CCDT_GNU:
        break;  /* @@@ already put into .ctors/.dtors anyway? */

      case CCDT_VBCC_ELF:  /* no leading underscores */
        vbcc_ctor++;
        vbcc_dtor++;
        ctor_label++;
        dtor_label++;
      case CCDT_VBCC:
        add_xtor_sym(gv,1,ctor_label);  /* define __CTOR_LIST__ */
        add_vbcc_xtors(gv,&gv->selobjects,
                       vbcc_ctor,vbcc_dtor,csec,dsec,ctor_label,dtor_label);
        add_xtor_sym(gv,0,dtor_label);  /* define __DTOR_LIST__ */
        add_vbcc_xtors(gv,&gv->libobjects,
                       vbcc_ctor,vbcc_dtor,csec,dsec,ctor_label,dtor_label);
        break;

      case CCDT_SASC:
        /* ___ctors/___dtors will be directed to __CTOR_LIST__/__DTOR_LIST */
        add_xtor_sym(gv,1,ctor_label);  /* define __CTOR_LIST__ */
        add_sasc_xtors(gv,&gv->selobjects,
                       sasc_ctor,sasc_dtor,csec,dsec,ctor_label,dtor_label);
        add_xtor_sym(gv,0,dtor_label);  /* define __DTOR_LIST__ */
        add_sasc_xtors(gv,&gv->libobjects,
                       sasc_ctor,sasc_dtor,csec,dsec,ctor_label,dtor_label);
        break;

      default:
        ierror("collect_constructors(): Unsupported type: %u\n",
               gv->collect_ctors_type);
        break;
    }
  }
}


struct Section *find_sect_type(struct ObjectUnit *ou,uint8_t type,uint8_t prot)
/* find a section in current object unit with approp. type and protection */
{
  struct Section *sec;

  for (sec=(struct Section *)ou->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    if (sec->type==type && (sec->protection&prot)==prot
        && (sec->flags & SF_ALLOC))
      return sec;
  }
  return NULL;
}


struct Section *find_sect_id(struct ObjectUnit *ou,uint32_t id)
/* find a section by its identification value */
{
  struct Section *sec;

  for (sec=(struct Section *)ou->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    if (sec->id == id)
      return sec;
  }
  return NULL;
}


struct Section *find_sect_name(struct ObjectUnit *ou,const char *name)
/* find a section by its name */
{
  struct Section *sec;

  for (sec=(struct Section *)ou->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    if (!strcmp(name,sec->name))
      return sec;
  }
  return NULL;
}


struct Section *find_first_bss_sec(struct LinkedSection *ls)
/* returns pointer to first BSS-type section in list, or zero */
{
  struct Section *sec;

  for (sec=(struct Section *)ls->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    if (sec->flags & SF_UNINITIALIZED)
      return sec;
  }
  return NULL;
}


struct LinkedSection *find_lnksec(struct GlobalVars *gv,const char *name,
                                  uint8_t type,uint8_t flags,uint8_t fmask,
                                  uint8_t prot)
/* Return pointer to the first section which fits the passed */
/* name-, type- and flags-conditions. If a condition is 0, then */
/* it is ignored. If no appropriate section was found, return NULL. */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextls;

  while (nextls = (struct LinkedSection *)ls->n.next) {
    bool found = TRUE;

    if (name)
      if (strcmp(ls->name,name))
        found = FALSE;
    if (type)
      if (ls->type != type)
        found = FALSE;
    if (fmask)
      if ((ls->flags&fmask) != (flags&fmask))
        found = FALSE;
    if (prot)
      if ((ls->protection & prot) != prot)
        found = FALSE;
    if (found)
      return ls;
    ls = nextls;
  }
  return NULL;
}


struct ObjectUnit *create_objunit(struct GlobalVars *gv,
                                  struct LinkFile *lf,const char *objname)
/* creates and initializes an ObjectUnit node */
{
  struct ObjectUnit *ou = alloc(sizeof(struct ObjectUnit));

  ou->lnkfile = lf;
  if (objname)
    ou->objname = objname;
  else
    ou->objname = noname;
  initlist(&ou->sections);  /* empty section list */
  ou->common = ou->scommon = NULL;
  ou->objsyms = alloc_hashtable(OBJSYMHTABSIZE);
  initlist(&ou->stabs);  /* empty stabs list */
  initlist(&ou->pripointers);  /* empty PriPointer list */
  ou->flags = 0;
  ou->min_alignment = gv->min_alignment;
  return ou;
}


struct ObjectUnit *art_objunit(struct GlobalVars *gv,const char *n,
                               uint8_t *d,unsigned long len)
/* creates and initializes an artificial linker-object */
{
  struct LinkFile *lf = alloczero(sizeof(struct LinkFile));

  lf->pathname = lf->filename = lf->objname = n;
  lf->data = d;
  lf->length = len;
  lf->format = gv->dest_format;
  lf->type = ID_ARTIFICIAL;
  return create_objunit(gv,lf,n);
}


void add_objunit(struct GlobalVars *gv,struct ObjectUnit *ou,bool fixrelocs)
/* adds an ObjectUnit to the approriate list */
{
  if (ou) {
    uint8_t t = ou->lnkfile->type;

    if (t==ID_LIBARCH && gv->whole_archive)
      t = ID_OBJECT;  /* force linking of a whole archive */

    switch (t) {
      case ID_OBJECT:
      case ID_EXECUTABLE:
        ou->flags |= OUF_LINKED;  /* objects are always linked */
        addtail(&gv->selobjects,&ou->n);
        break;
      case ID_LIBARCH:
        addtail(&gv->libobjects,&ou->n);
        break;
      case ID_SHAREDOBJ:
        addtail(&gv->sharedobjects,&ou->n);
        break;
      default:
        ierror("add_objunit(): Link File type = %d",
               (int)ou->lnkfile->type);
    }

    if (fixrelocs) {  /* convert section index into address */
      struct Section *sec;
      struct Reloc *r;
      uint32_t idx;

      for (sec=(struct Section *)ou->sections.first;
           sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
        for (r=(struct Reloc *)sec->relocs.first;
             r->n.next!=NULL; r=(struct Reloc *)r->n.next) {
          idx = r->relocsect.id;
          if ((r->relocsect.ptr = find_sect_id(ou,idx)) == NULL) {
            /* section with this index doesn't exist */
            error(52,ou->lnkfile->pathname,sec->name,getobjname(ou),(int)idx);
          }
        }
      }
    }
  }
}


struct SecAttrOvr *addsecattrovr(struct GlobalVars *gv,char *name,
                                 uint32_t flags)
/* Create a new SecAttrOvr node and append it to the list. When a node
   for the same input section name is already present, then reuse it.
   Print a warning, when trying to reset the same attribute. */
{
  struct SecAttrOvr *sao;

  for (sao=gv->secattrovrs; sao!=NULL; sao=sao->next) {
    if (!strcmp(sao->name,name))
      break;
  }

  if (sao != NULL) {
    if ((sao->flags & flags) != 0)
      error(129,name);  /* resetting attribute for section */
  }
  else {
    struct SecAttrOvr *prev = gv->secattrovrs;

    sao = alloczero(sizeof(struct SecAttrOvr)+strlen(name));
    strcpy(sao->name,name);
    if (prev) {
      while (prev->next)
        prev = prev->next;
      prev->next = sao;
    }
    else
      gv->secattrovrs = sao;
  }

  sao->flags |= flags;
  return sao;
}


struct SecAttrOvr *getsecattrovr(struct GlobalVars *gv,const char *name,
                                 uint32_t flags)
/* Return a SecAttrOvr node which matches section name and flags. */
{
  struct SecAttrOvr *sao;

  for (sao=gv->secattrovrs; sao!=NULL; sao=sao->next) {
    if (!strcmp(sao->name,name) && (sao->flags & flags)!=0)
      break;
  }
  return sao;
}


struct Section *create_section(struct ObjectUnit *ou,const char *name,
                               uint8_t *data,unsigned long size)
/* creates and initializes a Section node */
{
  static uint32_t idcnt = 0;
  struct Section *s = alloczero(sizeof(struct Section));

  if (name)
    s->name = name;
  else
    s->name = noname;
  s->data = data;
  s->size = size;
  s->obj = ou;
  s->id = idcnt++;       /* target dependant - ELF replaces this with shndx */
  initlist(&s->relocs);  /* empty relocation list */
  initlist(&s->xrefs);   /* empty xref list */
  return s;
}


struct Section *add_section(struct ObjectUnit *ou,const char *name,
                            uint8_t *data,unsigned long size,
                            uint8_t type,uint8_t flags,uint8_t protection,
                            uint8_t align,bool inv)
/* create a new section and add it to the object ou */
{
  struct Section *sec = create_section(ou,name,data,size);

  sec->type = type;
  sec->flags = flags;
  sec->protection = protection;
  sec->alignment = ou->min_alignment>align ? ou->min_alignment : align;
  if (inv)
    sec->id = INVALID;
  if (type != ST_TMP)  /* TMP sections must not be part of the link process */
    addtail(&ou->sections,&sec->n);
  return sec;
}


struct Section *common_section(struct GlobalVars *gv,struct ObjectUnit *ou)
/* returns the dummy section for COMMON symbols, or creates it */
{
  struct Section *s;

  if (!(s = ou->common)) {
    s = add_section(ou,gv->common_sec_name,NULL,0,ST_UDATA,
                    SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,0,TRUE);
    ou->common = s;
  }
  return s;
}


struct Section *scommon_section(struct GlobalVars *gv,struct ObjectUnit *ou)
/* returns the dummy section for small-data COMMON symbols, or creates it */
{
  struct Section *s;

  if (!(s = ou->scommon)) {
    s = add_section(ou,gv->scommon_sec_name,NULL,0,ST_UDATA,
                    SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,0,TRUE);
    if (ou->common)
      s->alignment = ou->common->alignment;  /* inherit .common alignment */
    ou->scommon = s;
  }
  return s;
}


struct Section *abs_section(struct ObjectUnit *ou)
/* return first section available or create a new one */
{
  struct Section *s;

  if (listempty(&ou->sections))
    s = add_section(ou,noname,NULL,0,ST_UDATA,
                    SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,0,TRUE);
  else
    s = (struct Section *)ou->sections.first;

  return s;
}


struct Section *dummy_section(struct GlobalVars *gv,struct ObjectUnit *ou)
/* Make a dummy section already attached to a dummy-LinkedSection, which
   won't appear in any section lists.
   Can be used for relocatable linker symbols, which need a specific value. */
{
  struct Section *s;

  if (!(s = gv->dummysec)) {
    struct LinkedSection *ls = alloczero(sizeof(struct LinkedSection));

    s = add_section(ou,"*linker*",NULL,0,ST_TMP,
                    SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,0,TRUE);
    s->lnksec = ls;
    ls->name = s->name;
    ls->type = s->type;
    ls->flags = s->flags;
    ls->protection = s->protection;
    ls->index = INVALID;
    initlist(&ls->sections);
    initlist(&ls->relocs);
    initlist(&ls->xrefs);
    initlist(&ls->symbols);
    gv->dummysec = s;
  }
  return s;
}


struct LinkedSection *create_lnksect(struct GlobalVars *gv,const char *name,
                                     uint8_t type,uint8_t flags,
                                     uint8_t protection,uint8_t alignment,
                                     uint32_t memattr)
/* create and initialize a LinkedSection node and include */
/* it in the global list */
{
  struct LinkedSection *ls = alloczero(sizeof(struct LinkedSection));

  ls->index = gv->nsecs++;
  ls->name = name;
  ls->type = type;
  ls->flags = flags;
  ls->protection = protection;
  ls->alignment = alignment;
  ls->memattr = memattr;
  initlist(&ls->sections);
  initlist(&ls->relocs);
  initlist(&ls->xrefs);
  initlist(&ls->symbols);
  addtail(&gv->lnksec,&ls->n);
  return ls;
}


static struct Section *add_xtor_section(struct GlobalVars *gv,
                                        struct ObjectUnit *ou,const char *name,
                                        uint8_t *data,unsigned long size)
{
  struct Section *sec = add_section(ou,name,data,size,ST_DATA,
                                    SF_ALLOC,SP_READ|SP_WRITE,2,FALSE);
  struct SecAttrOvr *sao;

  if (sao = getsecattrovr(gv,name,SAO_MEMFLAGS))
    sec->memattr = sao->memflags;

  return sec;
}


static void write_constructors(struct GlobalVars *gv,struct ObjectUnit *ou,
                               struct Symbol *labelsym,int cnt,
                               lword offset,const char *secname)
{
  uint8_t *data = ou->lnkfile->data + offset;
  unsigned long asize = (unsigned long)fff[gv->dest_format]->addr_bits / 8;
  struct Section *sec;
  struct PriPointer *pp;
  int extraslots;

  /* Format for vbcc constructors: <num>, [ <ptrs>... ], NULL */
  /* Format for SAS/C constructors: [ <ptrs>...], NULL */
  switch (gv->collect_ctors_type) {
    case CCDT_SASC:
      extraslots = 1;
      break;
    default:
      extraslots = 2;
      break;
  }
  /* create a new section, if required */
  for (sec=(struct Section *)ou->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    if (!strcmp(secname,sec->name))
      break;
  }
  if (sec->n.next == NULL) {
    sec = add_xtor_section(gv,ou,secname,ou->lnkfile->data+offset,
                           extraslots*asize);
    offset = 0;
  }
  else
    sec->size += extraslots*asize;

  /* assign constructor/destructor label symbol to start of list */
  unlink_lnksymbol(gv,labelsym);
  labelsym->relsect = sec;
  labelsym->type = SYM_RELOC;
  labelsym->value = offset;
  labelsym->size = extraslots * asize;
  add_objsymbol(ou,labelsym);
  addglobsym(gv,labelsym);  /* make it globally visible */

  if (gv->collect_ctors_type != CCDT_SASC) {
    data += writetaddr(gv,data,(lword)cnt);
    offset += asize;
  }

  /* write con-/destructor pointers */
  for (pp=(struct PriPointer *)gv->pripointers.first;
       pp->n.next!=NULL; pp=(struct PriPointer *)pp->n.next) {
    if (!strcmp(pp->listname,labelsym->name)) {
      struct Reloc *r;

      data += writetaddr(gv,data,pp->addend);
      if (pp->xrefname) {
        r = newreloc(gv,sec,pp->xrefname,NULL,0,(unsigned long)offset,
                     R_ABS,pp->addend);
        addreloc(sec,r,0,asize<<3,-1);
      }
      sec->size += asize;
      labelsym->size += asize;
      offset += asize;
    }
  }
}


void make_constructors(struct GlobalVars *gv)
/* Create an artificial object for constructor/destructor lists
   and fill them will entries from the PriPointer list. */
{
  if (!gv->dest_object && (gv->ctor_symbol || gv->dtor_symbol)) {
    int nctors=0,ndtors=0;
    bool ctors=FALSE,dtors=FALSE;
    const char *csecname=NULL,*dsecname=NULL;
    unsigned long clen,dlen;
    struct PriPointer *pp;
    uint8_t *data;
    struct ObjectUnit *ou;

    /* check if constructors or destructors are needed (referenced) */
    if (gv->ctor_symbol) {
      if (gv->ctor_symbol->flags & SYMF_REFERENCED) {
        ctors = TRUE;
        for (pp=(struct PriPointer *)gv->pripointers.first;
             pp->n.next!=NULL; pp=(struct PriPointer *)pp->n.next) {
          if (!strcmp(pp->listname,gv->ctor_symbol->name)) {
            if (csecname) {
              if (strcmp(csecname,pp->secname))
                error(125);  /* CTORS/DTORS spread over multiple sections */
            }
            else
              csecname = pp->secname;
          }
        }
        if (!csecname)
          csecname = xtors_secname(gv,ctors_name);
      }
    }
    if (gv->dtor_symbol) {
      if (gv->dtor_symbol->flags & SYMF_REFERENCED) {
        dtors = TRUE;
        for (pp=(struct PriPointer *)gv->pripointers.first;
             pp->n.next!=NULL; pp=(struct PriPointer *)pp->n.next) {
          if (!strcmp(pp->listname,gv->dtor_symbol->name)) {
            if (dsecname) {
              if (strcmp(dsecname,pp->secname))
                error(125);  /* CTORS/DTORS spread over multiple sections */
            }
            else
              dsecname = pp->secname;
          }
        }
        if (!dsecname)
          dsecname = xtors_secname(gv,dtors_name);
      }
    }
    if (!ctors && !dtors)
      return;

    /* count number of constructor and destructor pointers */
    for (pp=(struct PriPointer *)gv->pripointers.first;
         pp->n.next!=NULL; pp=(struct PriPointer *)pp->n.next) {
      if (ctors) {
        if (!strcmp(pp->listname,gv->ctor_symbol->name))
          nctors++;
      }
      if (dtors) {
        if (!strcmp(pp->listname,gv->dtor_symbol->name))
          ndtors++;
      }
    }

    /* create artificial object */
    clen = (unsigned long)(fff[gv->dest_format]->addr_bits / 8) *
            (ctors ? nctors+2 : 0);
    dlen = (unsigned long)(fff[gv->dest_format]->addr_bits / 8) *
            (dtors ? ndtors+2 : 0);
    data = alloczero(clen + dlen);
    ou = art_objunit(gv,"INITEXIT",data,clen+dlen);

    /* write constructors/destructors */
    if (ctors)
      write_constructors(gv,ou,gv->ctor_symbol,nctors,0,csecname);
    if (dtors)
      write_constructors(gv,ou,gv->dtor_symbol,ndtors,clen,dsecname);

    /* enqueue artificial object unit into linking process */
    ou->lnkfile->type = ID_OBJECT;
    add_objunit(gv,ou,FALSE);
  }
}


struct LinkedSection *smalldata_section(struct GlobalVars *gv)
/* Return pointer to first small data LinkedSection. If not existing, */
/* return first data/bss section or the first section. */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *ldls=NULL,*firstls=NULL,*nextls;

  while (nextls = (struct LinkedSection *)ls->n.next) {
    if ((ls->flags & SF_ALLOC) && ls->size!=0) {
      if (firstls == NULL)
        firstls = ls;
      if (ls->type==ST_DATA || ls->type==ST_UDATA && ldls==NULL)
        ldls = ls;
      if (ls->flags & SF_SMALLDATA)  /* first SD section found! */
        return ls;
    }
    ls = nextls;
  }
  return ldls ? ldls : firstls;
}


void get_text_data_bss(struct GlobalVars *gv,struct LinkedSection **sections)
/* find exactly one ST_CODE, ST_DATA and ST_UDATA section, which
   will become .text, .data and .bss */
{
  static const char *fn = "get_text_data_bss(): ";
  struct LinkedSection *ls;

  sections[0] = sections[1] = sections[2] = NULL;
  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    if (ls->flags & SF_ALLOC) {
      switch (ls->type) {
        case ST_UNDEFINED:
          /* @@@ discard undefined sections - they are empty anyway */
          ls->flags &= ~SF_ALLOC;
          break;
        case ST_CODE:
          if (sections[0]==NULL)
            sections[0] = ls;
          else
            ierror("%sMultiple code sections (%s)",fn,ls->name);
          break;
        case ST_DATA:
          if (sections[1]==NULL)
            sections[1] = ls;
          else
            ierror("%sMultiple data sections (%s)",fn,ls->name);
          break;
        case ST_UDATA:
          if (sections[2]==NULL)
            sections[2] = ls;
          else
            ierror("%sMultiple bss sections (%s)",fn,ls->name);
          break;
        default:
          ierror("%sIllegal section type %d (%s)",fn,(int)ls->type,ls->name);
          break;
      }
    }
  }
}


void text_data_bss_gaps(struct LinkedSection **sections)
/* calculate gap size between text-data and data-bss */
{
  if (sections[0]) {
    unsigned long nextsecbase = sections[1] ? sections[1]->base :
                                (sections[2] ? sections[2]->base : 0);
    if (nextsecbase) {
      sections[0]->gapsize = nextsecbase -
                             (sections[0]->base + sections[0]->size);
    }
  }
  if (sections[1] && sections[2]) {
    sections[1]->gapsize = sections[2]->base -
                           (sections[1]->base + sections[1]->filesize);
  }
}


bool discard_symbol(struct GlobalVars *gv,struct Symbol *sym)
/* checks if symbol can be discarded and excluded from the output file */
{
  if (sym->flags & SYMF_PROTECTED)
    return FALSE;

  if (gv->strip_symbols < STRIP_ALL) {
    if (sym->bind!=SYMB_LOCAL || gv->discard_local==DISLOC_NONE)
      return FALSE;

    if (gv->discard_local==DISLOC_TMP) {
      char c = sym->name[0];

      if (!((c=='L' || c=='l' || c=='.') && isdigit((unsigned)sym->name[1])))
        return FALSE;
    }
  }
  return TRUE;
}


lword entry_address(struct GlobalVars *gv)
/* returns address of entry point for executables */
{
  struct Symbol *sym;
  struct LinkedSection *ls;

  if (gv->entry_name) {
    lword entry = 0;

    if (sym = findsymbol(gv,NULL,gv->entry_name)) {
      return (lword)sym->value;
    }
    else if (isdigit((unsigned char)*gv->entry_name)) {
      if (sscanf(gv->entry_name,"%lli",&entry) == 1)
        return entry;
    }
  }

  /* plan b: search for _start symbol: */
  if (sym = findsymbol(gv,NULL,"_start"))
      return (lword)sym->value;

  /* plan c: search for first executable section */
  if (ls = find_lnksec(gv,NULL,ST_CODE,SF_ALLOC,SF_ALLOC|SF_UNINITIALIZED,
                       SP_READ|SP_EXEC))
    return (lword)ls->base;

  return 0;
}


struct Symbol *bss_entry(struct ObjectUnit *ou,const char *secname,
                         struct Symbol *xdef)
/* Create a BSS section in the object ou with space for xdef's size. 
   The symbol will be changed to the base address of this section and
   enqueued in the section's object symbol list.
   A size of 0 will leave the symbol untouched (no need to copy), which
   is indicated by returning NULL.
   This function is called for R_COPY objects, used for dynamic linking. */
{
  if (xdef->size) {
    /* change xdef to point to our new object in sec */
    unlink_objsymbol(xdef);
    xdef->value = 0;
    xdef->relsect = add_section(ou,secname,NULL,xdef->size,ST_UDATA,
                                SF_ALLOC|SF_UNINITIALIZED,
                                SP_READ|SP_WRITE,2,TRUE);
    add_objsymbol(ou,xdef);
    return xdef;
  }

  return NULL;
}
