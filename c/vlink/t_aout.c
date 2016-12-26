/* $VER: vlink t_aout.c V0.15a (27.02.16)
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

#include "config.h"
#ifdef AOUT
#define T_AOUT_C
#include "vlink.h"
#include "aout.h"

/* common a.out linker symbols */
static const char *aout_symnames[] = {
  gotbase_name,
  pltbase_name,
  dynamic_name
};
#define AOUTSTD_LNKSYMS 3
#define GOTSYM          0
#define PLTSYM          1
#define DYNAMICSYM      2

static struct ar_info ai;     /* for scanning library archives */
static uint8_t sectype[] = { N_TEXT, N_DATA, N_BSS };
static uint8_t weaktype[] = { N_WEAKT, N_WEAKD, N_WEAKB };

/* for generating a.out files */
struct SymTabList aoutsymlist; 
struct StrTabList aoutstrlist; 
static struct list treloclist;
static struct list dreloclist;



/*****************************************************************/
/*                          Read a.out                           */
/*****************************************************************/


static uint32_t aout_txtoffset(struct aout_hdr *hdr,int be)
{
  return (sizeof(struct aout_hdr));
}

static uint32_t aout_datoffset(struct aout_hdr *hdr,int be)
{
  return ((GETMAGIC(hdr) == ZMAGIC) ?
          (read32(be,hdr->a_text)) :
          (sizeof(struct aout_hdr) + read32(be,hdr->a_text)));
}

static uint32_t aout_bssoffset(struct aout_hdr *hdr,int be)
{
  return (aout_datoffset(hdr,be) + read32(be,&hdr->a_data));
}

static uint32_t aout_treloffset(struct aout_hdr *hdr,int be)
{
  return (aout_bssoffset(hdr,be));
}

static uint32_t aout_dreloffset(struct aout_hdr *hdr,int be)
{
  return (aout_treloffset(hdr,be) + read32(be,&hdr->a_trsize));
}

static uint32_t aout_symoffset(struct aout_hdr *hdr,int be)
{
  return (aout_dreloffset(hdr,be) + read32(be,&hdr->a_drsize));
}

static uint32_t aout_stroffset(struct aout_hdr *hdr,int be)
{
  return (aout_symoffset(hdr,be) + read32(be,&hdr->a_syms));
}


int aout_identify(struct FFFuncs *ff,char *name,struct aout_hdr *p,
                  unsigned long plen)
/* check a possible a.out file against the requirements, then */
/* return its type (object, library, shared object) */
{
  uint32_t mid = ff->id;
  bool arflag = FALSE;

  if (plen < ff->headersize(0))  /* @@@ gv-ptr is not needed for a.out ! */
    return (ID_UNKNOWN);

  if (ar_init(&ai,(char *)p,plen,name)) {
    /* library archive detected, extract 1st archive member */
    arflag = TRUE;
    if (!(ar_extract(&ai))) {
      error(38,name);  /* Empty archive ignored */
      return (ID_IGNORE);
    }
    p = (struct aout_hdr *)ai.data;
  }

  if (GETMID(p) == mid) {
    uint32_t mag = GETMAGIC(p);
    int fl = GETFLAGS(p) & EX_DPMASK;

    if (mag==OMAGIC || mag==NMAGIC || mag==ZMAGIC || mag==QMAGIC) {
      /* valid a.out format for this machine detected! */
      switch (mag) {
        case OMAGIC:
          return (arflag ? ID_LIBARCH : ID_OBJECT);
        case NMAGIC:
        case ZMAGIC:
          if (arflag) {
            if (fl == EX_DYNAMIC|EX_PIC)
              error(39,name,ff->tname); /* no shared objects in lib archives */
            else
              error(40,name,ff->tname); /* no executables in lib archives */
          }
          if (fl == EX_DYNAMIC|EX_PIC)
            return (ID_SHAREDOBJ);
          return (ID_EXECUTABLE);
        case QMAGIC:
          error(84,name); /* QMAGIC is deprecated */
          break;
      }
    }
  }
  return (ID_UNKNOWN);
}


static void aout_check_ar_type(struct FFFuncs *ff,const char *name,
                               struct aout_hdr *hdr)
/* check all library archive members before conversion */
{
  if (GETMID(hdr)==ff->id || GETMID(hdr)==0) {
    switch (GETMAGIC(hdr)) {
      case NMAGIC:
      case ZMAGIC:
        if (GETFLAGS(hdr)&EX_DPMASK == (EX_DYNAMIC|EX_PIC))
          error(39,name,ff->tname); /* no shared objects in lib archives */
        else
          error(40,name,ff->tname); /* no executables in lib archives */
        return;
      case QMAGIC:
        error(84,name); /* QMAGIC is deprecated */
      case OMAGIC:
        return;
      default:
        break;
    }
  }
  error(41,name,ff->tname);
}


static void aout_create_section(struct ObjectUnit *ou,struct FFFuncs *ff,
                                const char *sec_name,uint8_t *data,
                                unsigned long size,uint8_t type)
{
  struct LinkFile *lf = ou->lnkfile;
  uint8_t flags=0,protection;

  if (type != ST_UDATA) {
    if (data+size > lf->data+lf->length)  /* illegal section offset */
      error(49,lf->pathname,sec_name,lf->objname);
  }

  switch (type) {
    case ST_CODE:
      protection = SP_READ|SP_EXEC;
      break;
    case ST_DATA:
      protection = SP_READ|SP_WRITE;
      break;
    case ST_UDATA:
      protection = SP_READ|SP_WRITE;
      flags = SF_UNINITIALIZED;
      data = NULL;
      break;
  }
  add_section(ou,sec_name,data,size,type,flags|SF_ALLOC,
              protection,MIN_ALIGNMENT,FALSE);
}


static void aout_make_sections(struct ObjectUnit *ou,struct aout_hdr *hdr,
                               int be)
/* creates up to three sections from an a.out file */
{
  struct FFFuncs *ff = fff[ou->lnkfile->format];
  uint32_t size;

  if (size = read32(be,hdr->a_text))
    aout_create_section(ou,ff,TEXTNAME,((uint8_t *)hdr)+aout_txtoffset(hdr,be),
                        size,ST_CODE);

  if (size = read32(be,&hdr->a_data))
    aout_create_section(ou,ff,DATANAME,((uint8_t *)hdr)+aout_datoffset(hdr,be),
                        size,ST_DATA);

  if (size = read32(be,&hdr->a_bss))
    aout_create_section(ou,ff,BSSNAME,((uint8_t *)hdr)+aout_bssoffset(hdr,be),
                        size,ST_UDATA);
}


