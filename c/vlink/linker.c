/* $VER: vlink linker.c V0.15a (27.02.16)
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


#define LINKER_C
#include "vlink.h"


static char namebuf[FNAMEBUFSIZE];
static char namebuf2[FNAMEBUFSIZE];

static const char *filetypes[] = {
  "unknown",
  "object",
  "executable",NULL,
  "shared object",NULL,NULL,NULL,
  "library"
};

static const char *sec_names[] = {
  "undefined","code","data","bss",NULL
};


#ifdef DEBUG
#define Dprintf(...) printf(__VA_ARGS__)

#else
#if (defined _WIN32) && (_MSC_VER < 1400)
/* MSVCs older than MSVC2005 do not handle variadic macros; for these
   compilers, we create a dummy function instead of the macro */
static void Dprintf(const char *format, ...) { }
#else
#define Dprintf(...)
#endif
#endif



const char *getobjname(struct ObjectUnit *obj)
/* if library: return "file name(object name)" */
/* else: return "file name" */
{
  const char *fn = obj->lnkfile->filename;

  if (obj->lnkfile->type == ID_LIBARCH) {
    const char *on = obj->objname;
    if (strlen(fn)+strlen(on)+2 < FNAMEBUFSIZE) {
      snprintf(namebuf,FNAMEBUFSIZE,"%s(%s)",fn,on);
      return (namebuf);
    }
  }
  return (fn);
}


void print_function_name(struct Section *sec,unsigned long offs)
/* Try to determine the function to which the section offset */
/* belongs, by comparing with SYMI_FUNC-type symbol definitions. */
/* If this was successful and the current function is different */
/* from the last one printed, make an output to stderr. */
{
  static const char *infoname[] = { "", "object ", "function " };
  static struct Symbol *last_func=NULL;
  struct Symbol *sym,*func=NULL;
  int i;

  for (i=0; i<OBJSYMHTABSIZE; i++) {  /* scan all hash chains */
    for (sym=sec->obj->objsyms[i]; sym; sym=sym->obj_chain) {
      if (sym->relsect == sec) {
        if (sym->info <= SYMI_FUNC) {
          if (sym->type == SYM_RELOC) {
            if ((unsigned long)sym->value <= offs) {
              if (sym->size) {  /* size of function specified? */
                if ((unsigned long)(sym->value+sym->size) > offs) {
                  func = sym;
                  i = OBJSYMHTABSIZE;
                  break;  /* function found! */
                }
              }
              else {  /* no size - find nearest... */
                if (func) {
                  if (sym->value > func->value) {
                    if (func->bind<SYMB_GLOBAL || sym->bind>=SYMB_GLOBAL)
                      func = sym;
                  }
                }
                else
                  func = sym;
              }
            }
          }
        }
      }
    }
  }

  /* print function name */
  if (func && func!=last_func) {
    last_func = func;
    fprintf(stderr,"%s: In %s\"%s\":\n",getobjname(sec->obj),
            infoname[func->info],func->name);
  }
}


static void undef_sym_error(struct Section *sec,struct Reloc *rel,
                            const char *symname)
{
  print_function_name(sec,rel->offset);
  error(21,getobjname(sec->obj),sec->name,rel->offset-sec->offset,symname);
}


static struct Symbol *lnksymbol(struct GlobalVars *gv,struct Section *sec,
                                struct Reloc *xref)
{
  struct Symbol *sym;

  if (sym = findlnksymbol(gv,xref->xrefname))
    return (sym);

  if (fff[gv->dest_format]->lnksymbol)
    return (fff[gv->dest_format]->lnksymbol(gv,sec,xref));

  return (NULL);
}


static char *scan_directory(char *dirname,char *libname,int so_ver)
{
  size_t lnlen=strlen(libname);
  char *dd,*scan,*fname=NULL;
  char maxname[FNAMEBUFSIZE];
  int maxver=0,maxsubver=-1;

  if (so_ver < 0) {
    /* no need to scan the directory */
    fname = libname;
  }
  else {
    if (dd = open_dir(dirname)) {
      while (scan = read_dir(dd)) {
        if (!strncmp(scan,libname,lnlen)) {
          /* found a library archive/shared object name! */
          if (!strcmp(scan,libname) && so_ver==0) {  /* perfect match */
            fname = scan;
            break;
          }
          else {  /* find highest version */
            if (scan[lnlen]=='.' && scan[lnlen+1]) {
              char *p = &scan[lnlen+1];
              int ver = atoi(p++);
              int subver = 0;

              while (*p!='\0' && *p!='.')
                p++;
              if (*p++ == '.')
                subver = atoi(p);

              if (so_ver==0 || so_ver==ver) {
                if ((ver>maxver || (ver==maxver && subver>maxsubver)) &&
                    strlen(scan)<(FNAMEBUFSIZE-1)) {
                  fname = maxname;
                  maxver = ver;
                  maxsubver = subver;
                  strcpy(maxname,scan);
                }
              }
            }
          }
        }
      }
      close_dir(dd);
    }
  }

  if (fname) {
    char *p,*fullpath;

    if (fullpath = path_append(namebuf,dirname,fname,FNAMEBUFSIZE)) {
      if (p = mapfile(fullpath))
        return (p);
    }
  }
  return (NULL);
}


static char *searchlib(struct GlobalVars *gv,char *libname,int so_ver)
{
  struct LibPath *lpn = (struct LibPath *)gv->libpaths.first;
  struct LibPath *nextlpn;
  char *p,*path,*flavour_dir;
  int i,count;
  size_t len;

  if (p = scan_directory(".",libname,so_ver))
    return (p);

  while (nextlpn = (struct LibPath *)lpn->n.next) {
    for (count=gv->flavours.n_flavours; count>=0; count--) {
      flavour_dir = gv->flavours.flavour_dir;
      for (flavour_dir[0]='\0',i=0; i<count; i++) {
        if (!path_append(flavour_dir,flavour_dir,gv->flavours.flavours[i],
                         gv->flavours.flavours_len + 1))
          ierror("searchlib(): flavour \"%s\" doesn't fit into path buffer",
                 gv->flavours.flavours[i]);
      }
      len = strlen(lpn->path) + strlen(flavour_dir) + 3;
      if (len < FNAMEBUFSIZE) {
        path = path_append(namebuf2,lpn->path,flavour_dir,FNAMEBUFSIZE);
        if (p = scan_directory(path,libname,so_ver))
          return (p);
      }
    }
    lpn = nextlpn;
  }
  return (NULL);
}


static char *maplibrary(struct GlobalVars *gv,struct InputFile *ifn)
/* Map a complete file into memory and return its address. */
/* The file's length is returned in *(p-sizeof(size_t)). */
/* All defined library paths will be searched for the file, */
/* before aborting. On success, the complete path of the loaded */
/* file is stored in namebuf[]. */
{
  char *p;
  char libname[FNAMEBUFSIZE];

  if (strlen(ifn->name) < (FNAMEBUFSIZE-16)) {
    if (ifn->dynamic) {
      snprintf(libname,FNAMEBUFSIZE,"lib%s.so",ifn->name);
      if (p = searchlib(gv,libname,ifn->so_ver))
        return (p);
    }
    snprintf(libname,FNAMEBUFSIZE,"lib%s.a",ifn->name);
    if (p = searchlib(gv,libname,-1))
      return (p);
    snprintf(libname,FNAMEBUFSIZE,"%s.lib",ifn->name);
    if (p = searchlib(gv,libname,-1))
      return (p);
  }
  return (NULL);
}


static void addrelref(struct RelRef **rrptr,struct Section *sec)
/* if not already exists, add a new relative reference to another sect. */
{
  struct RelRef *rr;

  if (rr = *rrptr) {
    while (rr->next) {
      if (rr->refsec == sec)
        return;  /* reference already exists */
      rr = rr->next;
    }
  }
  else
    rr = (struct RelRef *)rrptr;

  rr->next = alloczero(sizeof(struct RelRef));
  rr->next->refsec = sec;
}


static bool checkrr(struct RelRef *rr,struct Section *sec)
/* Check if there is a relative reference to the specified section. */
{
  while (rr) {
    if (rr->refsec == sec)
      return (TRUE);
    rr = rr->next;
  }
  return (FALSE);
}


static bool checkrelrefs(struct LinkedSection *ls,struct Section *newsec)
/* Check if there is a relative reference between those sections */
{
  struct Section *sec;

  for (sec=(struct Section *)ls->sections.first;
       sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
    /* check for references to 'newsec' */
    if (checkrr(sec->relrefs,newsec))
      return (TRUE);
    /* check for references from 'newsec' */
    if (checkrr(newsec->relrefs,sec))
      return (TRUE);
  }
  return (FALSE);
}


static char *protstring(uint8_t prot)
/* return pointer to protection string - example: "r---" or "rwxs" */
{
  static char ps[] = "----";
  char *p = ps;

  *p++ = (prot & SP_READ) ? 'r' : '-';
  *p++ = (prot & SP_WRITE) ? 'w' : '-';
  *p++ = (prot & SP_EXEC) ? 'x' : '-';
  *p++ = (prot & SP_SHARE) ? 's' : '-';
  return (ps);
}


static uint8_t cmpsecflags(struct GlobalVars *gv,struct LinkedSection *ls,
                           struct Section *sec)
