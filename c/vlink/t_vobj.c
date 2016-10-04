/* $VER: vlink t_vobj.c V0.14d (12.02.14)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2014  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2014 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */

#include "config.h"
#ifdef VOBJ
#define T_VOBJ_C
#include "vlink.h"
#include "vobj.h"


/*
  VOBJ Format (WILL CHANGE!):

  .byte 0x56,0x4f,0x42,0x4a
  .byte flags
    1: BIGENDIAN
    2: LITTLENDIAN
  .number bitsperbyte
  .number bytespertaddr
  .string cpu
  .number nsections [1-based]
  .number nsymbols [1-based]
  
nsymbols
  .string name
  .number type
  .number flags
  .number secindex
  .number val
  .number size

nsections
  .string name
  .string attr
  .number flags
  .number align
  .number size
  .number nrelocs
  .number databytes
  .byte[databytes]

nrelocs [standard|special]
standard
   .number type
   .number byteoffset
   .number bitoffset
   .number size
   .number mask
   .number addend
   .number symbolindex | 0 (sectionbase)

special
    .number type
    .number size
    .byte[size]

.number:[taddr]
    .byte 0--127 [0--127]
    .byte 128-255 [x-0x80 bytes little-endian]

*/

static unsigned long vobj_headersize(struct GlobalVars *);
static int vobjle_identify(char*,uint8_t *,unsigned long,bool);
static int vobjbe_identify(char*,uint8_t *,unsigned long,bool);
static void vobj_readconv(struct GlobalVars *,struct LinkFile *);
static int vobj_targetlink(struct GlobalVars *,struct LinkedSection *,
                              struct Section *);
static void vobj_writeobject(struct GlobalVars *,FILE *);
static void vobj_writeshared(struct GlobalVars *,FILE *);
static void vobj_writeexec(struct GlobalVars *,FILE *);


struct FFFuncs fff_vobj_le = {
  "vobj-le",
  NULL,
  NULL,
  vobj_headersize,
  vobjle_identify,
  vobj_readconv,
  NULL,
  vobj_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  vobj_writeobject,
  vobj_writeshared,
  vobj_writeexec,
  bss_name,sbss_name,
  0,
  0, /* don't care */
  0,
  0,
  RTAB_UNDEF,0,
  _LITTLE_ENDIAN_,
  32
};

struct FFFuncs fff_vobj_be = {
  "vobj-be",
  NULL,
  NULL,
  vobj_headersize,
  vobjbe_identify,
  vobj_readconv,
  NULL,
  vobj_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  vobj_writeobject,
  vobj_writeshared,
  vobj_writeexec,
  bss_name,sbss_name,
  0,
  0, /* don't care */
  0,
  0,
  RTAB_UNDEF,0,
  _BIG_ENDIAN_,
  32
};


static struct ar_info ai;     /* for scanning library archives */
static uint8_t *p;



/*****************************************************************/
/*                           Read VOBJ                           */
/*****************************************************************/

static unsigned long vobj_headersize(struct GlobalVars *gv)
{
  return 0;  /* irrelevant - no write format */
}


static int vobj_identify(char *name,uint8_t *p,unsigned long plen,uint8_t e)
{
  int id = ID_OBJECT;

  if (ar_init(&ai,(char *)p,plen,name)) {
    /* library archive detected, extract 1st archive member */
    id = ID_LIBARCH;
    if (!(ar_extract(&ai))) {
      error(38,name);  /* empty archive ignored */
      return ID_IGNORE;
    }
    p = (uint8_t *)ai.data;
    plen = ai.size;
  }

  if (plen>4 && p[0]==0x56 && p[1]==0x4f && p[2]==0x42 &&
      p[3]==0x4a && p[4]==e) {
    return id;
  }

  return ID_UNKNOWN;
}

static int vobjle_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return vobj_identify(name,p,plen,2);
}

static int vobjbe_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return vobj_identify(name,p,plen,1);
}


static void vobj_check_ar_type(struct FFFuncs *ff,const char *name,uint8_t *p)
/* check all library archive members before conversion */
{
  if (p[0]!=0x56 || p[1]!=0x4f || p[2]!=0x42 || p[3]!=0x4a ||
      p[4]!=(ff->endianess ? 1 : 2))
    error(41,name,ff->tname);
}


static taddr read_number(int is_signed)
{
  int bitcnt;
  taddr val;
  uint8_t n,*q;

  if ((n = *p++) <= 0x7f)
    return (taddr)n;

  val = 0;
  if (n -= 0x80) {
    p += n;
    q = p;
    bitcnt = n << 3;
    while (n--)
      val = (val<<8) | *(--q);
    if (is_signed)
      val = sign_extend(val,bitcnt);
  }
  return val;
}