static void check_strtab(struct LinkFile *lf,struct aout_hdr *hdr,int be)
{
  char *strtab = ((char *)hdr) + aout_stroffset(hdr,be);

  if (((uint8_t *)strtab < lf->data) || ((uint8_t *)strtab +
       read32(be,(uint32_t *)strtab) > (lf->data + lf->length)))
    error(85,lf->pathname,"string",lf->objname);  /* illegal offset */
}


static char *get_symname(struct LinkFile *lf,struct aout_hdr *hdr,int be,
                         int32_t offset)
{
  char *symname = ((char *)hdr) + aout_stroffset(hdr,be) + offset;

  if (((uint8_t *)symname < lf->data) ||
      ((uint8_t *)symname > (lf->data + lf->length)))  /* illegal offset? */
    error(87,lf->pathname,offset,lf->objname);

  return (symname);
}


static void aout_symbols(struct GlobalVars *gv,struct ObjectUnit *ou,
                         struct aout_hdr *hdr,int be)
/* reads all symbols from an a.out and converts them into internal fmt. */
{
  struct LinkFile *lf = ou->lnkfile;
  struct nlist32 *nlst = (struct nlist32 *)(((char *)hdr) +
                                            aout_symoffset(hdr,be));
  uint32_t symtabsize = read32(be,&hdr->a_syms);
  uint32_t txtaddr = (GETMAGIC(hdr) == ZMAGIC) ? sizeof(struct aout_hdr) : 0;
  uint32_t dataddr = read32(be,hdr->a_text);
  uint32_t bssaddr = dataddr + read32(be,&hdr->a_data);
  int i;

  if (symtabsize == 0)
    return;  /* no symbols */

  if (((uint8_t *)nlst < lf->data) || 
      ((uint8_t *)nlst + symtabsize > lf->data + lf->length))
    error(85,lf->pathname,"symbol",lf->objname);  /* illegal offset */

  if (symtabsize % sizeof(struct nlist32) != 0)  /* symtab sanity check */
    error(86,lf->pathname,"symbol",lf->objname,sizeof(struct nlist32));

  check_strtab(lf,hdr,be);  /* strtab sanity check */

  /* read the symbols */
  for (i=0; i<(int)(symtabsize/sizeof(struct nlist32)); i++,nlst++) {
    char *symname,*indirname = NULL;
    uint8_t type=SYM_RELOC,objinfo,objbind;
    uint32_t saddr=0,size=0;
    uint32_t value=read32(be,&nlst->n_value);
    struct Section *sec = NULL;

    symname = get_symname(lf,hdr,be,read32(be,&nlst->n_strx));

    switch (nlst->n_other & 0x0f) {
      case AUX_FUNC:
      case AUX_LABEL: /* @@@ what's label? */
        objinfo = SYMI_FUNC;
        break;
      case AUX_OBJECT:
        objinfo = SYMI_OBJECT;
        break;
      default:
        objinfo = SYMI_NOTYPE;
        break;
    }

    objbind = (nlst->n_type & N_EXT) ? SYMB_GLOBAL : SYMB_LOCAL;
    switch ((nlst->n_other & 0xf0) >> 4) {
      /* seems that local and global are not used in a.out... */
      case BIND_LOCAL:
        /*objbind = SYMB_LOCAL;*/
        break;
      case BIND_GLOBAL:
        /*objbind = SYMB_GLOBAL;*/
        break;
      case BIND_WEAK:
        objbind = SYMB_WEAK;
        break;
      default:  /* illegal binding type */
        error(88,lf->pathname,symname,(nlst->n_other&0xf0)>>4,lf->objname);
        break;
    }

    if (nlst->n_type & N_STAB) {
      /* debugging symbols */

      if (gv->strip_symbols < STRIP_DEBUG) {
        switch (nlst->n_type & N_TYPE) {
          case N_TEXT:
            if (!(sec = find_sect_type(ou,ST_CODE,SP_READ|SP_EXEC)))
              sec = add_section(ou,TEXTNAME,NULL,0,ST_CODE,SF_ALLOC,
                                SP_READ|SP_EXEC,MIN_ALIGNMENT,FALSE);
            saddr = txtaddr;
            break;
          case N_DATA:
            if (!(sec = find_sect_type(ou,ST_DATA,SP_READ|SP_WRITE)))
              sec = add_section(ou,DATANAME,NULL,0,ST_DATA,SF_ALLOC,
                                SP_READ|SP_WRITE,MIN_ALIGNMENT,FALSE);
            saddr = dataddr;
            break;
          case N_BSS:
            if (!(sec = find_sect_type(ou,ST_UDATA,SP_READ|SP_WRITE)))
              sec = add_section(ou,BSSNAME,NULL,0,ST_UDATA,
                                SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,
                                MIN_ALIGNMENT,FALSE);
            saddr = bssaddr;
            break;
        }

        addstabs(ou,sec,symname,nlst->n_type,nlst->n_other,
                 (int16_t)read16(be,&nlst->n_desc),value - saddr);
      }
    }

    else {
      /* normal symbols */

      switch (nlst->n_type & (N_TYPE | N_EXT)) {
        case N_WEAKU:
          objbind = SYMB_WEAK;
          /* fall through */
        case N_UNDF: case N_UNDF | N_EXT:
          if (value) {
            /* undefd. symbol with a value is assumed to be a common symbol */
            sec = common_section(gv,ou);
            type = SYM_COMMON;
            size = value;
            value = MIN_ALIGNMENT;
          }
          /* ignore undefined symbols for now */
          break;

        /* assign a section for ABS and COMMON symbols, to prevent */
        /* accidental NULL-pointer references */
        case N_WEAKA:
          objbind = SYMB_WEAK;
          /* fall through */
        case N_ABS: case N_ABS | N_EXT:
          sec = abs_section(ou);
          type = SYM_ABS;
          break;

#if 0 /* @@@ N_UNDF is used instead? */
        case N_COMM: case N_COMM | N_EXT:
          sec = common_section(gv,ou);
          type = SYM_COMMON;
          size = value;
          break;
#endif

        case N_WEAKT:
          objbind = SYMB_WEAK;
          /* fall through */
        case N_TEXT: case N_TEXT | N_EXT:
          if (!(sec = find_sect_type(ou,ST_CODE,SP_READ|SP_EXEC)))
            sec = add_section(ou,TEXTNAME,NULL,0,ST_CODE,SF_ALLOC,
                              SP_READ|SP_EXEC,MIN_ALIGNMENT,FALSE);
          saddr = txtaddr;
          break;

        case N_WEAKD:
          objbind = SYMB_WEAK;
          /* fall through */
        case N_DATA: case N_DATA | N_EXT:
          if (!(sec = find_sect_type(ou,ST_DATA,SP_READ|SP_WRITE)))
            sec = add_section(ou,DATANAME,NULL,0,ST_DATA,SF_ALLOC,
                              SP_READ|SP_WRITE,MIN_ALIGNMENT,FALSE);
          saddr = dataddr;
          break;

        case N_WEAKB:
          objbind = SYMB_WEAK;
          /* fall through */
        case N_BSS: case N_BSS | N_EXT:
          if (!(sec = find_sect_type(ou,ST_UDATA,SP_READ|SP_WRITE)))
            sec = add_section(ou,BSSNAME,NULL,0,ST_UDATA,
                              SF_ALLOC|SF_UNINITIALIZED,SP_READ|SP_WRITE,
                              MIN_ALIGNMENT,FALSE);
          saddr = bssaddr;
          break;

        case N_INDR: case N_INDR | N_EXT:
          sec = abs_section(ou);
          type = SYM_INDIR;
          indirname = get_symname(lf,hdr,be,
                                  read32(be,&(nlst+1)->n_strx));
          break;

        case N_SIZE:
          /* ignored */
          error(96,lf->pathname,(int)value,lf->objname);
          break;

        case N_FN | N_EXT:
          sec = abs_section(ou);
          type = SYM_ABS;
          objinfo = SYMI_FILE;
          objbind = SYMB_LOCAL;
          break;

        default:
          ierror("aout_symbols(): Symbol %s in %s has type %d, "
                 "which is currently not supported",
                 symname,lf->pathname,nlst->n_type&N_TYPE);
          break;
      }

      if (sec) {
        /* check for symbol size: following symbol has to be type = N_SIZE */
        /* and the same symbol name */
        if ((i+1)<(int)(symtabsize/sizeof(struct nlist32)) &&
            ((nlst+1)->n_type & N_TYPE) == N_SIZE) {
          if (!strcmp(symname,get_symname(lf,hdr,be,
                      read32(be,&(nlst+1)->n_strx)))) {
            i++;  /* skip symbol */
            nlst++;
            size = read32(be,&nlst->n_value);
          }
        }

        /* convert a.out specific file offset into a section offset */
        value -= saddr;

        /* add a new symbol definition */
        if (objbind == SYMB_LOCAL) {
          addlocsymbol(gv,sec,symname,indirname,(int32_t)value,
                       type,0,objinfo,size);
        }
        else {
          addsymbol(gv,sec,symname,indirname,(int32_t)value,
                    type,0,objinfo,objbind,size,TRUE);
        }
      }
    }
  }
}