/* return 0xff if sections are incompatible, otherwise return new flags */
{
  uint8_t old = ls->flags;
  uint8_t new = sec->flags;

  if (ls->ld_flags & LSF_NOLOAD)
    new &= ~SF_ALLOC;
  else if ((old&SF_ALLOC) != (new&SF_ALLOC))
    return 0xff;

  return (fff[gv->dest_format]->cmpsecflags != NULL) ?
         fff[gv->dest_format]->cmpsecflags(ls,sec) : (old | new);
}


static void merge_sec_attrs(struct LinkedSection *lsn,struct Section *sec,
                            uint8_t target_flags)
{
  if (lsn->type == ST_UNDEFINED) {
    lsn->type = sec->type;
    lsn->flags = sec->flags;
    lsn->memattr = sec->memattr;
  }
  else {
    if (lsn->type==ST_UDATA && sec->type==ST_DATA)
      lsn->type = ST_DATA;  /* a DATA-BSS section */
    lsn->flags &= SF_PORTABLE_MASK;
    lsn->flags |= (sec->flags&SF_SMALLDATA) | target_flags;
  }

  if (lsn->protection != sec->protection) {
    if (lsn->protection!=0 &&
        (lsn->protection & sec->protection)!=sec->protection &&
        !listempty(&lsn->sections)) {
      /* merge protection-flags of the two sections */
      char prot1[5],prot2[5];
      strncpy(prot1,protstring(lsn->protection),5);
      strncpy(prot2,protstring(lsn->protection|sec->protection),5);
      strcpy(namebuf2,getobjname(((struct Section *)lsn->sections.last)->obj));
      error(22,lsn->name,prot1,namebuf2,prot2,getobjname(sec->obj));
    }
    lsn->protection |= sec->protection;
  }

  /* merge memory attributes */
  if (lsn->memattr != sec->memattr) {
    Dprintf("Memory attributes of section %s merged from %08lx to %08lx"
            " in %s.\n",lsn->name,lsn->memattr,lsn->memattr|sec->memattr,
            getobjname(sec->obj));
    lsn->memattr |= sec->memattr;
  }

  if (sec->alignment > lsn->alignment) {
    /* increase alignment to fit the needs of the new section */
    if (lsn->alignment && !listempty(&lsn->sections)) {
      strcpy(namebuf2,getobjname(((struct Section *)lsn->sections.last)->obj));
      Dprintf("Alignment of section %s was changed from "
              "%d in %s to %d in %s.\n",
              lsn->name,1<<lsn->alignment,namebuf2,
              1<<sec->alignment,getobjname(sec->obj));
    }
    lsn->alignment = sec->alignment;
  }
}


static struct LinkedSection *get_matching_lnksec(struct GlobalVars *gv,
                                                 struct Section *sec,
                                                 struct LinkedSection *myls)
/* find a LinkedSection node which matches the attributes of the
   specified section, but which is different from 'myls' */
{
  struct LinkedSection *lsn = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextlsn;
  uint8_t f;
  int tl;

  while (nextlsn = (struct LinkedSection *)lsn->n.next) {
    if (lsn != myls && ((f = cmpsecflags(gv,lsn,sec)) != 0xff)) {
      f &= ~SF_PORTABLE_MASK;

      if (!gv->dest_object) {
        /* target-specific linking */
        if ((tl = fff[gv->dest_format]->targetlink(gv,lsn,sec)) > 0) {
          /* target demands merge of sections */
          Dprintf("targetlink: %s(%s) -> %s\n",getobjname(sec->obj),
                  sec->name,lsn->name);
          merge_sec_attrs(lsn,sec,f);
          return (lsn);
        }
      }
      else
        tl = 0;

      if (tl == 0) {  /* target wants to use the default rules */

        if (!gv->dest_object) {
          /* for final executable only: */

          if (gv->small_code) {
            if (lsn->type==ST_CODE && sec->type==ST_CODE) {
              /* merge all code sections */
              Dprintf("smallcode: %s(%s) -> %s\n",getobjname(sec->obj),
                      sec->name,lsn->name);
              merge_sec_attrs(lsn,sec,f);
              return (lsn);
            }
          }

          if (gv->small_data) {
            if ((lsn->type==ST_DATA || lsn->type==ST_UDATA) &&
                (sec->type==ST_DATA || sec->type==ST_UDATA)) {
              /* merge all data and bss sections */
              Dprintf("smalldata: %s(%s) -> %s\n",getobjname(sec->obj),
                      sec->name,lsn->name);
              merge_sec_attrs(lsn,sec,f);
              return (lsn);
            }
          }

          if (gv->auto_merge && checkrelrefs(lsn,sec)) {
            /* we must link them together, because there are rel. refs */
            if ((lsn->type==ST_CODE || sec->type==ST_CODE) &&
                lsn->type != sec->type)
              /* forces a maybe unwanted combination of code and data */
              error(58,sec_names[lsn->type],lsn->name,sec_names[sec->type],
                    sec->name,getobjname(sec->obj));
            Dprintf("relrefs: %s(%s) -> %s\n",getobjname(sec->obj),
                    sec->name,lsn->name);
            merge_sec_attrs(lsn,sec,f);
            return (lsn);
          }

          if (!gv->multibase && (lsn->flags & sec->flags & SF_SMALLDATA)) {
            Dprintf("sd-refs: %s(%s) -> %s\n",getobjname(sec->obj),
                    sec->name,lsn->name);
            merge_sec_attrs(lsn,sec,f);
            return (lsn);
          }
        }  /* final executable only */

        /* standard check, if sections could be merged */
        if (myls == NULL) {
          if (!strcmp(sec->name,lsn->name) || /* same name or no name */
              *(sec->name)==0) {
            if (lsn->type == sec->type) {   /* same type */
              Dprintf("name: %s(%s) -> %s\n",getobjname(sec->obj),
                      sec->name,lsn->name);
              merge_sec_attrs(lsn,sec,f);
              return (lsn);
            }
            else if (*(sec->name)==0 && sec->size==0) {
              /* no name and no contents - may contain abs symbols only */
              return (lsn);
            }
          }

          if (!gv->dest_object) {
            /* COMMON sections are merged with any BSS-type section */
            if (!strcmp(sec->name,gv->common_sec_name) ||
                !strcmp(sec->name,gv->scommon_sec_name)) {
              if (lsn->type==ST_UDATA && (lsn->flags & SF_UNINITIALIZED)) {
                Dprintf("common: %s(%s) -> %s\n",getobjname(sec->obj),
                        sec->name,lsn->name);
                merge_sec_attrs(lsn,sec,f);
                return (lsn);
              }
            }
          }
        }

      } /* default rules */
    }
    lsn = nextlsn;
  }
  return (NULL);
}


static struct Section *last_initialized(struct LinkedSection *ls)
/* search for bss-sections in reverse order, beginning at the end of
   the section-list, and return a pointer to the first initialized one,
   or NULL when all sections were uninitialized */
{
  struct Section *s;

  for (s=(struct Section *)ls->sections.last; s->n.pred!=NULL;
       s=(struct Section *)s->n.pred) {
    if (!(s->flags & SF_UNINITIALIZED))
      return (s);
  }
  return (NULL);
}


static unsigned long allocate_common(struct GlobalVars *gv,
                                     struct Section *sec,unsigned long addr)
/* allocate all common symbols to section 'sec' at 'addr',
   returns number of total bytes allocated */
{
  unsigned long abytes,alloc=0;
  struct Symbol *sym;
  int i;

  for (i=0; i<SYMHTABSIZE; i++) {
    for (sym=gv->symbols[i]; sym; sym=sym->glob_chain) {
      /* common symbol from this section name? */
      if (sym->relsect==sec && sym->type==SYM_COMMON) {

        /* allocate and transform into SYM_RELOC */
        abytes = comalign(addr+alloc,sym->value);
        sym->value = (lword)((addr+alloc) - sec->va) + abytes;
        sym->type = SYM_RELOC;
        alloc += abytes + sym->size;

        if (gv->map_file)
          fprintf(gv->map_file,"Allocating common %s: %x at %llx hex\n",
                  sym->name,(int)sym->size,(lword)sec->va+sym->value);
      }
    }
  }

  sec->size += alloc;
  return alloc;
}


void print_symbol(FILE *f,struct Symbol *sym)
/* print symbol name, type, value, etc. */
{
  if (sym->type == SYM_COMMON)
    fprintf(f,"  %s: %s%s%s, alignment %d, size %d\n",sym->name,
            sym_bind[sym->bind],sym_type[sym->type],sym_info[sym->info],
            (int)sym->value,(int)sym->size);
  else if (sym->type == SYM_INDIR)
    fprintf(f,"  %s: %s%s%s, referencing %s\n",sym->name,
            sym_bind[sym->bind],sym_type[sym->type],sym_info[sym->info],
            sym->indir_name);
  else
#if 0
    fprintf(f,"  %s: %s%s%s, value 0x%llx, size %d\n",sym->name,
            sym_bind[sym->bind],sym_type[sym->type],sym_info[sym->info],
            (uint64_t)sym->value,(int)sym->size);
#else
    fprintf(f,"  %s: %s%s%s, value 0x%x, size %d\n",sym->name,
            sym_bind[sym->bind],sym_type[sym->type],sym_info[sym->info],
            (uint32_t)sym->value,(int)sym->size);
#endif
}