static void skip_string(void)
{
  while (*p)
    p++;
  p++;
}


static void read_symbol(struct vobj_symbol *vsym)
{
  vsym->name = (char *)p;
  skip_string();
  vsym->type = (int)read_number(0);
  vsym->flags = (int)read_number(0);
  vsym->sec = (int)read_number(0);
  vsym->val = read_number(1);
  vsym->size = (int)read_number(0);
}


static void read_section(struct GlobalVars *gv,struct ObjectUnit *u,
                         uint32_t index,struct vobj_symbol *vsyms,int nsyms)
{
  struct Section *s;
  lword dsize,fsize;
  int nrelocs;
  uint8_t type = ST_DATA;
  uint8_t prot = SP_READ;
  uint8_t flags = 0;
  uint8_t align,*data;
  char *attr;
  char *name = (char *)p;
  struct Reloc *last_reloc;
  int last_sym = -1;
  lword last_offs;
  uint16_t last_bpos = INVALID;

  skip_string();  /* section name */
  for (attr=(char *)p; *attr; attr++) {
    switch (tolower((unsigned char)*attr)) {
      case 'w': prot |= SP_WRITE; break;
      case 'x': prot |= SP_EXEC; break;
      case 'c': type = ST_CODE; break;
      case 'd': type = ST_DATA; break;
      case 'u': type = ST_UDATA; flags |= SF_UNINITIALIZED; break;
      case 'a': flags |= SF_ALLOC;
    }
  }
  skip_string();
  read_number(0);                 /* ignore flags */
  align = (uint8_t)lshiftcnt(read_number(0));
  dsize = read_number(0);         /* total size of section */
  nrelocs = (int)read_number(0);  /* number of relocation entries */
  fsize = read_number(0);         /* size in file, without 0-bytes */

  if (type == ST_UDATA) {
    data = NULL;
  }
  else if (dsize > fsize) {       /* recreate 0-bytes at end of section */
    data = alloczero((size_t)dsize);
    memcpy(data,p,(size_t)fsize);
  }
  else
    data = p;

  /* create and add section */
  p += fsize;
  s = add_section(u,name,data,(unsigned long)dsize,type,flags,prot,align,0);
  s->id = index;

  /* create relocations and unkown symbol references for this section */
  for (last_reloc=NULL,last_offs=-1; nrelocs>0; nrelocs--) {
    struct Reloc *r;
    char *xrefname = NULL;
    lword offs,mask,addend;
    uint16_t bpos,bsiz;
    uint8_t flags;
    int sym_idx;

    /* read one relocation entry */
    type = (uint8_t)read_number(0);
    offs = read_number(0);
    bpos = (uint16_t)read_number(0);
    bsiz = (uint16_t)read_number(0);
    mask = read_number(1);
    addend = read_number(1);
    sym_idx = (int)read_number(0) - 1;  /* symbol index */
    flags = 0;

    if (type>R_NONE && type<=LAST_STANDARD_RELOC &&
        offs>=0 && bsiz<=(sizeof(lword)<<3) &&
        sym_idx>=0 && sym_idx<nsyms) {
      if (vsyms[sym_idx].type == LABSYM) {
        xrefname = NULL;
        index = vsyms[sym_idx].sec;
      }
      else if (vsyms[sym_idx].type == IMPORT) {
        xrefname = vsyms[sym_idx].name;
        if (vsyms[sym_idx].flags & WEAK)
          flags |= RELF_WEAK;  /* undefined weak symbol */
        index = 0;
      }
      else {
        /* VOBJ relocation not supported */
        error(115,getobjname(u),fff[u->lnkfile->format]->tname,
              (int)type,(lword)offs,(int)bpos,(int)bsiz,(lword)mask,
              vsyms[sym_idx].name,(int)vsyms[sym_idx].type);
      }

      if (sym_idx==last_sym && offs==last_offs && bpos==last_bpos &&
          last_reloc!=NULL) {
        r = last_reloc;
      }
      else {
        r = newreloc(gv,s,xrefname,NULL,index,(unsigned long)offs,type,addend);
        r->flags |= flags;
        last_reloc = r;
        last_offs = offs;
        last_bpos = bpos;
        last_sym = sym_idx;
      }

      addreloc(s,r,bpos,bsiz,mask);

      /* make sure that section reflects the addend for other formats */
      writesection(gv,data+(uint32_t)offs,r,addend);
    }

    else if (type != R_NONE) {
      /* VOBJ relocation not supported */
      error(115,getobjname(u),fff[u->lnkfile->format]->tname,
            (int)type,(lword)offs,(int)bpos,(int)bsiz,(lword)mask,
            (sym_idx>=0&&sym_idx<nsyms) ? vsyms[sym_idx].name : "?",
            (sym_idx>=0&&sym_idx<nsyms) ? (int)vsyms[sym_idx].type : 0);
    }
  }
}