static void aout_newreloc(struct GlobalVars *gv,struct aout_hdr *hdr,
                          struct Section *sec,uint32_t saddr,uint32_t symidx,
                          bool xtern,uint8_t rtype,uint16_t size,
                          uint32_t offs,int be)
{
  const char *fn = "aout_newreloc(): ";
  struct ObjectUnit *ou = sec->obj;
  struct LinkFile *lf = ou->lnkfile;
  lword mask = -1;
  lword a = readsection(gv,rtype,sec->data+offs,0,size,mask);

  if (rtype == R_AOUT_MOVEI)
    a = sign_extend(SWAP16(a),32);  /* swap 16-bit words */

  if (xtern) {
    /* relocation by an external reference to an unknown symbol */
    char *strtab = ((char *)hdr) + aout_stroffset(hdr,be);
    struct nlist32 *nlst = (struct nlist32 *)(((char *)hdr) +
                                              aout_symoffset(hdr,be));
    char *xrefname = strtab + read32(be,&nlst[symidx].n_strx);

    if (rtype == R_PC) {
      /* fix a.out specific PC-relative relocs */
      a += (lword)saddr + (lword)offs;
    }

    if (nlst[symidx].n_type == N_EXT|N_UNDF) {
      if (rtype == R_AOUT_MOVEI) {
        addreloc(sec,newreloc(gv,sec,xrefname,NULL,0,offs,R_ABS,a),
                 0,16,0xffff);
        addreloc(sec,newreloc(gv,sec,xrefname,NULL,0,offs+2,R_ABS,a),
                 0,16,0xffff0000);
      }
      else
        addreloc(sec,newreloc(gv,sec,xrefname,NULL,0,offs,rtype,a),
                 0,size,mask);
    }
    else
      error(91,lf->pathname,xrefname,sec->name);  /* illegal ext. ref. */
  }

  else {
    /* local relocation */
    struct Section *rsec = NULL;
    uint32_t rsaddr = 0; /* reloc section base address in object file */

    if (symidx & ~N_TYPE)  /* illegal nlist type in relocation */
      error(92,lf->pathname,symidx,sec->name,lf->objname,offs);

    switch (symidx & N_TYPE) {
      case N_TEXT:
        if (!(rsec = find_sect_type(ou,ST_CODE,SP_READ|SP_EXEC)))
          ierror("%sno .text for reloc found",fn);
        rsaddr = 0;
        break;

      case N_DATA:
        if (!(rsec = find_sect_type(ou,ST_DATA,SP_READ|SP_WRITE)))
          ierror("%sno .data for reloc found",fn);
        rsaddr = read32(be,hdr->a_text);
        break;

      case N_BSS:
        if (!(rsec = find_sect_type(ou,ST_UDATA,SP_READ|SP_WRITE)))
          ierror("%sno .bss for reloc found",fn);
        rsaddr = read32(be,hdr->a_text) + read32(be,&hdr->a_data);
        break;

      default:
        ierror("%slocal reloc with nlist type %lu is not supported",
               fn,symidx&N_TYPE);
        break;
    }

    /* fix addend for a.out */
    switch (rtype) {
      case R_ABS:
      case R_AOUT_MOVEI:
        a -= (lword)rsaddr;
        break;
      case R_PC:
        a += (lword)offs;
        break;
      case R_SD:
        /* @@@ A local baserel relocation will not happen in standard a.out. */
        /* A GOT base offset is always based on a symbol. But we use it here */
        /* to support small data mode... */
        a -= (lword)rsaddr;
        break;
    }

    if (rtype == R_AOUT_MOVEI) {
      addreloc(sec,newreloc(gv,sec,NULL,rsec,0,offs,R_ABS,a),
               0,16,0xffff);
      addreloc(sec,newreloc(gv,sec,NULL,rsec,0,offs+2,R_ABS,a),
               0,16,0xffff0000);
    }
    else
      addreloc(sec,newreloc(gv,sec,NULL,rsec,0,offs,rtype,a),0,size,mask);
  }
}