bool trace_sym_access(struct GlobalVars *gv,const char *name)
/* check if the symbol with this name should be traced */
{
  struct SymNames *sn;

  if (gv->trace_syms) {
    sn = gv->trace_syms[elf_hash(name)%TRSYMHTABSIZE];
    while (sn) {
      if (!strcmp(name,sn->name))
        return (TRUE);  /* symbol found! */
      sn = sn->next;
    }
  }
  return (FALSE);
}


static void add_undef_syms(struct GlobalVars *gv)
/* create dummy xreferences for symbols marked as undefined
   (-u option or EXTERN script directive) */
{
  struct SymNames *sn;

  if (sn = gv->undef_syms) {
    static uint8_t dat[sizeof(uint32_t)];  /* contents of dummy section */
    struct ObjectUnit *obj;
    struct Section *sec = NULL;
    struct Section *dummysec;
    struct Reloc *r;

    /* search first section in an object from the command line */
    for (obj=(struct ObjectUnit *)gv->selobjects.first;
         obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
      if (!listempty(&obj->sections)) {
        sec = (struct Section *)obj->sections.first;
        break;
      }
    }
    if (sec == NULL)
      ierror("add_undef_syms(): no objects or no sections on command line");

    /* make artificial object for external references */
    obj = art_objunit(gv,"UNDEFSYMBOLS",dat,sizeof(uint32_t));
    obj->flags |= OUF_LINKED;
    dummysec = create_section(obj,sec->name,dat,sizeof(uint32_t));
    dummysec->type = sec->type;
    dummysec->protection = sec->protection;
    dummysec->flags = sec->flags;
    addtail(&obj->sections,&dummysec->n);
    addtail(&gv->selobjects,&obj->n);

    do {
      /* add a dummy xreference of type R_NONE to the dummy section */
      r = newreloc(gv,dummysec,sn->name,NULL,0,0,R_NONE,0);
      addreloc(dummysec,r,0,32,-1);
    }
    while (sn = sn->next);
  }
}


static void make_dynobj(struct GlobalVars *gv)
{
  if (gv->dynobj == NULL) {
    gv->dynobj = art_objunit(gv,"DYNAMIC",NULL,0);
    gv->dynobj->flags |= OUF_LINKED;
    addhead(&gv->selobjects,&gv->dynobj->n);
  }
}


static struct Symbol *dyn_entry(struct GlobalVars *gv,DynArg arg,int entrytype)
{
  make_dynobj(gv);

  if (fff[gv->dest_format]->dynentry)
    return fff[gv->dest_format]->dynentry(gv,arg,entrytype);
  
  /* dynamic symbol reference not supported by target */
  error(126,fff[gv->dest_format]->tname);
  return NULL;
}


static struct Symbol *dyn_ext_entry(struct GlobalVars *gv,
                                    struct Symbol *xdef,struct Reloc *xref,
                                    int entrytype)
/* make a dyn_entry for an external reference */
{
  if (xdef->relsect->obj->lnkfile->type!=ID_SHAREDOBJ
      && entrytype==PLT_ENTRY) {
    /* resolve PLT relocation to a local function directly */
    switch (xref->rtype) {
      case R_PLT:
        xref->rtype = R_ABS;
        break;
      case R_PLTPC:
        xref->rtype = R_PC;
        break;
    }
  }
  else {
    DynArg a;
    struct Symbol *sym;

    a.sym = xdef;
    sym = dyn_entry(gv,a,entrytype);
    if (sym)
      return sym;
  }
  return xdef;
}


static void dyn_reloc_entry(struct GlobalVars *gv,struct Reloc *reloc,
                            int entrytype)
/* make a dyn_entry for a local GOT/PLT reference, fix reloc for entry */
{
  if (reloc->relocsect.ptr->obj->lnkfile->type!=ID_SHAREDOBJ
      && entrytype==PLT_LOCAL) {
    /* resolve PLT relocation to a local function directly */
    switch (reloc->rtype) {
      case R_PLT:
        reloc->rtype = R_ABS;
        break;
      case R_PLTPC:
        reloc->rtype = R_PC;
        break;
    }
  }
  else {
    DynArg a;
    struct Symbol *xdef;

    a.rel = reloc;
    if (xdef = dyn_entry(gv,a,entrytype)) {
      reloc->relocsect.ptr = xdef->relsect;
      reloc->addend = xdef->value;
    }
    else
      ierror("dyn_reloc_entry(): new xdef is NULL");
  }
}


static void dyn_so_needed(struct GlobalVars *gv,struct ObjectUnit *ou)
{
  DynArg a;

  a.name = ou->objname;
  dyn_entry(gv,a,SO_NEEDED);
}


static void dyn_export(struct GlobalVars *gv,struct Symbol *sym)
{
  DynArg a;

  if (!(sym->flags & SYMF_DYNLINK)) {
    sym->flags |= SYMF_DYNEXPORT;
    a.sym = sym;
    dyn_entry(gv,a,SYM_ENTRY);
  }
}


static void init_dynlink(struct GlobalVars *gv)
{
  make_dynobj(gv);

  /* target-specific init */
  if (fff[gv->dest_format]->dyninit)
    fff[gv->dest_format]->dyninit(gv);
}


void linker_init(struct GlobalVars *gv)
{
  initlist(&gv->linkfiles);
  initlist(&gv->selobjects);
  initlist(&gv->libobjects);
  initlist(&gv->sharedobjects);
  gv->symbols = alloc_hashtable(SYMHTABSIZE);
  initlist(&gv->pripointers);
  initlist(&gv->scriptsymbols);
  gv->got_base_name = gotbase_name;
  gv->plt_base_name = pltbase_name;

  if (gv->reloctab_format != RTAB_UNDEF) {
    if (!(fff[gv->dest_format]->rtab_mask & gv->reloctab_format)) {
      error(122,fff[gv->dest_format]->tname);
      gv->reloctab_format = fff[gv->dest_format]->rtab_format;
    }
  }
  else
    gv->reloctab_format = fff[gv->dest_format]->rtab_format;
}


void linker_load(struct GlobalVars *gv)
/* load all objects and libraries into memory, identify their */
/* format, then read all symbols and convert into internal format */
{
  struct InputFile *ifn;
  struct LinkFile *lf;
  uint8_t *objptr;
  const char *objname;
  unsigned long objlen;
  int i,ff;

  init_ld_script(gv);       /* pre-parse linker script, when available */
  if (listempty(&gv->inputlist))
    error(6);  /* no input files */

  if (gv->use_ldscript) {
    gv->common_sec_name = "COMMON";
    gv->scommon_sec_name = ".scommon";
  }
  else {
    gv->common_sec_name = fff[gv->dest_format]->bssname ?
                          fff[gv->dest_format]->bssname : "COMMON";
    gv->scommon_sec_name = fff[gv->dest_format]->sbssname ?
                           fff[gv->dest_format]->sbssname : ".scommon";
  }

  if (gv->trace_file)
    fprintf(gv->trace_file,"\nLoading files:\n\n");

  for (ifn=(struct InputFile *)gv->inputlist.first;
       ifn->n.next!=NULL; ifn=(struct InputFile *)ifn->n.next) {
    if (ifn->lib) {
      if (!(objptr = (uint8_t *)maplibrary(gv,ifn))) {
        snprintf(namebuf,FNAMEBUFSIZE,"-l%s",ifn->name);
        error(8,namebuf);  /* cannot open -lxxx */
      }
    }
    else {
      if (objptr = (uint8_t *)mapfile(ifn->name))
        strcpy(namebuf,ifn->name);
      else
        error(8,ifn->name);  /* cannot open xxx */
    }
    objlen = *(size_t *)(objptr - sizeof(size_t));
    objname = base_name(namebuf);

    /* determine the object's file format */
    for (i=0,ff=ID_UNKNOWN; fff[i]; i++) {
      if ((ff = (fff[i]->identify)((char *)objname,objptr,objlen,ifn->lib))
          != ID_UNKNOWN)
        break;
    }
    if (ff == ID_UNKNOWN)
      error(11,objname);  /* File format not recognized */

    if (ff != ID_IGNORE) {
      /* use endianess of first object read */
      if (gv->endianess < 0)
        gv->endianess = fff[i]->endianess;
      else if (fff[i]->endianess>=0 && gv->endianess!=fff[i]->endianess)
        error(61,objname);  /* endianess differs from previous objects */

      /* create new link file node */
      lf = (struct LinkFile *)alloc(sizeof(struct LinkFile));
      lf->pathname = allocstring(namebuf);
      lf->filename = base_name(lf->pathname);
      lf->data = objptr;
      lf->length = objlen;
      lf->format = (uint8_t)i;
      lf->type = (uint8_t)ff;
      lf->flags = ifn->flags;
      if (gv->trace_file)
        fprintf(gv->trace_file,"%s (%s %s)\n",namebuf,fff[i]->tname,
                                              filetypes[ff]);

      /* read the file and convert into internal format */
      fff[i]->readconv(gv,lf);
      addtail(&gv->linkfiles,&lf->n);
    }
  }

  if (gv->endianess < 0) {
    /* When endianess is still unknown, after reading all input files,
       we take the it from the destination format. */
    gv->endianess = fff[gv->dest_format]->endianess;

    /* The destination format didn't define the endianess either?
       Then guess by using the host endianess. */
    if (gv->endianess < 0)
      gv->endianess = host_endianess();
  }

  collect_constructors(gv); /* scan for con-/destructor functions */
  add_undef_syms(gv);       /* put syms. marked as undef. into 1st sec. */
}