static void vobj_read(struct GlobalVars *gv,struct LinkFile *lf,uint8_t *data)
{
  struct ObjectUnit *u;
  int bpb,bpt,nsecs,nsyms,i;
  struct vobj_symbol *vsymbols = NULL;

  if (lf->type == ID_LIBARCH) {  /* check ar-member for correct format */
    vobj_check_ar_type(fff[lf->format],lf->pathname,data);
  }
  p = data + 5;  /* skip ID and endianess */
  bpb = (int)read_number(0);  /* bits per byte */
  if (bpb != 8) {
    /* bits per byte are not supported */
    error(113,lf->pathname,fff[lf->format]->tname,bpb);
  }
  bpt = (int)read_number(0);  /* bytes per taddr */
  if (bpt > sizeof(taddr)) {
    /* n bytes per target-address are not supported */
    error(114,lf->pathname,fff[lf->format]->tname,bpt);
  }
  skip_string();  /* skip cpu-string */

  u = create_objunit(gv,lf,lf->objname);
  nsecs = (int)read_number(0);  /* number of sections */
  nsyms = (int)read_number(0);  /* number of symbols */

  if (nsyms) {
    vsymbols = alloc(nsyms * sizeof(struct vobj_symbol));
    for (i=0; i<nsyms; i++)
      read_symbol(&vsymbols[i]);
  }

  for (i=1; i<=nsecs; i++)
    read_section(gv,u,(uint32_t)i,vsymbols,nsyms);

  /* add relocatable and absolute symbols, ignore unknown symbol-refs */
  for (i=0; i<nsyms; i++) {
    struct vobj_symbol *vs = &vsymbols[i];
    struct Section *s = NULL;
    uint8_t type,bind,info;

    if (vs->flags & WEAK)
      bind = SYMB_WEAK;
    else if (vs->flags & EXPORT)
      bind = SYMB_GLOBAL;
    else
      bind = SYMB_LOCAL;

    if (vs->flags & COMMON) {
      type = SYM_COMMON;
      bind = SYMB_GLOBAL;  /* common symbols are always global */
      s = common_section(gv,u);
    }
    else if (vs->type == EXPRESSION) {
      type = SYM_ABS;
      s = abs_section(u);
    }
    else if (vs->type == LABSYM) {
      type = SYM_RELOC;
      if (!(s = find_sect_id(u,vs->sec))) {
        /* a section with this index doesn't exist! */
        error(53,lf->pathname,vs->name,lf->objname,vs->sec);
      }
    }
    else if (vs->type == IMPORT) {
      type = 0;  /* ignore unknown symbols */
    }
    else {
      /* illegal symbol type */
      error(116,getobjname(u),fff[lf->format]->tname,
            vs->type,vs->name,lf->objname);
      type = 0;
    }

    switch (TYPE(vs)) {
      case TYPE_UNKNOWN: info = SYMI_NOTYPE; break;
      case TYPE_OBJECT: info = SYMI_OBJECT; break;
      case TYPE_FUNCTION: info = SYMI_FUNC; break;
      case TYPE_SECTION: type = 0; break;  /* ignore SECTION symbols */
      case TYPE_FILE: info = SYMI_FILE; break;
      default:
        error(54,lf->pathname,TYPE(vs),vs->name,lf->objname);
        type = 0;
        break;
    }

    if (type) {
      if (bind == SYMB_LOCAL)
        addlocsymbol(gv,s,vs->name,NULL,(lword)vs->val,type,0,info,vs->size);
      else
        addsymbol(gv,s,vs->name,NULL,(lword)vs->val,
                  type,0,info,bind,vs->size,TRUE);
    }
  }
  if (nsyms)
    free(vsymbols);

  add_objunit(gv,u,TRUE);  /* add object unit and fix relocations */
}


static void vobj_readconv(struct GlobalVars *gv,struct LinkFile *lf)
{
  if (lf->type == ID_LIBARCH) {
    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        vobj_read(gv,lf,(uint8_t *)ai.data);
      }
    }
    else
      ierror("vobj_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    vobj_read(gv,lf,lf->data);
  }
}


static int vobj_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                             struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  ierror("vobj_targetlink(): Impossible to link vobjects");
  return (0);
}



/*****************************************************************/
/*                          Write VOBJ                           */
/*****************************************************************/


static void vobj_writeexec(struct GlobalVars *gv,FILE *f)
{
  error(94);  /* Target file format doesn't support executable files */
}


static void vobj_writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void vobj_writeobject(struct GlobalVars *gv,FILE *f)
{
  error(62);  /* Target file format doesn't support relocatable objects */
}


#endif