int aout_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                    struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  /* a.out requires that all sections of type CODE or DATA or BSS */
  /* will be combined, because there are only those three available! */
  if (ls->type == s->type)
    return (1);

  return (0);
}


struct Symbol *aout_lnksym(struct GlobalVars *gv,struct Section *sec,
                           struct Reloc *xref)
/* Check for common a.out linker symbols. */
{
  struct Symbol *sym;
  int i;

  if (!gv->dest_object) {
    for (i=0; i<AOUTSTD_LNKSYMS; i++) {
      if (!strcmp(aout_symnames[i],xref->xrefname)) {
        sym = addlnksymbol(gv,aout_symnames[i],0,SYM_ABS,
                           SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
        sym->extra = i; /* for easy ident. in aout_setlnksym */
        switch (i) {
          case GOTSYM:
            gv->got_base_name = aout_symnames[i];
            sym->type = SYM_RELOC;
            break;
          case PLTSYM:
            gv->got_base_name = aout_symnames[i];
            sym->type = SYM_RELOC;
            break;
          case DYNAMICSYM:
            break;
        }
        return (sym);  /* new linker symbol created */
      }
    }
  }
  return (NULL);
}


void aout_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
/* Initialize common a.out linker symbol structure during resolve_xref() */
{
  struct FFFuncs *tf = fff[gv->dest_format];

  if (xdef->flags & SYMF_LNKSYM) {
    switch (xdef->extra) {
      case GOTSYM:
      case PLTSYM:
      case DYNAMICSYM:
        /* @@@ FIXME! NOW! */
        break;
    }
    xdef->flags &= ~SYMF_LNKSYM;  /* do not init again */
  }
}


void aoutstd_relocs(struct GlobalVars *gv,struct ObjectUnit *ou,
                    struct aout_hdr *hdr,int be,
                    struct relocation_info *reloc,uint32_t rsize,
                    struct Section *sec,uint32_t saddr)
/* reads all relocations in standard format for a section */
{
  static uint16_t bsize[4] = { 8,16,32,64 };
  struct LinkFile *lf = ou->lnkfile;
  uint32_t mid = GETMID(hdr);

  if (sec) {
    int i;

    if (((uint8_t *)reloc < lf->data) ||
        (((uint8_t *)reloc)+rsize > lf->data + lf->length))
      error(85,lf->pathname,"stdreloc",lf->objname);  /* illegal offset */

    if (rsize % sizeof(struct relocation_info) != 0)  /* reloc sanity check */
      error(86,lf->pathname,"stdreloc",lf->objname,
            sizeof(struct relocation_info));

    for (i=0; i<(rsize/sizeof(struct relocation_info)); i++,reloc++) {
      uint32_t *info = &reloc->r_info;
      uint32_t symnum = readbf32(be,info,RELB_symbolnum,RELS_symbolnum);
      int size = readbf32(be,info,RSTDB_length,RSTDS_length);
      int pcrel = readbf32(be,info,RSTDB_pcrel,RSTDS_pcrel);
      int baserel = readbf32(be,info,RSTDB_baserel,RSTDS_baserel);
      int jmptable = readbf32(be,info,RSTDB_jmptable,RSTDS_jmptable);
      int relative = readbf32(be,info,RSTDB_relative,RSTDS_relative);
      int copy = readbf32(be,info,RSTDB_copy,RSTDS_copy);
      int xtern = readbf32(be,info,RSTDB_extern,RSTDS_extern);
      uint8_t rtype;

      if (!pcrel && !baserel && !jmptable && !relative && !copy) {
        rtype = R_ABS;
      }
      else if (pcrel && !baserel && !jmptable && !relative && !copy) {
        rtype = R_PC;
      }
      else if (baserel && !pcrel && !jmptable && !relative && !copy) {
        rtype = R_SD;
      }
      else if (!mid && !pcrel && !baserel && !jmptable && !relative &&
               copy && size==2) {
        /* MID 0 and 32-bit COPY reloc may indicate a Jaguar GPU
           MOVEI RISC-instruction, which has swapped 16-bit words */
        rtype = R_AOUT_MOVEI;
        if (gv->endianess < 0)
          gv->endianess = _BIG_ENDIAN_;  /* Jaguar is big-endian */
      }
      else
        ierror("aoutstd_relocs(): %s (%s): Reloc type "
               "<pcrel=%d len=%d extern=%d baserel=%d jmptab=%d "
               "rel=%d copy=%d> in %s is currently not supported",
               lf->pathname,lf->objname,pcrel,bsize[size],xtern,baserel,
               jmptable,relative,copy,sec->name);

      if (rtype) {
        /* create a.out relocation */
        aout_newreloc(gv,hdr,sec,saddr,symnum,xtern!=0,rtype,bsize[size],
                      read32(be,&reloc->r_address),be);
      }
      else {
        /* illegal a.out relocation */
        error(90,lf->pathname,sec->name,lf->objname,
              (uint32_t)read32(be,&reloc->r_address),pcrel,size,xtern,
              baserel,jmptable,relative,copy);
      }
    }
  }

  else if (rsize) {
    /* no section for these relocations! */
    error(89,lf->pathname,lf->objname);
  }
}


void aoutstd_read(struct GlobalVars *gv,struct LinkFile *lf,
                  struct aout_hdr *hdr)
/* read an a.out file with standard relocations */
{
  /*int so = (GETFLAGS(hdr)&EX_DPMASK) == (EX_DYNAMIC|EX_PIC);*/
  int be;
  struct ObjectUnit *u;

  /* determine endianess */
  if (fff[lf->format]->endianess < 0) {
    if (gv->endianess < 0) {
      /* unknown endianess, default to BE */
      be = gv->endianess = host_endianess();
      error(128,lf->pathname,endian_name[be]);
    }
    else
      be = gv->endianess;
  }
  else
    be = fff[lf->format]->endianess;

  if (lf->type == ID_LIBARCH)  /* check ar-member for correct format */
    aout_check_ar_type(fff[lf->format],lf->pathname,hdr);

  u = create_objunit(gv,lf,lf->objname);

  aout_make_sections(u,hdr,be);   /* create up to 3 sections */
  aout_symbols(gv,u,hdr,be);      /* read all symbols */

  aoutstd_relocs(gv,u,hdr,be,(struct relocation_info *)    /* .text relocs */
                 (((uint8_t *)hdr)+aout_treloffset(hdr,be)),
                 read32(be,&hdr->a_trsize),
                 find_sect_type(u,ST_CODE,SP_READ|SP_EXEC),0);
  aoutstd_relocs(gv,u,hdr,be,(struct relocation_info *)    /* .data relocs */
                 (((uint8_t *)hdr)+aout_dreloffset(hdr,be)),
                 read32(be,&hdr->a_drsize),
                 find_sect_type(u,ST_DATA,SP_READ|SP_WRITE),
                 read32(be,hdr->a_text));

  /* add new object unit to the appropriate list */
  add_objunit(gv,u,FALSE);
}


void aoutstd_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read a.out executable / object / shared obj. with standard relocs */
{
  if (lf->type == ID_LIBARCH) {
    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        aoutstd_read(gv,lf,(struct aout_hdr *)ai.data);
      }
    }
    else
      ierror("aoutstd_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    aoutstd_read(gv,lf,(struct aout_hdr *)lf->data);
  }
}