void linker_resolve(struct GlobalVars *gv)
/* Resolve all symbol references and pull the required objects into */
/* the gv->selobjects list. */
{
  bool constructors_made = FALSE;
  bool pseudo_dynlink = (fff[gv->dest_format]->flags&FFF_PSEUDO_DYNLINK)!=0;
  struct ObjectUnit *obj = (struct ObjectUnit *)gv->selobjects.first;
  static const char *pulltxt = " needed due to ";

  if (gv->dest_sharedobj || gv->dyn_exp_all) {
    gv->dynamic = TRUE;
    init_dynlink(gv);
  }
  else
    gv->dynamic = FALSE;  /* set to true, when first shared object found */

  if (gv->trace_file)
    fprintf(gv->trace_file,"\nDigesting symbol information:\n\n");

  if (obj->n.next == NULL)
    return;  /* no objects in list */

  do {
    struct Section *sec;
    struct Reloc *xref;
    struct Symbol *xdef;
    struct ObjectUnit *pull_unit;

    /* all sections of this object are checked for external references */
    for (sec=(struct Section *)obj->sections.first;
         sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {

      for (xref=(struct Reloc *)sec->xrefs.first;
           xref->n.next!=NULL; xref=(struct Reloc *)xref->n.next) {

        if (xref->rtype == R_LOADREL) {
          /* addend offsets to load address, nothing to resolve */
          continue;
        }

        /* find a global symbol with this name in any object or library */
        xdef = findsymbol(gv,sec,xref->xrefname);

        if (xdef!=NULL && xref->rtype==R_LOCALPC) {
          /* R_LOCALPC only accepts symbols which are defined in the
             same ObjectUnit as the reference. */
          if (xdef->relsect->obj != obj)
            xdef = NULL;  /* discard symbol from other object */
        }

        if (xdef == NULL) {
          /* check if reference can be resolved by a linker symbol */
          if (!(xdef = lnksymbol(gv,sec,xref))) {

            /* ref. to undefined symbol is only an error for executables */
            if (!gv->dest_object && !gv->dest_sharedobj) {
              if (xref->flags & RELF_WEAK) {
                /* weak references default to 0 */
                xdef = addlnksymbol(gv,xref->xrefname,0,SYM_RELOC,0,
                                    SYMI_NOTYPE,SYMB_LOCAL,0);
                xdef->relsect = dummy_section(gv,obj);
              }
              else {
                print_function_name(sec,xref->offset);
                error(21,getobjname(sec->obj),sec->name,xref->offset,
                      xref->xrefname);
                continue;
              }
            }
            else
              continue;
          }
        }
        /* reference has been resolved after this point */
        if (trace_sym_access(gv,xref->xrefname))
          fprintf(stderr,"Symbol %s referenced from %s\n",
                  xref->xrefname,getobjname(sec->obj));

        /* turn LOCALPC into a PC reloc, once resolved by a local symbol */
        if (xref->rtype == R_LOCALPC)
          xref->rtype = R_PC;

        /* link with symbol's unit */
        if (xdef->relsect && xdef->relsect->type != ST_TMP) {
          pull_unit = xdef->relsect->obj;

          switch (pull_unit->lnkfile->type) {

            case ID_ARTIFICIAL:
              /* linker-generated object - insert it behind the curr. obj. */
              if (!(pull_unit->flags & OUF_LINKED)) {
                if (gv->map_file) {
                  fprintf(gv->map_file,
                          "artificial object (%s) created due to %s\n",
                          pull_unit->objname,xref->xrefname);
                  /* "artificial object (name.o) created due to @__name" */
                }
                insertbehind(&obj->n,&pull_unit->n);
                pull_unit->flags |= OUF_LINKED;
              }
              /* turn into a normal object */
              pull_unit->lnkfile->type = ID_OBJECT;
              xref->relocsect.symbol = xdef;  /* xref was resolved */
              break;

            case ID_SHAREDOBJ:
              if (!(pull_unit->flags & OUF_LINKED)) {
                if (gv->map_file) {
                  fprintf(gv->map_file,"%s%s%s\n",
                          pull_unit->lnkfile->pathname,pulltxt,xref->xrefname);
                  /* Example: "/usr/lib/libc.so.12.0 needed due to _atexit" */
                }
                insertbehind(&obj->n,remnode(&pull_unit->n));
                add_priptrs(gv,pull_unit);
                pull_unit->flags |= OUF_LINKED;
                reenter_global_objsyms(gv,pull_unit);
                if (!pseudo_dynlink) {
                  if (!gv->dynamic) {
                    gv->dynamic = TRUE;  /* we're doing dynamic linking! */
                    init_dynlink(gv);
                  }
                  /* declare the shared object as "needed" */
                  dyn_so_needed(gv,pull_unit);
                }
              }

              if (!gv->dest_object && !pseudo_dynlink) {
                /* ref. to a shared object's symbol needs special treatment */
                switch (xref->rtype) {
                  case R_ABS:
                  case R_PC:
                    if (xdef->info == SYMI_FUNC) {
                      /* abs. or rel. function calls create a PLT entry */
                      xdef = dyn_ext_entry(gv,xdef,xref,PLT_ENTRY);
                    }
                    else {
                      /* alloc bss space and R_COPY from shared object */
                      xdef = dyn_ext_entry(gv,xdef,xref,BSS_ENTRY);
                    }
                    break;
                  case R_GOT:
                  case R_GOTPC:
                  case R_GOTOFF:
                  case R_PLT:
                  case R_PLTPC:
                  case R_PLTOFF:
                  case R_GLOBDAT:
                  case R_JMPSLOT:
                  case R_COPY:
                    /* types are already correct for referencing a shared obj. */
                    break;
                  default:
                    ierror("linker_resolve(): Unsupported reloc %s referencing "
                           "shared object symbol %s",
                           reloc_name[xref->rtype],xref->xrefname);
                    break;
                }
                xref->relocsect.symbol = xdef;  /* xref was resolved */
              }
              break;

            case ID_LIBARCH:
              if (!(pull_unit->flags & OUF_LINKED)) {
                if (gv->map_file) {
                  fprintf(gv->map_file,"%s (%s)%s%s\n",
                          pull_unit->lnkfile->pathname,pull_unit->objname,
                          pulltxt,xref->xrefname);
                  /* "/usr/lib/libc.a (atexit.o) needed due to _atexit" */
                }
                insertbehind(&obj->n,remnode(&pull_unit->n));
                add_priptrs(gv,pull_unit);
                pull_unit->flags |= OUF_LINKED;
                reenter_global_objsyms(gv,pull_unit);
              }
              /* fall through */

            default:
              xref->relocsect.symbol = xdef;  /* xref was resolved */
              break;
          }

          /* Handle explicit GOT and PLT references */
          if (!gv->dest_object) {
            switch (xref->rtype) {
              case R_GOT:
              case R_GOTPC:
              case R_GOTOFF:
                xref->relocsect.symbol = dyn_ext_entry(gv,xdef,xref,GOT_ENTRY);
                break;
              case R_PLT:
              case R_PLTPC:
              case R_PLTOFF:
                xref->relocsect.symbol = dyn_ext_entry(gv,xdef,xref,PLT_ENTRY);
                break;
            }
          }

          /* is it a reference from a shared object to one of our symbols? */
          if (obj->lnkfile->type==ID_SHAREDOBJ
              && pull_unit->lnkfile->type!=ID_SHAREDOBJ)
            dyn_export(gv,xdef);  /* then we have to export it */
        }
        else
          xref->relocsect.symbol = xdef;

        xdef->flags |= SYMF_REFERENCED;
      }
    }

    if (obj->n.next->next == NULL && !constructors_made) {
      make_constructors(gv);  /* Con-/Destructor object always at last */
      constructors_made = TRUE;
    }
    obj = (struct ObjectUnit *)obj->n.next;
  }
  while (obj->n.next);
}


void linker_relrefs(struct GlobalVars *gv)
/* All relocations and unresolved xrefs with a relative reference
   to other sections are collected. A second task is to detect
   and handle base-relative and GOT/PLT references. */
{
  struct ObjectUnit *obj;
  struct Section *sec;
  struct Symbol *sdabase = NULL;
  struct Symbol *sda2base = NULL;
  struct Symbol *r13init = NULL;

  for (obj=(struct ObjectUnit *)gv->selobjects.first;
       obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {

    for (sec=(struct Section *)obj->sections.first;
         sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
      struct RelRef **rr = &sec->relrefs;
      struct Symbol *xdef;
      struct Reloc *xref,*reloc;

      for (*rr=NULL,xref=(struct Reloc *)sec->xrefs.first;
           xref->n.next!=NULL; xref=(struct Reloc *)xref->n.next) {

        if (xdef = xref->relocsect.symbol) {
          if (xdef->relsect!=NULL &&
              (xdef->type==SYM_RELOC || xdef->type==SYM_COMMON)) {

            if ((xref->rtype==R_SD || xref->rtype==R_SD21 ||
                 xref->rtype==R_MOSDREL) && xdef->type==SYM_COMMON) {
                /* small data common symbol - assign .scommon section */
                xdef->relsect = scommon_section(gv,xdef->relsect->obj);
            }

            if (xref->rtype==R_PC && xdef->relsect!=sec) {
              /* relative reference to different section */
              addrelref(rr,xdef->relsect);
            }

            else if (xref->rtype==R_SD || xref->rtype==R_MOSDREL) {
              /* other section is accessed base relative from this one */
              xdef->relsect->flags |= SF_SMALLDATA;
              if (!gv->textbaserel && xdef->relsect->type==ST_CODE)
                error(121,getobjname(sec->obj),sec->name,xref->offset);
            }
          }
        }
      }

      for (reloc=(struct Reloc *)sec->relocs.first;
           reloc->n.next!=NULL; reloc=(struct Reloc *)reloc->n.next) {

        if (reloc->rtype==R_PC && reloc->relocsect.ptr!=sec) {
          /* relative reference to different section */
          addrelref(rr,reloc->relocsect.ptr);
        }

        else if (reloc->rtype==R_GOT || reloc->rtype==R_GOTPC) {
          /* a local relocation to a GOT entry may create that entry */
          dyn_reloc_entry(gv,reloc,GOT_LOCAL);
        }

        else if (reloc->rtype==R_PLT || reloc->rtype==R_PLTPC) {
          /* a local relocation to a PLT entry may create that entry */
          dyn_reloc_entry(gv,reloc,PLT_LOCAL);
        }

        else if (reloc->rtype == R_SD) {
          /* other section is accessed base relative from this one */
          reloc->relocsect.ptr->flags |= SF_SMALLDATA;
          if (!sdabase) {
            /* R_SD relocation implies a reference to _SDA_BASE_ */
            if (sdabase = find_any_symbol(gv,sec,sdabase_name))
              sdabase->flags |= SYMF_REFERENCED;
          }
          if (!gv->textbaserel && reloc->relocsect.ptr->type==ST_CODE)
            error(121,getobjname(sec->obj),sec->name,reloc->offset);
        }

        else if (reloc->rtype == R_SD2) {
          if (!sda2base) {
            /* R_SD2 relocation implies a reference to _SDA2_BASE_ */
            if (sda2base = find_any_symbol(gv,sec,sda2base_name))
              sda2base->flags |= SYMF_REFERENCED;
          }
        }

        else if (reloc->rtype == R_MOSDREL) {
          /* other section is accessed base relative from this one */
          reloc->relocsect.ptr->flags |= SF_SMALLDATA;
          if (!r13init) {
            /* R_MOSDREL relocation implies a reference to __r13_init */
            if (r13init = find_any_symbol(gv,sec,r13init_name))
              r13init->flags |= SYMF_REFERENCED;
          }
          if (!gv->textbaserel && reloc->relocsect.ptr->type==ST_CODE)
            error(121,getobjname(sec->obj),sec->name,reloc->offset);
        }

      }
    }
  }
}


void linker_dynprep(struct GlobalVars *gv)
/* Preparations for dynamic linking */
{
  /* hide unreferenced symbols from a shared library */
  hide_shlib_symbols(gv);

  /* export all global symbols when creating a shared library */
  if (gv->dest_sharedobj || gv->dyn_exp_all) {
    int i;

    for (i=0; i<SYMHTABSIZE; i++) {
      struct Symbol *sym;
      struct Symbol **chain = &gv->symbols[i];

      while (sym = *chain) {
        if (sym->bind>=SYMB_GLOBAL && !(sym->flags & SYMF_SHLIB) &&
            sym->relsect!=NULL && (sym->relsect->obj->flags & OUF_LINKED))
          dyn_export(gv,sym);
        chain = &sym->glob_chain;
      }
    }
  }

  /* let the target create and populate dynamic sections when needed */
  if (gv->dynamic && fff[gv->dest_format]->dyncreate)
    fff[gv->dest_format]->dyncreate(gv);
}


void linker_join(struct GlobalVars *gv)
/* Join the sections with same name and type, or as defined by a
   linker script. Calculate their virtual address and size. */
{
  struct ObjectUnit *obj;
  struct Section *sec,*nextsec;
  struct LinkedSection *ls;
  uint8_t stype;

  if (gv->trace_file)
    fprintf(gv->trace_file,"Joining selected sections:\n");

  if (gv->use_ldscript) {
    /* Linkage rules are defined by a linker script, which means there */
    /* are predefined LinkedSection structures which can be used. */
    struct LinkedSection *maxls=NULL;
    char *filepattern,**secpatterns;
    unsigned long maxsize = 0;

    init_secdef_parse(gv);
    /* Handle one section definition after the other from the
       linker script's SECTIONS block. The script parser cares
       for commands, symbol-definitions and address-assignments. */

    while (ls = next_secdef(gv)) {
      /* Phase 1: read file/section patterns and determine which alignment
         and flags are required for the sections to merge with us */
      while (test_pattern(gv,&filepattern,&secpatterns)) {
        for (obj=(struct ObjectUnit *)gv->selobjects.first;
             obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {

          if (obj->lnkfile->type != ID_SHAREDOBJ &&
              pattern_match(filepattern,obj->lnkfile->filename)) {
            for (sec=(struct Section *)obj->sections.first;
                 sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
              if (sec->lnksec==NULL
                  && patternlist_match(secpatterns,sec->name)) {
                /* File name and section name are matching the patterns,
                   so try to merge and check alignments */
                uint8_t f;

                if ((f = cmpsecflags(gv,ls,sec)) == 0xff) {
                  /* no warning, because the linker-script should know... */
                  f = ls->flags ? ls->flags : sec->flags;
                }
                merge_sec_attrs(ls,sec,f&~SF_PORTABLE_MASK);
                sec->lnksec = ls;  /* will be reset for phase 2 */
              }
            }
          }
        }
        free_patterns(filepattern,secpatterns);
      }

      /* align this section to the maximum required alignment */
      align_address(ls->relocmem,ls->destmem,ls->alignment);
      ls->base = ls->relocmem->current;
      ls->copybase = ls->destmem->current;

      /* reset lnksec pointers for phase 2 */
      for (obj=(struct ObjectUnit *)gv->selobjects.first;
           obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
        if (obj->lnkfile->type!=ID_SHAREDOBJ && !listempty(&obj->sections)) {
          for (sec=(struct Section *)obj->sections.first;
               sec->n.next!=NULL; sec=(struct Section *)sec->n.next)
            sec->lnksec = NULL;
        }
      }

      /* The linker scripts create an empty dummy section and adds */
      /* it as the first section into the LinkedSection's list. */
      /* Its purpose is to keep all linker script symbols. */
      /* We have to make sure that its lnksec and va is valid. */
      if (!listempty(&ls->sections)) {
        sec = (struct Section *)ls->sections.first;
        sec->filldata = gv->filldata;
        sec->lnksec = ls;
        sec->va = ls->relocmem->current;
      }

      /* Phase 2: read next patterns and merge matching sections for real */
      while (next_pattern(gv,&filepattern,&secpatterns)) {
        /* For each pattern, merge ST_CODE first, then ST_DATA and */
        /* ST_UDATA at last, to keep uninitialized sections together. */
        for (stype=0; stype<=ST_LAST; stype++) {
          for (obj=(struct ObjectUnit *)gv->selobjects.first;
               obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {

            if (obj->lnkfile->type != ID_SHAREDOBJ &&
                pattern_match(filepattern,obj->lnkfile->filename)) {
              sec = (struct Section *)obj->sections.first;
              while (nextsec = (struct Section *)sec->n.next) {
                if (sec->lnksec==NULL
                    && patternlist_match(secpatterns,sec->name)
                    && sec->type==stype) {

                  /* File name and section name are matching the patterns,
                     so join it into the current LinkedSection. */
                  align_address(ls->relocmem,ls->destmem,sec->alignment);
                  sec->filldata = gv->filldata;
                  sec->lnksec = ls;
                  sec->va = ls->relocmem->current;
                  sec->offset = sec->va - ls->base;
                  update_address(ls->relocmem,ls->destmem,sec->size);

                  /* allocate COMMON symbols, if required */
                  if ((!strcmp(sec->name,gv->common_sec_name) ||
                       !strcmp(sec->name,gv->scommon_sec_name)) &&
                      (!gv->dest_object || gv->alloc_common) &&
                      stype==ST_UDATA) {
                    update_address(ls->relocmem,ls->destmem,
                                   allocate_common(gv,sec,
                                                   ls->relocmem->current));
                  }

                  addtail(&ls->sections,remnode(&sec->n));

                  if (!is_ld_script(sec->obj) &&
                      (gv->scriptflags & LDSF_KEEP)) {
                  /* @@@ KEEP for one section will prevent all merged
                     sections from being deleted - ok??? */
                    ls->ld_flags |= LSF_PRESERVE;
                    ls->flags |= SF_ALLOC;  /* @@@ keep implies ALLOC? */
                  }
                }
                sec = nextsec;
              }
            }
          }
        }
        free_patterns(filepattern,secpatterns);

        /* keep section size up to date */
        ls->size = ls->relocmem->current - ls->base;
        if (sec = last_initialized(ls))
          ls->filesize = (sec->va + sec->size) - ls->base;
        else
          ls->filesize = 0;  /* whole contents is uninitialized */

        if (ls->size>maxsize || maxsize==0) {  /* finds largest section */
          maxsize = ls->size;
          maxls = ls;
        }
      }
    }

    /* Check if there are any sections left, which were not recognized */
    /* by the linker script rules */
    for (obj=(struct ObjectUnit *)gv->selobjects.first;
         obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
      if (obj->lnkfile->type!=ID_SHAREDOBJ && !listempty(&obj->sections)) {
        for (sec=(struct Section *)obj->sections.first; sec->n.next!=NULL;
             sec=(struct Section *)sec->n.next) {
          int i;

          if (sec->size==0 && (*(sec->name)==0 || is_ld_script(sec->obj))) {
            /* @@@ move section without name and contents into biggest
               LinkedSection - might be a dummy or linker script section
               with abs symbols */
            sec->filldata = gv->filldata;
            sec->lnksec = maxls;
            sec->va = maxls->relocmem->current;
            sec->offset = sec->va - maxls->base;
            addtail(&maxls->sections,remnode(&sec->n));
          }
          else {
            /* Section was not recognized by target linker script */
            error(64,getobjname(obj),sec->name);

            /* kill unallocated common symbols */
            for (i=0; i<OBJSYMHTABSIZE; i++) {
              struct Symbol *sym;

              for (sym = sec->obj->objsyms[i]; sym; sym=sym->obj_chain) {
                if (sym->relsect==sec && sym->type==SYM_COMMON)
                  sym->type = SYM_ABS; /* to prevent an internal error */
              }
            }
          }
        }
      }
    }
  }


  else {  /* !gv->use_ldscript */
    /* Default linkage rules. Link all code, all data, all bss. */
    unsigned long va = 0;
    bool baseincr = (fff[gv->dest_format]->flags&FFF_BASEINCR) != 0;
    struct LinkedSection *ls,*newls;

    /* join sections, beginning with ST_CODE, then ST_DATA and ST_UDATA */
    for (stype=0; stype<=ST_LAST; stype++) {
      struct list seclist;

      /* collect all sections of current type */
      initlist(&seclist);
      for (obj=(struct ObjectUnit *)gv->selobjects.first;
           obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {

        if (obj->lnkfile->type != ID_SHAREDOBJ) {
          sec = (struct Section *)obj->sections.first;
          while (nextsec = (struct Section *)sec->n.next) {
            if (sec->type == stype)
              addtail(&seclist,remnode(&sec->n));
            sec = nextsec;
          }
        }
      }

      /* Phase 1: link sec. which fit together, obeying target linking rules*/
      do {
        bool create_allowed = TRUE;

        for (sec=(struct Section *)seclist.first;
             sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
          ls = get_matching_lnksec(gv,sec,NULL);
          if (!ls && create_allowed) {
            Dprintf("new: %s(%s) -> %s\n",getobjname(sec->obj),
                    sec->name,sec->name);
            ls = create_lnksect(gv,sec->name,sec->type,sec->flags,
                                sec->protection,sec->alignment,sec->memattr);
            create_allowed = FALSE;
          }
          if (ls)
            addtail(&ls->sections,remnode(&sec->n));
        }
      }
      while (!(listempty(&seclist)));
    }

    /* Phase 2: resolve dependencies between created LinkedSections */
    do {
      newls = NULL;
      for (ls=(struct LinkedSection *)gv->lnksec.first;
           ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
        for (sec=(struct Section *)ls->sections.first;
             sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
          if (newls = get_matching_lnksec(gv,sec,ls)) {
            /* another LinkedSection matches too - merge them! */
            break;
          }
        }
        if (newls) {
          /* merge with matching LinkedSection, dump the newer one */
          struct Section *firstbss;
          uint8_t tgtfl;

          if (newls->index > ls->index) {
            /* ls is older, so keep it instead of newls */
            struct LinkedSection *dumls = newls;
            newls = ls;
            ls = dumls;
          }
          firstbss = find_first_bss_sec(newls);
          tgtfl = ls->flags & ~SF_PORTABLE_MASK;

          while (sec = (struct Section *)remhead(&ls->sections)) {
            merge_sec_attrs(newls,sec,tgtfl);
            if (!(sec->flags & SF_UNINITIALIZED) && firstbss!=NULL)
              insertbefore(&sec->n,&firstbss->n);
            else
              addtail(&newls->sections,&sec->n);
          }
          remnode(&ls->n);
          free(ls);
          break;
        }
      }
    }
    while (newls);

    /* Phase 3: calculate offsets and sizes for final LinkedSections */
    for (ls=(struct LinkedSection *)gv->lnksec.first;
         ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
      ls->base = ls->copybase = va;

      for (sec=(struct Section *)ls->sections.first;
           sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
        unsigned long abytes = align(ls->base+ls->size,sec->alignment);

        sec->lnksec = ls;
        sec->offset = ls->size + abytes;
        sec->va = ls->base + sec->offset;
        ls->size += sec->size + abytes;
        if (baseincr)
          va += sec->size + abytes;
        if (!(sec->flags & SF_UNINITIALIZED))
          ls->filesize += sec->size + abytes;

        /* allocate COMMON symbols, if required */
        if ((!strcmp(sec->name,gv->common_sec_name) ||
             !strcmp(sec->name,gv->scommon_sec_name)) &&
            (!gv->dest_object || gv->alloc_common)) {
          unsigned long n = allocate_common(gv,sec,ls->base+ls->size);

          ls->size += n;
          if (baseincr)
            va += n;
        }
      }
    }
  }
}


void linker_mapfile(struct GlobalVars *gv)
/* print section mapping, when desired */
{
  if (gv->map_file) {
    struct ObjectUnit *obj;
    struct Section *sec;
    struct LinkedSection *ls;

    /* print file names and the new addresses of their sections */
    fprintf(gv->map_file,"\nFiles:\n");

    for (obj=(struct ObjectUnit *)gv->selobjects.first;
         obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
      struct LinkFile *lfile = obj->lnkfile;
      char sep = ' ';

      if (!(obj->flags & OUF_SCRIPT)) {
        if (lfile->type == ID_LIBARCH)
          fprintf(gv->map_file,"  %s (%s):",lfile->pathname,obj->objname);
        else
          fprintf(gv->map_file,"  %s:",obj->objname);

        if (lfile->type != ID_SHAREDOBJ) {
          for (ls=(struct LinkedSection *)gv->lnksec.first;
               ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
            for (sec=(struct Section *)ls->sections.first;
                 sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
              if (sec->obj == obj) {  /* section came from this object? */
                if (strcmp(sec->name,gv->common_sec_name) &&
                    strcmp(sec->name,gv->scommon_sec_name)) {
                  fprintf(gv->map_file,"%c %s %lx(%lx)",sep,sec->name,
                          sec->va,sec->size);
                  sep = ',';
                }
              }
            }
          }
        }

        if (sep == ',')  /* any sections listed? */
          fprintf(gv->map_file," hex\n");
        else
          fprintf(gv->map_file,"  symbols only\n"); /* empty or shared obj. */
      }
    }

    /* print section mappings */
    fprintf(gv->map_file,"\n\nSection mapping (numbers in hex):\n");

    for (ls=(struct LinkedSection *)gv->lnksec.first;
         ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
      if (!(ls->size==0 && listempty(&ls->relocs) &&
            listempty(&ls->symbols) && !(ls->ld_flags & LSF_PRESERVE))) {
        fprintf(gv->map_file,"------------------------------\n"
                "  %08lx %s  (size %lx",ls->copybase,ls->name,ls->size);
        if (ls->filesize < ls->size)
          fprintf(gv->map_file,", allocated %lx",ls->filesize);
        fprintf(gv->map_file,")\n");
  
        for (sec=(struct Section *)ls->sections.first;
             sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
          if (sec->obj!=NULL && !is_ld_script(sec->obj)) {
            fprintf(gv->map_file,"           %08lx - %08lx %s(%s)\n",
                    sec->va,sec->va+sec->size,sec->obj->objname,sec->name);
          }
        }
      }
    }
  }
}


void linker_copy(struct GlobalVars *gv)
/* Merge contents of linked sections, fix symbol offsets and
   allocate common symbol data. */
{
  struct LinkedSection *ls,*maxls=NULL;
  struct Section *sec;
  unsigned long maxsize = 0;
  struct Symbol *sym;
  struct ObjectUnit *obj;

  if (gv->trace_file)
    fprintf(gv->trace_file,"\n");
  if (gv->map_file)
    fprintf(gv->map_file,"\n");

  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
    bool print_symbols_of_header = TRUE;
    unsigned long lastsecend = 0;  /* for filling gaps */

    if (gv->trace_file) {
      if (!listempty(&ls->sections) && ls->size>0)
        fprintf(gv->trace_file,"Copying %s:\n",ls->name);
    }
    if (ls->size>maxsize || maxsize==0) {  /* finds largest section */
      maxsize = ls->size;
      maxls = ls;
    }
    /* allocate memory for section, even for uninitialized ones */
    ls->data = alloczero(ls->size);

    for (sec=(struct Section *)ls->sections.first;
         sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
      int i;

      if (ls->data && sec->data) {
        /* copy section contents, fill gaps */
        memset16(gv,ls->data + lastsecend,sec->filldata,
                 sec->offset - lastsecend);
        memcpy(ls->data+sec->offset,sec->data,sec->size);
        lastsecend = sec->offset + sec->size;
      }

      if (sec->obj) {
        /* find section symbols and fix their offsets */
        for (i=0; i<OBJSYMHTABSIZE; i++) {
          for (sym=sec->obj->objsyms[i]; sym; sym=sym->obj_chain) {
            if (sym->relsect == sec) {
#if 0
              if (sym->type==SYM_COMMON &&
                  (!gv->dest_object || gv->alloc_common)) {
                /* delete remaining copies of common symbols */
                remove_obj_symbol(sym);
              }
#endif
              if (!((sym->flags & (SYMF_REFERENCED|SYMF_PROVIDED))
                    == SYMF_PROVIDED)) { /* ignore unrefd. provided sym. */
                if (sym->type == SYM_RELOC)
                  sym->value += sec->va;  /* was sec->offset */
                addtail(&ls->symbols,&sym->n);

                if (gv->map_file) {
                  if (print_symbols_of_header)
                    fprintf(gv->map_file,"\nSymbols of %s:\n",ls->name);
                  print_symbol(gv->map_file,sym);
                  print_symbols_of_header = FALSE;
                }
              }
            }
          }
        }
      }
    }
  }

  if (gv->use_ldscript && maxls!=NULL) {
    /* put remaining absolute linker script symbols into the
       symbol list of the largest defined section: */
    if (gv->map_file)
      fprintf(gv->map_file,"\nLinker symbols:\n");
    while (sym = (struct Symbol *)remhead(&gv->scriptsymbols)) {
      if (!((sym->flags & (SYMF_REFERENCED|SYMF_PROVIDED))
            == SYMF_PROVIDED)) {
        sym->relsect = (struct Section *)maxls->sections.first;
        addtail(&maxls->symbols,&sym->n);
        if (gv->map_file)
          print_symbol(gv->map_file,sym);
      }
    }
  }

  /* last chance to fix linker symbols */
  fixlnksymbols(gv,maxls);

  /* fix offsets of relocatable debugging symbols */
  for (obj=(struct ObjectUnit *)gv->selobjects.first;
       obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
    fixstabs(obj);
  }
}


void linker_relocate(struct GlobalVars *gv)
/* Fix relocations, resolve x-references and create more relocations, */
/* if required. */
{
  const char *fn = "linker_relocate(): ";
  struct Symbol *sdabase,*sda2base,*gotbase,*pltbase,*r13init;
  struct LinkedSection *ls;
  struct Section *sec;

  /* get symbols needed for reloc calculation */
  sdabase = find_any_symbol(gv,NULL,sdabase_name);
  sda2base = find_any_symbol(gv,NULL,sda2base_name);
  gotbase = find_any_symbol(gv,NULL,gv->got_base_name);
  pltbase = find_any_symbol(gv,NULL,gv->plt_base_name);
  r13init = find_any_symbol(gv,NULL,r13init_name);

  for (ls=(struct LinkedSection *)gv->lnksec.first;
       ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {

    /* dyn.relocs appear in uninitialized sections as well, so...*/
    if (/*!(ls->flags&SF_UNINITIALIZED) &&*/ ls->size>0) {
      if (gv->trace_file)
        fprintf(gv->trace_file,"Relocating %s:\n",ls->name);

      for (sec=(struct Section *)ls->sections.first;
           sec->n.next!=NULL; sec=(struct Section *)sec->n.next) {
        struct Reloc *rel,*xref;

        /*--------------------------*/
        /* copy and fix relocations */
        /*--------------------------*/
        while (rel = (struct Reloc *)remhead(&sec->relocs)) {
          bool keep = TRUE;
          lword a = 0;

          rel->offset += sec->offset;
          rel->addend += rel->relocsect.ptr->offset;
          rel->relocsect.lnk = rel->relocsect.ptr->lnksec;

          switch (rel->rtype) {

            case R_PLTPC:
            case R_GOTPC:
              if (gv->dest_object)
                break;
              rel->rtype = R_PC;
              /* fall through */

            case R_PC:          /* Normal, PC-relative reference */
            case R_LOCALPC:
              /* resolve relative relocs from the same section */
              if (rel->relocsect.lnk == ls) {
                a = ((lword)rel->relocsect.lnk->base + rel->addend) -
                    ((lword)ls->base + rel->offset);
                a = writesection(gv,ls->data+rel->offset,rel,a);
                keep = FALSE;
              }
              break;

            case R_SECOFF:      /* symbol's section-offset */
              if (!gv->dest_object) {
                a = rel->addend;
                a = writesection(gv,ls->data+rel->offset,rel,a);
                keep = FALSE;
              }
              break;

            case R_GOT:         /* GOT offset */
            case R_GOTOFF:
              if (!gv->dest_object) {
                if (gotbase) {
                  a = (lword)rel->relocsect.lnk->base +
                      rel->addend - gotbase->value;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else
                  undef_sym_error(sec,rel,gv->got_base_name);
              }
              break;

            case R_SD:          /* _SDA_BASE_ relative reference */
              if (!gv->dest_object) {
                /* resolve base-relative relocation for executable file */
                if (sdabase) {
                  a = (lword)rel->relocsect.lnk->base +
                      rel->addend - sdabase->value;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else
                  undef_sym_error(sec,rel,sdabase_name);
              }
              break;
              
            case R_SD2:       /* _SDA2_BASE_ relative reference */
              if (!gv->dest_object) {
                /* resolve base-relative relocation for executable file */
                if (sda2base) {
                  a = (lword)rel->relocsect.lnk->base +
                      rel->addend - sda2base->value;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else
                  undef_sym_error(sec,rel,sda2base_name);
              }
              break;

            case R_SD21:        /* PPC-EABI base rel. reference */
              if (!gv->dest_object) {
                /* resolve base-relative relocation for executable file */
                const char *secname = rel->relocsect.lnk->name;

                *(ls->data+rel->offset+1) &= 0xe0;
                if (!strcmp(secname,sdata_name) ||
                    !strcmp(secname,sbss_name)) {
                  if (sdabase) {
                    a = (lword)rel->relocsect.lnk->base +
                               rel->addend - sdabase->value;
                    *(ls->data+rel->offset+1) |= 13;
                    a = writesection(gv,ls->data+rel->offset,rel,a);
                    keep = FALSE;
                  }
                  else
                    undef_sym_error(sec,rel,sdabase_name);
                }
                else if (!strcmp(secname,sdata2_name) ||
                         !strcmp(secname,sbss2_name)) {
                  if (sda2base) {
                    a = (lword)rel->relocsect.lnk->base +
                               rel->addend - sda2base->value;
                    *(ls->data+rel->offset+1) |= 2;
                    a = writesection(gv,ls->data+rel->offset,rel,a);
                    keep = FALSE;
                  }
                  else
                    undef_sym_error(sec,rel,sda2base_name);
                }
                else if (!strcmp(secname,".PPC.EMB.sdata0") ||
                         !strcmp(secname,".PPC.EMB.sbss0")) {
                  a = (lword)rel->relocsect.lnk->base + rel->addend;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else {
                  print_function_name(sec,rel->offset);
                  error(117,getobjname(sec->obj),sec->name,
                        rel->offset-sec->offset,reloc_name[rel->rtype],
                        secname,secname);
                }
              }
              break;

            case R_MOSDREL:     /* __r13_init rel. reference */
              if (!gv->dest_object) {
                /* resolve base-relative relocation for executable file */
                if (r13init) {
                  a = (lword)rel->relocsect.lnk->base +
                      rel->addend - r13init->value;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else
                  undef_sym_error(sec,rel,r13init_name);
              }
              break;

            case R_AOSBREL:     /* .data rel. reference */
              if (!gv->dest_object) {
                /* resolve base-relative relocation for executable file */
                struct LinkedSection *datals;

                if (datals = find_lnksec(gv,data_name,0,0,0,0)) {
                  a = (lword)rel->relocsect.lnk->base +
                      rel->addend - datals->base;
                  a = writesection(gv,ls->data+rel->offset,rel,a);
                  keep = FALSE;
                }
                else {
                  print_function_name(sec,rel->offset);
                  error(120,getobjname(sec->obj),sec->name,
                        rel->offset-sec->offset,data_name);
                }
              }
              break;
            
            case R_ABS:
            case R_NONE:
              break;

            default:
              ierror("%sReloc type %d (%s) is not yet supported",
                     fn,(int)rel->rtype,reloc_name[rel->rtype]);
              break;
          }

          if (keep) {
            /* keep relocations which cannot be resolved in output file */
/*@@@       writesection(gv,ls->data+rel->offset,rel,rel->addend); */
            addtail(&ls->relocs,&rel->n);
            a = 0;
          }

          if (a) {  /* relocation out of range! */
            print_function_name(sec,rel->offset);
            error(25,getobjname(sec->obj),sec->name,rel->offset-sec->offset,
                  (int)rel->insert->bsiz,reloc_name[rel->rtype],
                  rel->relocsect.lnk->name,rel->addend,a);
          }
        }


        /*------------------------------------*/
        /* resolve, fix and copy x-references */
        /*------------------------------------*/
        while (xref = (struct Reloc *)remhead(&sec->xrefs)) {
          struct Symbol *xdef;
          int err_no = 0;
          lword a = 0;
          bool make_reloc = FALSE;

          xref->offset += sec->offset;
          xdef = xref->relocsect.symbol;

          if (xdef != NULL &&
            /* dynamic relocations must be left alone */
              !(xref->flags & RELF_DYNLINK) &&
            /* common symbols have to be resolved in the final executable
               only, or when option -dc (allocate commons) is given */
              !(xref->relocsect.symbol->type==SYM_COMMON &&
                (gv->dest_object && !gv->alloc_common))) {

            /* Relative/absolute reference to absolute symbol */
            if (xdef->type == SYM_ABS) {
              a = xdef->value + xref->addend;
              err_no = 26;
            }

            else if (xdef->type == SYM_RELOC) {
              if (xdef->relsect->lnksec == NULL) {
                /* Cannot resolve reference to <sym-name>, because section
                   <name> was not recognized by the linker script */
                error(112,getobjname(sec->obj),sec->name,xref->offset,
                      xref->xrefname,xdef->relsect->name);
              }
              else {
                lword symoffset = xdef->value -
                                  (lword)xdef->relsect->lnksec->base;

                a = symoffset + xref->addend;

                switch (xref->rtype) {

                  case R_PLTPC:
                  case R_GOTPC:
                    /* PC-relative PLT/GOT reference */
                    if (gv->dest_object)
                      break;
                    xref->rtype = R_PC;
                    /* fall through */

                  case R_PC:
                    /* PC relative reference to relocatable symbol */
                    if (xdef->relsect->lnksec != ls) {
                      make_reloc = TRUE;
                    }
                    else {
                      a = (xdef->value + xref->addend) -
                          ((lword)sec->lnksec->base + (lword)xref->offset);
                      err_no = 28;
                    }
                    break;

                  case R_SECOFF:
                    /* reference to symbol's section offset */
                    err_no = 36;
                    if (gv->dest_object)
                      make_reloc = TRUE;
                    break;

                  case R_GOT:
                    /* _GLOBAL_OFFSET_TABLE_ relative reference to an
                       object's pointer slot in .got */
                  case R_GOTOFF:
                    /* symbol's offset to _GLOBAL_OFFSET_TABLE_ */
                    err_no = 36;
                    if (!gv->dest_object) {
                      if (gotbase) {
                        a = xdef->value + xref->addend - gotbase->value;
                      }
                      else
                        undef_sym_error(sec,xref,gv->got_base_name);
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_SD:
                    /* _SDA_BASE_ relative reference to relocatable symbol */
                    err_no = 36;
                    if (!gv->dest_object) {
                      if (sdabase) {
                        a = xdef->value + xref->addend - sdabase->value;
                      }
                      else
                        undef_sym_error(sec,xref,sdabase_name);
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_SD2:
                    /* _SDA2_BASE_ relative reference to relocatable symbol */
                    err_no = 36;
                    if (!gv->dest_object) {
                      if (sda2base) {
                        a = xdef->value + xref->addend - sda2base->value;
                      }
                      else
                        undef_sym_error(sec,xref,sda2base_name);
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_SD21:
                    /* PPC-EABI: base relative reference via base-reg 0,2 or 13 */
                    err_no = 36;
                    if (!gv->dest_object) {
                      const char *secname = xdef->relsect->lnksec->name;

                      *(ls->data+xref->offset+1) &= 0xe0;
                      if (!strcmp(secname,sdata_name) ||
                          !strcmp(secname,sbss_name)) {
                        if (sdabase) {
                          a = xdef->value + xref->addend - sdabase->value;
                          *(ls->data+xref->offset+1) |= 13;
                        }
                        else
                          undef_sym_error(sec,xref,sdabase_name);
                      }
                      else if (!strcmp(secname,sdata2_name) ||
                               !strcmp(secname,sbss2_name)) {
                        if (sda2base) {
                          a = xdef->value + xref->addend - sda2base->value;
                          *(ls->data+xref->offset+1) |= 2;
                        }
                        else
                          undef_sym_error(sec,xref,sda2base_name);
                      }
                      else if (!strcmp(secname,".PPC.EMB.sdata0") ||
                               !strcmp(secname,".PPC.EMB.sbss0")) {
                        a = xdef->value + xref->addend;
                      }
                      else {
                        print_function_name(sec,xref->offset);
                        error(117,getobjname(sec->obj),sec->name,
                              xref->offset-sec->offset,reloc_name[xref->rtype],
                              xdef->name,secname);
                      }
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_MOSDREL:
                    err_no = 36;
                    if (!gv->dest_object) {
                      if (r13init) {
                        a = xdef->value + xref->addend - r13init->value;
                      }
                      else
                        undef_sym_error(sec,xref,r13init_name);
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_AOSBREL:
                    err_no = 36;
                    if (!gv->dest_object) {
                      struct LinkedSection *datals;

                      if (datals = find_lnksec(gv,data_name,0,0,0,0)) {
                        a = xdef->value + xref->addend - datals->base;
                      }
                      else {
                        print_function_name(sec,xref->offset);
                        error(120,getobjname(sec->obj),sec->name,
                              rel->offset-sec->offset,data_name);
                      }
                    }
                    else
                      make_reloc = TRUE;
                    break;

                  case R_ABS:
                    /* Absolute reference to relocatable symbol */
                    make_reloc = TRUE;
                    /* fall through */

                  case R_NONE:
                    break;

                  default:
                    ierror("%sXRef reloc type %d (%s) is not yet supported",
                           fn,(int)xref->rtype,reloc_name[xref->rtype]);
                }
              }
            }
            else
              ierror("%s Referenced symbol has type %d",fn,(int)xdef->type);

            if (make_reloc) {
              /* turn into a relocation */
              xref->addend = a;
              xref->xrefname = NULL;
              xref->relocsect.lnk = xdef->relsect->lnksec;
              addtail(&ls->relocs,&xref->n);
            }
            else {
              if (a = writesection(gv,ls->data+xref->offset,xref,a)) {
                /* value of referenced symbol is out of range! */
                print_function_name(sec,xref->offset);
                error(err_no,getobjname(sec->obj),sec->name,
                      xref->offset-sec->offset,xdef->name,xdef->value,
                      xref->addend,a,(int)xref->insert->bsiz);
              }
            }
          }

          else /*@@@if (xref->rtype != R_NONE)*/ {
            /* xref remains in output file untouched */
            addtail(&ls->xrefs,&xref->n);
          }
        }
      }      
    }
  }
}


void linker_write(struct GlobalVars *gv)
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *firstls=NULL,*nextls;
  FILE *f;

  /* remove empty sections without referenced symbols and relocs */
  gv->nsecs = 0;
  while (nextls = (struct LinkedSection *)ls->n.next) {
    if (firstls == NULL)
      firstls = ls;

    if (ls->size==0 && listempty(&ls->relocs)
        && !(ls->ld_flags & LSF_PRESERVE)) {
      struct Symbol *sym;
      int keep = 0;

      for (sym=(struct Symbol *)ls->symbols.first;
           sym->n.next!=NULL; sym=(struct Symbol *)sym->n.next) {
        if (!discard_symbol(gv,sym) ||
            (sym->type!=SYM_ABS && (sym->flags & SYMF_REFERENCED)!=0))
          keep = 1;
      }
      if (!keep) {
        remnode(&ls->n);
        if (ls == firstls)
          firstls = NULL;
        ls = nextls;
        continue;
      }
      else if (ls!=firstls && (!strcmp(ls->name,gv->common_sec_name) ||
                               !strcmp(ls->name,gv->scommon_sec_name))) {
        /* @@@ Attention! This is a big HACK!
           For the future it should be desirable to have a separate
           list for common symbols, instead of just putting them into
           the symbol list of the first section... @@@ */
        struct Symbol *sym;

        while (sym = (struct Symbol *)remhead(&ls->symbols)) {
          addtail(&firstls->symbols,&sym->n);
        }
        remnode(&ls->n);
        ls = nextls;
        continue;
      }
    }

    ls->index = gv->nsecs++;  /* reindex remaining sections */
    ls = nextls;
  }

  if (!gv->errflag) {  /* no error? */
    if (gv->trace_file) {
      if (!gv->output_sections)
        fprintf(gv->trace_file,"\nCreating output file %s (%s).\n",
                gv->dest_name,fff[gv->dest_format]->tname);
      else
        fprintf(gv->trace_file,"\nCreating output files for each "
                               "section (%s).\n",
                fff[gv->dest_format]->tname);
    }

    /* create output file */
    if (!gv->output_sections) {
      if ((f = fopen(gv->dest_name,"wb")) == NULL) {
        error(29,gv->dest_name);  /* Can't create output file */
        return;
      }
    }
    else {
      f = NULL;
      if (!(fff[gv->dest_format]->flags & FFF_SECTOUT)) {
        error(29,"with sections");  /* Can't create output file with sect. */
        return;
      }
    }

    /* write output file */
    if (gv->dest_sharedobj)
      fff[gv->dest_format]->writeshared(gv,f);
    else if (gv->dest_object)
      fff[gv->dest_format]->writeobject(gv,f);
    else
      fff[gv->dest_format]->writeexec(gv,f);

    if (f != NULL) {
      fclose(f);
      if (!gv->dest_sharedobj && !gv->dest_object)
        set_exec(gv->dest_name);  /* set executable flag */
    }
  }
}


void linker_cleanup(struct GlobalVars *gv)
{
}