/*****************************************************************/
/*                          Write a.out                          */
/*****************************************************************/


unsigned long aout_headersize(struct GlobalVars *gv)
{
  return (sizeof(struct aout_hdr));
}


static int aout_sectindex(struct LinkedSection **sections,
                          struct LinkedSection *ls)
/* return index (0,1,2 = .text,.data,.bss) of 'ls' */
{
  int sec;

  for (sec=0; sec<3; sec++) {
    if (sections[sec] == ls)
      break;
  }
  if (sec>=3)
    ierror("aout_sectindex(): Section %s not found in list",ls->name);
  return (sec);
}


void aout_initwrite(struct GlobalVars *gv,struct LinkedSection **sections)
{
  static const char *fn = "aout_initwrite(): ";
  struct LinkedSection *ls;

  initlist(&aoutstrlist.l);
  aoutstrlist.hashtab = alloczero(STRHTABSIZE*sizeof(struct StrTabNode *));
  aoutstrlist.nextoffset = 4;  /* first string is always at offset 4 */
  initlist(&aoutsymlist.l);
  aoutsymlist.hashtab = alloczero(SYMHTABSIZE*sizeof(struct SymbolNode *));
  aoutsymlist.nextindex = 0;
  initlist(&treloclist);
  initlist(&dreloclist);

  get_text_data_bss(gv,sections);
}


static uint8_t aout_getinfo(struct Symbol *sym)
{
  uint8_t type;

  switch (sym->info) {
    case SYMI_NOTYPE:
    case SYMI_FILE:
    case SYMI_SECTION:  /* this will be ignored later */
      type = AUX_UNKNOWN;
      break;
    case SYMI_OBJECT:
      type = AUX_OBJECT;
      break;
    case SYMI_FUNC:
      type = AUX_FUNC;
      break;
    default:
      ierror("aout_getinfo(): Illegal symbol info: %d",(int)sym->info);
      break;
  }
  return (type);
}


static uint8_t aout_getbind(struct Symbol *sym)
{
  uint8_t bind;

  switch (sym->bind) {
    case SYMB_LOCAL:
      bind = BIND_LOCAL;
      break;
    case SYMB_GLOBAL:
      bind = BIND_GLOBAL;
      break;
    case SYMB_WEAK:
      bind = BIND_WEAK;
      break;
    default:
      ierror("aout_getbind(): Illegal symbol binding: %d",(int)sym->bind);
      break;
  }
  return (bind);
}


static uint32_t aout_addstr(const char *s)
/* add a new symbol name to the string table and return its offset */
{
  struct StrTabNode **chain = &aoutstrlist.hashtab[elf_hash(s)%STRHTABSIZE];
  struct StrTabNode *sn;

  if (*s == '\0')
    return (0);

  /* search string in hash table */
  while (sn = *chain) {
    if (!strcmp(s,sn->str))
      return (sn->offset);  /* it's already in, return offset */
    chain = &sn->hashchain;
  }

  /* new string table entry */
  *chain = sn = alloc(sizeof(struct StrTabNode));
  sn->hashchain = NULL;
  sn->str = s;
  sn->offset = aoutstrlist.nextoffset;
  addtail(&aoutstrlist.l,&sn->n);
  aoutstrlist.nextoffset += (uint32_t)strlen(s) + 1;
  return (sn->offset);
}


static uint32_t aout_addsym(const char *name,uint32_t value,uint8_t bind,
                           uint8_t info,uint8_t type,int16_t desc,int be)
/* add a new symbol, return its symbol table index */
{
  struct SymbolNode **chain;
  struct SymbolNode *sym;

  if (name == NULL)
    name = noname;

  chain = &aoutsymlist.hashtab[elf_hash(name)%SYMHTABSIZE];
  while (sym = *chain)
    chain = &sym->hashchain;
  /* new symbol table entry */
  *chain = sym = alloczero(sizeof(struct SymbolNode));

  sym->name = name;
  sym->index = aoutsymlist.nextindex++;
  write32(be,&sym->s.n_strx,aout_addstr(name));
  sym->s.n_type = type;
  /* @@@ GNU binutils don't use BIND_LOCAL/GLOBAL in a.out files! We do! */
  sym->s.n_other = ((bind&0xf)<<4) | (info&0xf);
  write16(be,&sym->s.n_desc,desc);
  write32(be,&sym->s.n_value,value);
  addtail(&aoutsymlist.l,&sym->n);
  return (sym->index);
}


static void aout_symconvert(struct GlobalVars *gv,struct Symbol *sym,
                            uint8_t symbind,uint8_t syminfo,
                            struct LinkedSection **ls,int sec,int be)
/* convert vlink symbol into a.out symbol(s) */
{
  uint32_t val = (uint32_t)sym->value;
  uint32_t size = sym->size;
  uint8_t ext = (symbind == BIND_GLOBAL) ? N_EXT : 0;
  uint8_t type = 0;

  if (sym->info == SYMI_SECTION) {
    return;   /* section symbols are ignored in a.out! */
  }
  else if (sym->info == SYMI_FILE) {
    type = N_FN | N_EXT;  /* special case: file name symbol */
    size = 0;
  }
  else {
    if (symbind == BIND_WEAK) {
      switch (sym->type) {
        case SYM_ABS:
          type = N_WEAKA;
          break;
        case SYM_RELOC:
          type = weaktype[sec];
          break;
        default:
          ierror("aout_symconvert(): Illegal weak symbol type: %d",
                 (int)sym->type);
          break;
      }
    }
    else {
      switch (sym->type) {
        case SYM_ABS:
          type = N_ABS | ext;
          break;
        case SYM_RELOC:
          type = sectype[sec] | ext;
          break;
        case SYM_COMMON:
          #if 0 /* GNU binutils prefers N_UNDF with value!=0 instead of N_COMM! */
          type = N_COMM | ext;
          #else
          type = N_UNDF | N_EXT;
          #endif
          val = sym->size;
          size = 0;
          break;
        case SYM_INDIR:
          aout_addsym(sym->name,0,symbind,0,N_INDR|ext,0,be);
          aout_addsym(sym->indir_name,0,0,0,N_UNDF|N_EXT,0,be);
          return;
        default:
          ierror("aout_symconvert(): Illegal symbol type: %d",(int)sym->type);
          break;
      }
    }
  }

  aout_addsym(sym->name,val,symbind,syminfo,type,0,be);
  if (size) {
    /* append N_SIZE symbol declaring the previous symbol's size */
    aout_addsym(sym->name,size,symbind,syminfo,N_SIZE,0,be);
  }
}


void aout_addsymlist(struct GlobalVars *gv,struct LinkedSection **ls,
                     uint8_t bind,uint8_t type,int be)
/* add all symbols with specified bind and type to the a.out symbol list */
{
  int i;

  for (i=0; i<3; i++) {
    if (ls[i]) {
      struct Symbol *sym = (struct Symbol *)ls[i]->symbols.first;
      struct Symbol *nextsym;

      while (nextsym = (struct Symbol *)sym->n.next) {
        uint8_t syminfo = aout_getinfo(sym);
        uint8_t symbind = aout_getbind(sym);

        if (symbind == bind && (!type || (syminfo == type))) {
          if (!discard_symbol(gv,sym)) {
            remnode(&sym->n);
            /* add new symbol(s) */
            aout_symconvert(gv,sym,symbind,syminfo,ls,i,be);
          }
        }
        sym = nextsym;
      }
    }
  }
}


void aout_debugsyms(struct GlobalVars *gv,bool be)
/* add debug stab-entries to symbol table, sorted by ObjectUnits */
{
  struct ObjectUnit *obj;
  struct StabDebug *stab;

  if (gv->strip_symbols < STRIP_DEBUG) {
    for (obj=(struct ObjectUnit *)gv->selobjects.first;
         obj->n.next!=NULL; obj=(struct ObjectUnit *)obj->n.next) {
      for (stab=(struct StabDebug *)obj->stabs.first;
           stab->n.next!=NULL; stab=(struct StabDebug *)stab->n.next) {
        aout_addsym(stab->name.ptr,stab->n_value,stab->n_othr&0xf,
                    (stab->n_othr>>4)&0xf,stab->n_type,stab->n_desc,be);
      }
    }
  }
}


static int aout_findsym(const char *name,bool be)
/* find a symbol by its name, return symbol table index or -1 */
{
  struct SymbolNode **chain = &aoutsymlist.hashtab[elf_hash(name)%SYMHTABSIZE];
  struct SymbolNode *sym;

  while (sym = *chain) {
    if (!strcmp(name,sym->name))
      return ((int)sym->index);
    chain = &sym->hashchain;
  }
  return (-1);
}


static void detect_movei_relocs(struct Reloc *first)
/* Search for possible MOVEI RISC relocations and flag them by the
   internal type R_AOUT_MOVEI. */
{
  struct Reloc *r;
  struct RelocInsert *ri;

  for (r=first; r->n.next!=NULL; r=(struct Reloc *)r->n.next) {
    if (r->rtype==R_ABS && (ri = r->insert)) {
      if (ri->bpos==0 && !ri->next && ri->bsiz==16 &&
          (ri->mask&0xffffffff)==0xffff0000) {
        /* Found a MOVEI reloc candidate. The 16-bit word to the left needs
           another 16-bit reloc with mask=0xffff and the same addend
           to confirm it! */
        unsigned long off = r->offset - 2;
        struct Reloc *r2;

        for (r2=first; r2->n.next!=NULL; r2=(struct Reloc *)r2->n.next) {
          if (r2->offset==off && r2->rtype==R_ABS && (ri = r2->insert)) {
            if (ri->bpos==0 && !ri->next && ri->bsiz==16 && ri->mask==0xffff) {
              /* MOVEI reloc with swapped words found */
              r2->rtype = R_AOUT_MOVEI;
              r->rtype = R_NONE;
              break;
            }
          }
        }
      }
    }
  }
}


static void aout_addreloclist(struct list *rlst,int32_t raddr,uint32_t rindex,
                              uint32_t rinfo,int be)
/* add new relocation_info to .text or .data reloc-list */
{
  struct RelocNode *rn = alloc(sizeof(struct RelocNode));

  write32(be,&rn->r.r_address,(uint32_t)raddr);
  writebf32(be,&rn->r.r_info,RELB_symbolnum,RELS_symbolnum,rindex);
  writebf32(be,&rn->r.r_info,RELB_reloc,RELS_reloc,rinfo);
  addtail(rlst,&rn->n);
}


uint32_t aout_addrelocs(struct GlobalVars *gv,struct LinkedSection **ls,
                      int sec,struct list *rlst,
                      uint32_t (*getrinfo)(struct GlobalVars *,struct Reloc *,
                                          bool,const char *,uint32_t),
                      int be)
/* creates a.out relocations for a single section (.text or .data) */
{
  struct Reloc *rel;
  uint32_t rtabsize=0,rinfo;
  lword a;

  if (ls[sec]) {
    if (fff[gv->dest_format]->flags & AOUT_JAGRELOC) {
      /* Output is for Atari Jaguar, so search for possible MOVEI RISC
         relocations and flag them by the internal type R_AOUT_MOVEI. */
      detect_movei_relocs((struct Reloc *)ls[sec]->relocs.first);
      detect_movei_relocs((struct Reloc *)ls[sec]->xrefs.first);
    }

    /* relocations */
    for (rel=(struct Reloc *)ls[sec]->relocs.first; rel->n.next!=NULL;
         rel=(struct Reloc *)rel->n.next) {
      int rsec = aout_sectindex(ls,rel->relocsect.lnk);

      if (rel->flags & RELF_INTERNAL)
        continue;  /* internal relocations will never be exported */

      /* fix addend for a.out */
      if (rel->rtype == R_PC)
        a = rel->addend - ((lword)ls[sec]->base + rel->offset);
      else
        a = (lword)ls[rsec]->base + rel->addend;
      /* @@@ calculation for other relocs: baserel,jmptab,load-relative? */

      if (rel->rtype == R_AOUT_MOVEI)
        a = sign_extend(SWAP16(a),32);

      if ((rinfo = getrinfo(gv,rel,FALSE,ls[sec]->name,rel->offset)) != ~0) {
        aout_addreloclist(rlst,rel->offset,(uint32_t)sectype[rsec],rinfo,be);
        writesection(gv,ls[sec]->data+rel->offset,rel,a);
        rtabsize += sizeof(struct relocation_info);
      }
    }

    /* external references */
    for (rel=(struct Reloc *)ls[sec]->xrefs.first; rel->n.next!=NULL;
         rel=(struct Reloc *)rel->n.next) {
      uint32_t symidx;

      if (rel->flags & RELF_INTERNAL)
        continue;  /* internal relocations will never be exported */
      if ((symidx = aout_findsym(rel->xrefname,be)) == -1)
        symidx = aout_addsym(rel->xrefname,0,0,0,N_UNDF|N_EXT,0,be);

      /* fix addend for a.out */
      if (rel->rtype == R_PC)
        a = rel->addend - (lword)(ls[sec]->base + rel->offset);
      else
        a = rel->addend;
      /* @@@ calculation for other relocs: baserel,jmptab,load-relative? */

      if (rel->rtype == R_AOUT_MOVEI)
        a = sign_extend(SWAP16(a),32);

      if ((rinfo = getrinfo(gv,rel,TRUE,ls[sec]->name,rel->offset)) != ~0) {
        aout_addreloclist(rlst,rel->offset,symidx,rinfo,be);
        writesection(gv,ls[sec]->data+rel->offset,rel,a);
        rtabsize += sizeof(struct relocation_info);
      }
    }
  }

  return (rtabsize);
}


void aout_header(FILE *f,uint32_t mag,uint32_t mid,uint32_t flag,
                 uint32_t tsize,uint32_t dsize,uint32_t bsize,uint32_t syms,
                 uint32_t entry,uint32_t trsize,uint32_t drsize,int be)
/* write an a.out header */
{
  struct aout_hdr h;

  SETMIDMAG(&h,mag,mid,flag);
  write32(be,h.a_text,tsize);
  write32(be,h.a_data,dsize);
  write32(be,h.a_bss,bsize);
  write32(be,h.a_syms,syms);
  write32(be,h.a_entry,entry);
  write32(be,h.a_trsize,trsize);
  write32(be,h.a_drsize,drsize);
  fwritex(f,&h,sizeof(struct aout_hdr));
}


static void check_overlap(struct GlobalVars *gv,struct LinkedSection *ls1,
                          struct LinkedSection *ls2)
/* overlapping sections in paged memory layout? */
{
  if (ls1 && ls2) {
    if (ls1->base+ls1->size > ls2->base)
      error(98,fff[gv->dest_format]->tname,ls1->name,ls2->name);
  }
}


static bool isPIC(struct LinkedSection **secs)
/* check if all sections contain position independant code (PIC) */
{
  int i;

  for (i=0; i<3; i++) {
    if (secs[i]) {
      struct Reloc *r;

      for (r=(struct Reloc *)secs[i]->relocs.first; r->n.next!=NULL;
           r=(struct Reloc *)r->n.next) {
        if (r->rtype == R_ABS)
          return (FALSE);
      }
      for (r=(struct Reloc *)secs[i]->xrefs.first; r->n.next!=NULL;
           r=(struct Reloc *)r->n.next) {
        if (r->rtype == R_ABS)
          return (FALSE);
      }
    }
  }
  return (TRUE);
}


uint32_t aout_getpagedsize(struct GlobalVars *gv,struct LinkedSection **ls,
                         int sec)
/* return size of section aligned to page boundaries */
{
  unsigned long pagealign = shiftcnt(fff[gv->dest_format]->page_size);

  if (sec == 0) {  /* .text */
    if (ls[1]) {  /* followed by .data */
      check_overlap(gv,ls[0],ls[1]);
      return ((ls[1]->base - ls[0]->base) + sizeof(struct aout_hdr));
    }
    else { /* align section size to page boundary */
      check_overlap(gv,ls[0],ls[2]);
      return (ls[0]->size + sizeof(struct aout_hdr) +
              align(ls[0]->base+ls[0]->size,pagealign));
    }
  }
  else if (sec == 1) {  /* .data */
    if (ls[1]) {
      check_overlap(gv,ls[1],ls[2]);
      return (ls[1]->size + align(ls[1]->base+ls[1]->size,pagealign));
    }
  }
  else if (ls[2]) {  /* .bss */
    /* parts of .bss might disappear in the last .text or .data page */
    unsigned long bytes_in_last_page = align(ls[2]->base,pagealign);

    if (bytes_in_last_page < ls[2]->size)
      return (ls[2]->size - bytes_in_last_page);
  }

  return (0);
}


void aout_pagedsection(struct GlobalVars *gv,FILE *f,
                       struct LinkedSection **ls,int sec)
/* write .text and .data section aligned to page boundaries */
{
  if (ls[sec]) {
    fwritex(f,ls[sec]->data,ls[sec]->size);
    fwritegap(f,aout_getpagedsize(gv,ls,sec) -
              (sec ? ls[sec]->size : ls[sec]->size+sizeof(struct aout_hdr)));
  }
}


void aout_writesection(FILE *f,struct LinkedSection *ls,uint8_t alignment)
{
  if (ls) {
    fwritex(f,ls->data,ls->size);
    fwrite_align(f,alignment,ls->size);
  }
}


void aout_writerelocs(FILE *f,struct list *l)
{
  struct RelocNode *rn;

  while (rn = (struct RelocNode *)remhead(l))
    fwritex(f,&rn->r,sizeof(struct relocation_info));
}


void aout_writesymbols(FILE *f)
{
  struct SymbolNode *sym;

  while (sym = (struct SymbolNode *)remhead(&aoutsymlist.l))
    fwritex(f,&sym->s,sizeof(struct nlist32));
}


void aout_writestrings(FILE *f,int be)
{
  if (aoutstrlist.nextoffset > 4) {
    struct StrTabNode *stn;
    uint32_t len;

    write32(be,&len,aoutstrlist.nextoffset);
    fwritex(f,&len,4);
    while (stn = (struct StrTabNode *)remhead(&aoutstrlist.l))
      fwritex(f,stn->str,strlen(stn->str)+1);
  }
}


static uint32_t aoutstd_getrinfo(struct GlobalVars *gv,struct Reloc *rel,
                                bool xtern,const char *sname,uint32_t offs)
/* convert vlink relocation type in standard a.out relocations, */
/* as used by M68k and x86 targets, */
/* return ~0 when this relocation has to be ignored */
{
  int be = fff[gv->dest_format]->endianess;
  struct RelocInsert *ri;
  uint32_t s=4,r=0;
  int b=0;

  if (be < 0)
    be = gv->endianess;

  if (ri = rel->insert) {
    switch (rel->rtype) {
      case R_NONE:
        return ~0;
      case R_ABS:
        b = -1;
        break;
      case R_PC:
        b = RSTDB_pcrel;
        break;
      case R_SD:
        b = RSTDB_baserel;
        break;
    }

    if (rel->rtype == R_AOUT_MOVEI) {
      /* Jaguar RISC MOVEI instruction's swapped words are indicated by a
         set RSTDB_copy bit. Reset reloc type to ABS and size to 32 bits. */
      b = RSTDB_copy;
      s = 2;
      rel->rtype = R_ABS;
      ri->bsiz = 32;
      ri->mask = -1;
    }
    else if (ri->bpos==0 && ri->next==NULL &&
             (ri->mask&makemask(ri->bsiz))==makemask(ri->bsiz)) {
      switch (ri->bsiz) {
        case 8: s=0; break;
        case 16: s=1; break;
        case 32: s=2; break;
      }
    }

    if (b && s<4) {
      if (b > 0)
        writebf32(be,&r,b,1,1);
      writebf32(be,&r,RSTDB_length,RSTDS_length,s);
      writebf32(be,&r,RSTDB_extern,RSTDS_extern,xtern?1:0);
    }
    else {
      /* unsupported relocation type */
      error(32,fff[gv->dest_format]->tname,reloc_name[rel->rtype],
            (int)ri->bpos,(int)ri->bsiz,ri->mask,sname,rel->offset);
    }
  }

  return readbf32(be,&r,RELB_reloc,RELS_reloc);
}


void aoutstd_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a standard a.out relocatable object file */
{
  uint32_t mid = fff[gv->dest_format]->id;
  int be = (int)fff[gv->dest_format]->endianess;
  struct LinkedSection *sections[3];
  uint32_t trsize,drsize;
  unsigned long a = MIN_ALIGNMENT;

  if (be < 0)
    be = gv->endianess;
  aout_initwrite(gv,sections);
  aout_addsymlist(gv,sections,BIND_GLOBAL,0,be);
  aout_addsymlist(gv,sections,BIND_WEAK,0,be);
  aout_addsymlist(gv,sections,BIND_LOCAL,0,be);
  aout_debugsyms(gv,be);
  trsize = aout_addrelocs(gv,sections,0,&treloclist,aoutstd_getrinfo,be);
  drsize = aout_addrelocs(gv,sections,1,&dreloclist,aoutstd_getrinfo,be);

  aout_header(f,OMAGIC,mid,isPIC(sections) ? EX_PIC : 0,
              sections[0] ? sections[0]->size+align(sections[0]->size,a) : 0,
              sections[1] ? sections[1]->size+align(sections[0]->size,a) : 0,
              sections[2] ? sections[2]->size : 0,
              aoutsymlist.nextindex * sizeof(struct nlist32),
              0,trsize,drsize,be);
  aout_writesection(f,sections[0],(uint8_t)a);
  aout_writesection(f,sections[1],(uint8_t)a);
  aout_writerelocs(f,&treloclist);
  aout_writerelocs(f,&dreloclist);
  aout_writesymbols(f);
  aout_writestrings(f,be);
}


void aoutstd_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a standard a.out shared object file */
{
  ierror("aoutstd_writeshared(): Shared object generation has not "
         "yet been implemented");
}


void aoutstd_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a standard a.out paged executable file */
{
  uint32_t mid = fff[gv->dest_format]->id;
  int be = (int)fff[gv->dest_format]->endianess;
  struct LinkedSection *sections[3];

  if (be < 0)
    be = gv->endianess;
  aout_initwrite(gv,sections);
  if (sections[0] == NULL)  /* this requires a .text section! */
    error(97,fff[gv->dest_format]->tname,TEXTNAME);
  aout_addsymlist(gv,sections,BIND_GLOBAL,0,be);
  aout_addsymlist(gv,sections,BIND_WEAK,0,be);
  aout_addsymlist(gv,sections,BIND_LOCAL,0,be);
  aout_debugsyms(gv,be);
  calc_relocs(gv,sections[0]);
  calc_relocs(gv,sections[1]);

  aout_header(f,ZMAGIC,mid,isPIC(sections) ? EX_PIC : 0, /* @@@ DYNAMIC? */
              aout_getpagedsize(gv,sections,0),
              aout_getpagedsize(gv,sections,1),
              aout_getpagedsize(gv,sections,2),
              aoutsymlist.nextindex * sizeof(struct nlist32),
              (uint32_t)entry_address(gv),0,0,be);
  aout_pagedsection(gv,f,sections,0);
  aout_pagedsection(gv,f,sections,1);
  aout_writesymbols(f);
  aout_writestrings(f,be);
}


#endif /* AOUT */
