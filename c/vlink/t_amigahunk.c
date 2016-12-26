/* $VER: vlink t_amigahunk.c V0.15a (04.02.16)
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
#if defined(ADOS) || defined(EHF)
#define T_AMIGAOS_C
#include "vlink.h"
#include "amigahunks.h"


static int ados_identify(char*,uint8_t *,unsigned long,bool);
static int ehf_identify(char *,uint8_t *,unsigned long,bool);
static int identify(char *,uint8_t *,unsigned long,bool);
static void readconv(struct GlobalVars *,struct LinkFile *);
static uint8_t cmpsecflags(struct LinkedSection *,struct Section *);
static int targetlink(struct GlobalVars *,struct LinkedSection *,
                      struct Section *);
static struct Symbol *ados_lnksym(struct GlobalVars *,struct Section *,
                                  struct Reloc *);
static void ados_setlnksym(struct GlobalVars *,struct Symbol *);
static struct Symbol *ehf_findsymbol(struct GlobalVars *,
                                     struct Section *,const char *);
static struct Symbol *ehf_lnksym(struct GlobalVars *,struct Section *,
                                  struct Reloc *);
static void ehf_setlnksym(struct GlobalVars *,struct Symbol *);
static unsigned long headersize(struct GlobalVars *);
static void ados_writeobject(struct GlobalVars *,FILE *);
static void ehf_writeobject(struct GlobalVars *,FILE *);
static void writeshared(struct GlobalVars *,FILE *);
static void writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_amigahunk = {
  "amigahunk",
  NULL,
  NULL,
  headersize,
  ados_identify,
  readconv,
  cmpsecflags,
  targetlink,
  ehf_findsymbol,
  ados_lnksym,
  ados_setlnksym,
  NULL,NULL,NULL,
  ados_writeobject,
  writeshared,
  writeexec,
  NULL,NULL,
  0,
  0x7ffe,
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD|RTAB_SHORTOFF,
  _BIG_ENDIAN_,
  32,
  FFF_RELOCATABLE
};

struct FFFuncs fff_ehf = {
  "amigaehf",
  NULL,
  NULL,
  headersize,
  ehf_identify,
  readconv,
  cmpsecflags,
  targetlink,
  ehf_findsymbol,
  ehf_lnksym,
  ehf_setlnksym,
  NULL,NULL,NULL,
  ehf_writeobject,
  writeshared,
  writeexec,
  NULL,NULL,
  0,
  0x7ffe,
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD|RTAB_SHORTOFF,
  _BIG_ENDIAN_,
  32,
  FFF_RELOCATABLE
};

/* Automagically create symbols in .tocd, which start with the */
/* following letters: */
static char ehf_addrsym[] = "@_";

static char tocd_name[] = ".tocd";

static char *ados_symnames[] = {
  /* PhxAss */     "_DATA_BAS_","_DATA_LEN_","_BSS_LEN_",
  /* SAS/StormC */ "_LinkerDB","__BSSBAS","__BSSLEN","___ctors","___dtors",
  /* DICE-C */     "__DATA_BAS","__DATA_LEN","__BSS_LEN","__RESIDENT",
  /* GNU-C */      "___machtype","___text_size","___data_size","___bss_size",
  /* ELF */        "_SDA_BASE_","_SDA2_BASE_"
};
#define PHXDB 0
#define PHXDL 1
#define PHXBL 2
#define SASPT 3
#define SASBB 4
#define SASBL 5
#define SASCT 6
#define SASDT 7
#define DICDB 8
#define DICDL 9
#define DICBL 10
#define DICRS 11
#define GNUMT 12
#define GNUTL 13
#define GNUDL 14
#define GNUBL 15
#define ELFSD 16
#define ELFS2 17
#define LAST_LNKSYM ELFS2

static bool exthunk,symhunk;



/*****************************************************************/
/*                      Read ADOS / EHF                          */
/*****************************************************************/


static int ados_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  int ff;

  if ((ff = identify(name,p,plen,lib)) >= 0)
    return ff;
  return ID_UNKNOWN;  /* ehf */
}


static int ehf_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  int ff;

  if ((ff = identify(name,p,plen,lib)) < 0)
    return -ff;
  return ff;  /* ados is a subset of ehf */
}


static void init_hunkinfo(struct HunkInfo *hi,const char *name,uint8_t *p,
                          unsigned long plen)
{
  hi->hunkptr = hi->hunkbase = p;
  hi->hunkcnt = (long)plen;
  hi->filename = name;
  hi->libbase = NULL;
  hi->exec = read32be(p) == HUNK_HEADER;  /* executable file? */
}


static void movehunkptr32(struct HunkInfo *hi,uint32_t n)
/* skip n 32-bit words */
{
  long offset = (long)n << 2;

  if ((hi->hunkcnt -= offset) < 0)
    error(13,hi->filename);  /* File format corrupted */
  hi->hunkptr += offset;
}


static void movehunkptr16(struct HunkInfo *hi,uint32_t n)
/* skip n 16-bit words */
{
  long offset = (long)n << 1;

  if ((hi->hunkcnt -= offset) < 0)
    error(13,hi->filename);  /* File format corrupted */
  hi->hunkptr += offset;
}


static void alignhunkptr(struct HunkInfo *hi)
/* make hunk pointer 32-bit aligned */
{
  if ((hi->hunkptr - hi->hunkbase) & 2)
    movehunkptr16(hi,1);
}


static uint32_t testword32(struct HunkInfo *hi)
/* try to read next 32-bit word - return 0, if end of file reached */
{
#if 0 /* @@@ this doesn't work??? check later why... */
  if (hi->hunkcnt >= sizeof(uint32_t)) {
    uint32_t w = read32be(hi->hunkptr);

    return w ? w : INVALID;  /* provoke an error when 0-word was read */
  }
#else
  if (hi->hunkcnt >= sizeof(uint32_t))
    return read32be(hi->hunkptr);
#endif
  return 0;
}


static uint32_t nextword32(struct HunkInfo *hi)
/* read next 32-bit word */
{
  uint32_t w;

  if ((hi->hunkcnt -= sizeof(uint32_t)) < 0)
    error(13,hi->filename);  /* File format corrupted */
  w = read32be(hi->hunkptr);
  hi->hunkptr += sizeof(uint32_t);
  return w;
}


static uint16_t nextword16(struct HunkInfo *hi)
/* read next 16-bit word */
{
  uint16_t w;

  if ((hi->hunkcnt -= sizeof(uint16_t)) < 0)
    error(13,hi->filename);  /* File format corrupted */
  w = read16be(hi->hunkptr);
  hi->hunkptr += sizeof(uint16_t);
  return w;
}


static uint32_t skiphunk(struct HunkInfo *hi)
/* Skip the hunk where hunkptr points to. */
/* Return first word of next hunk. */
{
  uint32_t type,n;

  n = read32be(hi->hunkptr);
  type = n & 0xffff;

  if ((type==HUNK_PPC_CODE || (type>=HUNK_CODE && type<=HUNK_BSS)) &&
      (n & HUNKF_MEMTYPE) == (HUNKF_FAST|HUNKF_CHIP))
    movehunkptr32(hi,1);  /* skip memory attributes @@@ inofficial! */

  switch (type) {
    case HUNK_UNIT:
    case HUNK_NAME:
    case HUNK_CODE:
    case HUNK_DATA:
    case HUNK_DEBUG:
    case HUNK_LIB:
    case HUNK_INDEX:
    case HUNK_PPC_CODE: /* EHF */
      movehunkptr32(hi,read32be(hi->hunkptr+4)+2);
      break;

    case HUNK_BSS:
      movehunkptr32(hi,2);  /* skip size specifier */
      break;

    case HUNK_ABSRELOC32:
    case HUNK_RELRELOC16:
    case HUNK_RELRELOC8:
    case HUNK_RELRELOC32:
    case HUNK_ABSRELOC16:
    case HUNK_DREL32:
    case HUNK_DREL16:
    case HUNK_DREL8:
    case HUNK_RELRELOC26: /* EHF */
      if (!(type==HUNK_DREL32 && hi->exec)) {
        nextword32(hi);
        while (n = nextword32(hi))
          movehunkptr32(hi,n+1);
        break;
      }
      /* else, fall through to HUNK_RELOC32SHORT */

    case HUNK_RELOC32SHORT:
      nextword32(hi);
      while (n = (uint32_t)nextword16(hi))
        movehunkptr16(hi,n+1);
      alignhunkptr(hi);
      break;

    case HUNK_EXT:
    case HUNK_SYMBOL:
      nextword32(hi);
      while (n = nextword32(hi)) {
        if (n & 0x80000000) {  /* external reference */
          movehunkptr32(hi,n & 0xffffff);
          if ((n>>24)==EXT_ABSCOMMON || (n>>24)==EXT_RELCOMMON ||
              ((n>>24)>=EXT_DEXT32COMMON && (n>>24)<=EXT_DEXT8COMMON)) {
            nextword32(hi);  /* size of common area */
          }
          movehunkptr32(hi,nextword32(hi));  /* skip reference offsets */
        }
        else
          movehunkptr32(hi,(n&0xffffff)+1);  /* skip xdef-value */
      }
      break;

    case HUNK_HEADER:
      nextword32(hi);
      movehunkptr32(hi,nextword32(hi)+2);
      n = nextword32(hi);  /* first root hunk index */
      n = nextword32(hi) - n + 1;  /* number of size specifiers */
      while (n--) {
        if ((nextword32(hi) & HUNKF_MEMTYPE) == (HUNKF_FAST|HUNKF_CHIP))
          nextword32(hi);
      }
      break;

    case HUNK_OVERLAY:
      movehunkptr32(hi,read32be(hi->hunkptr+4)+3); /* @@@ I'm not sure...*/
      break;

    case HUNK_END:
    case HUNK_BREAK:
      nextword32(hi);
      break;

    default:
      error(13,hi->filename);  /* File format corrupted */
      break;
  }

  /* return next 32-bit word */
  return testword32(hi);
}


static uint32_t readindex(struct HunkInfo *hi)
{
  uint16_t w;

  if ((hi->indexcnt -= sizeof(uint16_t)) < 0)
    error(13,hi->filename);  /* File format corrupted */
  w = read16be(hi->indexptr);
  hi->indexptr += sizeof(uint16_t);
  return w;
}


static void skipindex(struct HunkInfo *hi,uint32_t off)
{
  if ((hi->indexcnt -= off) < 0)
    error(13,hi->filename);  /* File format corrupted */
  hi->indexptr += off;
}


const char *readstrpool(struct HunkInfo *hi)
{
  return allocstring(hi->indexbase + 2 + readindex(hi));
}


static int identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* Identify AmigaDOS or extended hunk format */
{
  uint32_t w = read32be(p);
  struct HunkInfo hi;
  int type;

  if (w == HUNK_HEADER) {
    error(12,name);  /* file is already an executable */
    return ID_EXECUTABLE;  /* EHF-executables don't exist! */
  }
  else if (w!=HUNK_UNIT && w!=HUNK_LIB)
    return ID_UNKNOWN;

  /* @@@ EHF will never be in HUNK_LIB format, because HUNK_PPC_CODE */
  /* (0x4e9) conflicts with HUNK_CODE|(MEMB_CHIP<<14) = 0x7e9. @@@   */
  if (w == HUNK_LIB)
    return ID_LIBARCH;  /* SAS/C-style library */

  if (!lib) {
    /* Check, by comparing the suffix with ".LIB", if the units */
    /* of this object file have to be handled as part of an object */
    /* or library archive.  Yes, this is the only way... */
    int l;

    type = ID_OBJECT;
    if ((l = strlen(name)-4) > 0) {
      if (name[l]=='.' &&
          toupper((unsigned char)name[l+1])=='L' &&
          toupper((unsigned char)name[l+2])=='I' &&
          toupper((unsigned char)name[l+3])=='B')
        type = ID_LIBARCH;
    }
  }
  else
    type = ID_LIBARCH;  /* given with -l, will be regarded as a library */

  /* Now check if any unit contains EHF hunks */
  init_hunkinfo(&hi,name,p,plen);
  while (w = skiphunk(&hi)) {
    if (w & 0xffff == HUNK_PPC_CODE)
      return -type;  /* it's an EHF object/library, containing PPC code */
  }
  return type;
}


static bool addlongrelocs(struct GlobalVars *gv,struct HunkInfo *hi,
                          struct Section *s,uint8_t type,uint16_t size)
/* convert an amigahunk/ehf relocation hunk into an internal Reloc node */
{
  uint32_t n,id,offs;
  uint16_t pos = 0;
  lword mask = -1;
  struct Reloc *r;

  if (size == 24) {  /* EHF/PPC 26-bit branch */
    pos = 6;
    mask = ~3;  /* 0xfffffffc */
  }
  if (s) {
    nextword32(hi);
    while (n = nextword32(hi)) {
      id = nextword32(hi);  /* add base addr. of section with this index */
      while (n--) {
        offs = nextword32(hi);
        r = newreloc(gv,s,NULL,NULL,id,offs,type,
                     readsection(gv,type,s->data+offs,pos,size,mask));
        addreloc(s,r,pos,size,mask);
      }
    }
    return TRUE;
  }
  return FALSE;
}


static bool addshortrelocs32(struct GlobalVars *gv,struct HunkInfo *hi,
                             struct Section *s)
/* convert an amigahunk/ehf abs-reloc32 hunk into an internal Reloc node */
{
  uint32_t n,id,offs;
  struct Reloc *r;

  if (s) {
    nextword32(hi);
    while (n = (uint32_t)nextword16(hi)) {
      id = (uint32_t)nextword16(hi); /* add base addr. of sec. with this idx. */
      while (n--) {
        offs = (uint32_t)nextword16(hi);
        r = newreloc(gv,s,NULL,NULL,id,offs,R_ABS,
                     readsection(gv,R_ABS,s->data+offs,0,32,-1));
        addreloc(s,r,0,32,-1);  /* standard 32-bit reloc */
      }
    }
    alignhunkptr(hi);
    return TRUE;
  }
  return FALSE;
}


static char *gethunkname(struct HunkInfo *hi)
/* read 32-bit aligned name, the most significant byte of the */
/* length specifier is ignored (for HUNK_EXT names, for example) */
{
  uint32_t n;
  char *s=NULL;

  if (n = nextword32(hi) & 0xffffff) {  /* name given? */
    s = alloczero((n+1)<<2);
    strncpy(s,(char *)hi->hunkptr,n<<2);
    movehunkptr32(hi,n);
  }
  return s;
}


static bool create_debuginfo(struct GlobalVars *gv,struct HunkInfo *hi,
                             struct Section *s)
/* read amigahunk/ehf debugging informations */
{
  int32_t len;
  uint32_t base;

  if (s) {
    nextword32(hi);
    if ((len = nextword32(hi)) >= 3) {
      base = nextword32(hi);
      switch (nextword32(hi)) {

        case 0x4c494e45:  /* "LINE" - line/offset table and source name */
          {
            struct LineDebug *ldb;
            uint32_t *lptr,*optr;

            ldb = (struct LineDebug *)addtargetext(s,TGEXT_AMIGAOS,
                                                   SUBID_LINE,0,
                                                   sizeof(struct LineDebug));
            len -= testword32(hi) + 3; /* number of longwords for file name */
            ldb->source_name = gethunkname(hi);
            ldb->num_entries = len >> 1;
            lptr = ldb->lines = alloc(ldb->num_entries * sizeof(uint32_t));
            optr = ldb->offsets = alloc(ldb->num_entries * sizeof(uint32_t));
            while (len > 0) {
              *lptr++ = nextword32(hi);
              *optr++ = nextword32(hi) + base;
              len -= 2;
            }
          }
          break;

        default:
          movehunkptr32(hi,len-2);  /* ignore unknown debug hunk */
          break;
      }
    }
    else /* too short... ignore */
      movehunkptr32(hi,len);
    return TRUE;
  }
  return FALSE;
}


static void create_xdef(struct GlobalVars *gv,struct Section *s,
                        const char *name,int32_t val,uint8_t type,uint8_t bind)
/* add new symbol to the symbols list of the current object unit */
{
  struct Symbol *sym;
  uint32_t size = 0;

  if (type == SYM_COMMON) {
    /* Oh, a common symbol? A rare guest! :) */
    size = val;  /* its size was stored in val */
    val = 4;     /* how about a 32-bit alignment? */
    s = common_section(gv,s->obj);
  }

  if (sym = addsymbol(gv,s,name,NULL,(lword)val,
                      type,0,SYMI_NOTYPE,bind,size,FALSE)) {
    /* Symbol already defined. If defined globally, ignore it. */
    /* Otherwise, change into a global definition. */
    if (sym->bind != SYMB_GLOBAL) {
      if (bind == SYMB_GLOBAL) {
        sym->value = (lword)val;  /* redefine as global (xdef) symbol */
        sym->relsect = s;
        sym->type = type;
        sym->flags = 0;
        sym->info = SYMI_NOTYPE;
        sym->bind = SYMB_GLOBAL;
        sym->size = size;
        addglobsym(gv,sym);
      }
    }
  }
}


static void create_xrefs(struct GlobalVars *gv,struct HunkInfo *hi,
                         struct Section *s,char *name,
                         uint8_t rtype,uint16_t size)
/* add new unresolved symbol reference to the current section */
{
  uint32_t n = nextword32(hi);  /* number of references */
  uint32_t offs;
  uint16_t pos = 0;
  lword mask = -1;
  struct Reloc *r;

  if (size == 24) {  /* EHF/PPC 26-bit branch */
    pos = 6;
    mask = ~3;  /* 0xfffffffc */
  }
  while (n--) {
    offs = nextword32(hi);
    r = newreloc(gv,s,name,NULL,0,offs,rtype,
                 readsection(gv,rtype,s->data+offs,pos,size,mask));
    addreloc(s,r,pos,size,mask);
  }
}


static void readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read AmigaDOS/EHF hunks and symbols */
{
  struct HunkInfo hi;
  uint32_t w;
  struct ObjectUnit *u=NULL;
  struct Section *s=NULL;
  struct SecAttrOvr *sao;
  char *secname=NULL;
  uint8_t *headerattr=NULL;
  uint16_t hunksleft;
  bool indexhunk=FALSE;
  uint32_t index=0;

  init_hunkinfo(&hi,lf->filename,lf->data,lf->length);

  while (w = testword32(&hi)) {
    switch (w & ~HUNKF_MEMTYPE) {

      case HUNK_HEADER:
        /* header must be at the beginning of the file */
        if (hi.hunkptr == hi.hunkbase) {
          if (!s) {
            uint32_t n;
            add_objunit(gv,u,TRUE); /* add last one to glob. ObjUnit list */
            index = 0;
            create_objunit(gv,lf,lf->filename);
            u = NULL;
            nextword32(&hi);
            n = nextword32(&hi);
            movehunkptr32(&hi,n?n+2:1);
            w = nextword32(&hi);
            n = nextword32(&hi) - w + 1;  /* number of size specifiers */
            headerattr = hi.hunkptr;  /* remember section attributes */
            while (n--) {
              if ((nextword32(&hi) & HUNKF_MEMTYPE) == (HUNKF_FAST|HUNKF_CHIP))
                nextword32(&hi);
            }
          }
          else
            /* Unexpected end of section */
            error(15,lf->pathname,s->name,u->objname);
        }
        else
          /* header appeared twice */
          error(16,lf->pathname,"HUNK_HEADER",lf->filename);
        break;

      case HUNK_UNIT:  /* a new ObjectUnit */
        if (!s) {
          char *uname;
          nextword32(&hi);
          add_objunit(gv,u,TRUE); /* add last one to glob. ObjUnit list */
          index = 0;
          uname = gethunkname(&hi);
          u = create_objunit(gv,lf,uname);
        }
        else
          /* Unexpected end of section */
          error(15,lf->pathname,s->name,u->objname);
        break;

      case HUNK_LIB:  /* indexed library */
          if (s != NULL)
            error(15,lf->pathname,s->name,u->objname);
          nextword32(&hi);
          add_objunit(gv,u,TRUE); /* add last one to glob. ObjUnit list */

          /* Remember start of hunk definitions in HUNK_LIB and then
             skip this hunk completely. A HUNK_INDEX should follow. */
          w = nextword32(&hi);
          hi.libbase = hi.hunkptr;
          movehunkptr32(&hi,w);
          if (nextword32(&hi) != HUNK_INDEX)
            error(23,lf->pathname,"HUNK_INDEX");

          /* prepare to parse the first unit from the index */
          hi.indexcnt = nextword32(&hi) << 2;
          hi.indexptr = hi.indexbase = hi.hunkptr;
          hi.savedhunkcnt = hi.hunkcnt + hi.indexcnt;
          skipindex(&hi,readindex(&hi));
          indexhunk = TRUE;
          hunksleft = 0;
          break;

      case HUNK_INDEX:
          error(17,lf->pathname,"HUNK_INDEX",u ? u->objname : lf->filename);
          break;

      case HUNK_NAME:  /* name of a section */
        if (u && !s) {
          nextword32(&hi);
          secname = gethunkname(&hi);
        }
        else
          /* misplaced hunk */
          error(17,lf->pathname,"HUNK_NAME",u?u->objname:lf->filename);
        break;

      case HUNK_CODE:
      case HUNK_PPC_CODE:
      case HUNK_DATA:
      case HUNK_BSS:
        if (u && !s) {  /* a new Section */
          uint32_t s_attr,s_size;
          nextword32(&hi);

          /* determine section's memory attributes */
          if (headerattr) {
            /* from an executable file */
            s_attr = (read32be(headerattr)>>29) & (MEMF_FAST|MEMF_CHIP);
            headerattr += 4;
            if (s_attr == (MEMF_FAST|MEMF_CHIP)) {
              /* extended memory attributes in next word */
              s_attr = read32be(headerattr);
              headerattr += 4;
            }
          }
          else {
            /* from an object file */
            s_attr = (w>>29) & (MEMF_FAST|MEMF_CHIP);
            if (s_attr == (MEMF_FAST|MEMF_CHIP))
              s_attr = nextword32(&hi);  /* @@@ this seems inofficial! */
          }

          if (gv->fix_unnamed==TRUE &&
              (secname==NULL || (secname!=NULL && *secname=='\0'))) {
            /* assign a name according to the section's type */
            switch (w & 0xffff) {
              case HUNK_PPC_CODE:
              case HUNK_CODE:
                secname = ".text";
                break;
              case HUNK_DATA:
                secname = ".data";
                break;
              case HUNK_BSS:
                secname = ".bss";
                break;
            }
          }
          /* Sections of an executable should never be joined, or */
          /* dangerous things will happen. */
          if (!secname && hi.exec) {
            secname = alloc(10);
            sprintf(secname,"S%08lx",(unsigned long)hi.hunkptr);
          }

          /* create new section node */
          s_size = nextword32(&hi) & ~HUNKF_MEMTYPE;
          s = create_section(u,secname,
                             (w&0xffff)!=HUNK_BSS ? hi.hunkptr : NULL,
                             (unsigned long)s_size<<2);
          s->flags = SF_ALLOC;
          s->alignment = gv->min_alignment>2 ? gv->min_alignment : 2;
          if (sao = getsecattrovr(gv,secname,SAO_MEMFLAGS))
            s->memattr = sao->memflags;
          else
            s->memattr = s_attr;
          s->id = index++;
          switch (w & 0xffff) {
            case HUNK_PPC_CODE:
              s->flags |= SF_EHFPPC;  /* section contains PowerPC code */
            case HUNK_CODE:
              s->type = ST_CODE;
              /* @@@@ amigahunk/ehf code is always writeable ??? */
              s->protection = SP_READ | /*SP_WRITE |*/ SP_EXEC;
              break;
            case HUNK_DATA:
              s->type = ST_DATA;
              s->protection = SP_READ | SP_WRITE;
              break;
            case HUNK_BSS:
              s->flags |= SF_UNINITIALIZED;
              s->data = NULL;
              s->type = ST_UDATA;
              s->protection = SP_READ | SP_WRITE;
              break;
          }
          if (!(s->flags & SF_UNINITIALIZED))
            movehunkptr32(&hi,s_size);  /* skip section's contents */
        }
        else
          /* Section appeared twice */
          error(16,lf->pathname,"Section",u?u->objname:lf->filename);
        break;

      case HUNK_ABSRELOC32:
        if (!addlongrelocs(gv,&hi,s,R_ABS,32))
          error(17,lf->pathname,"HUNK_ABSRELOC32",u?u->objname:lf->filename);
        break;

      case HUNK_RELOC32SHORT:
        if (!addshortrelocs32(gv,&hi,s))
          error(17,lf->pathname,"HUNK_RELOC32SHORT",u?u->objname:lf->filename);
        break;

      case HUNK_RELRELOC16:
        if (!addlongrelocs(gv,&hi,s,R_PC,16))
          error(17,lf->pathname,"HUNK_RELRELOC16",u?u->objname:lf->filename);
        break;

      case HUNK_RELRELOC8:
        if (!addlongrelocs(gv,&hi,s,R_PC,8))
          error(17,lf->pathname,"HUNK_RELRELOC8",u?u->objname:lf->filename);
        break;

      case HUNK_RELRELOC32:
        if (!addlongrelocs(gv,&hi,s,R_PC,32))
          error(17,lf->pathname,"HUNK_RELRELOC32",u?u->objname:lf->filename);
        break;

      case HUNK_ABSRELOC16:
        if (!addlongrelocs(gv,&hi,s,R_ABS,16))
          error(17,lf->pathname,"HUNK_ABSRELOC16",u?u->objname:lf->filename);
        break;

      case HUNK_DREL32:
        /* This hunk block has a double meaning. Before Amiga OS 3.0 */
        /* it was often used as RELOC32SHORT, but will appear in */
        /* executables only. */
        if (hi.exec) {
          if (!addshortrelocs32(gv,&hi,s))
            error(17,lf->pathname,"HUNK_RELOC32SHORT",
                  u?u->objname:lf->filename);
        }
        else {
          if (!addlongrelocs(gv,&hi,s,R_SD,32))
            error(17,lf->pathname,"HUNK_DREL32",u?u->objname:lf->filename);
        }
        break;

      case HUNK_DREL16:
        if (!addlongrelocs(gv,&hi,s,R_SD,16))
          error(17,lf->pathname,"HUNK_DREL16",u?u->objname:lf->filename);
        break;

      case HUNK_DREL8:
        if (!addlongrelocs(gv,&hi,s,R_SD,8))
          error(17,lf->pathname,"HUNK_DREL8",u?u->objname:lf->filename);
        break;

      case HUNK_RELRELOC26: /* EHF */
        if (!addlongrelocs(gv,&hi,s,R_PC,24))
          error(17,lf->pathname,"HUNK_RELRELOC26",u?u->objname:lf->filename);
        break;

      case HUNK_EXT:  /* external definitions and references */
      case HUNK_SYMBOL:
        if (s) {
          uint32_t xtype;
          char *xname;

          nextword32(&hi);
          while (xtype = testword32(&hi)) {
            xname = gethunkname(&hi);
            switch (xtype >>= 24) {

              /* Symbol Definitions */
              case EXT_SYMB:  /* local symbol definition (for debugging) */
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_RELOC,SYMB_LOCAL);
                break;
              case EXT_DEF:  /* global addr. symbol def. (requires reloc) */
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_RELOC,SYMB_GLOBAL);
                break;
              case EXT_ABS:  /* global def. of absolute symbol */
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_ABS,SYMB_GLOBAL);
                break;
              case EXT_RES:  /* unsupported type, invalid since OS2.0 */
                error(18,lf->pathname,xname,u->objname,EXT_RES);
                break;

              /* Unresolved Symbol References */
              case EXT_ABSREF32:
                create_xrefs(gv,&hi,s,xname,R_ABS,32);
                break;
              case EXT_ABSREF16:
                create_xrefs(gv,&hi,s,xname,R_ABS,16);
                break;
              case EXT_ABSREF8:
                create_xrefs(gv,&hi,s,xname,R_ABS,8);
                break;
              case EXT_RELREF32:
                create_xrefs(gv,&hi,s,xname,R_PC,32);
                break;
              case EXT_RELREF26: /* EHF */
                create_xrefs(gv,&hi,s,xname,R_PC,24);
                break;
              case EXT_RELREF16:
                create_xrefs(gv,&hi,s,xname,R_PC,16);
                break;
              case EXT_RELREF8:
                create_xrefs(gv,&hi,s,xname,R_PC,8);
                break;
              case EXT_DEXT32:
                create_xrefs(gv,&hi,s,xname,R_SD,32);
                break;
              case EXT_DEXT16:
                create_xrefs(gv,&hi,s,xname,R_SD,16);
                break;
              case EXT_DEXT8:
                create_xrefs(gv,&hi,s,xname,R_SD,8);
                break;

              case EXT_ABSCOMMON:
                /* ABSCOMMON was never used and only supported */
                /* by the VERY old ALink linker on AmigaOS. */
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_COMMON,SYMB_GLOBAL);
                create_xrefs(gv,&hi,s,xname,R_ABS,32);
                break;
               case EXT_RELCOMMON:
                /* RELCOMMON was introduced in OS3.1. */
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_COMMON,SYMB_GLOBAL);
                create_xrefs(gv,&hi,s,xname,R_PC,32);
                break;

              /* The following are INOFFICIAL base-relative */
              /* common symbol references, created for vbcc */
              case EXT_DEXT32COMMON:
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_COMMON,SYMB_GLOBAL);
                create_xrefs(gv,&hi,s,xname,R_SD,32);
                break;
              case EXT_DEXT16COMMON:
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_COMMON,SYMB_GLOBAL);
                create_xrefs(gv,&hi,s,xname,R_SD,16);
                break;
              case EXT_DEXT8COMMON:
                create_xdef(gv,s,xname,(int32_t)nextword32(&hi),
                            SYM_COMMON,SYMB_GLOBAL);
                create_xrefs(gv,&hi,s,xname,R_SD,8);
                break;

              default:  /* unsupported HUNK_EXT sub type */
                if (xtype & 0x80000000)
                  error(20,lf->pathname,xname,u->objname,xtype>>24);
                else
                  error(18,lf->pathname,xname,u->objname,xtype>>24);
            }
          }
          nextword32(&hi);
        }
        else
          error(17,lf->pathname,(w==HUNK_EXT) ? "HUNK_EXT" : "HUNK_SYMBOL",
                u ? u->objname : lf->filename);
        break;

      case HUNK_DEBUG:
        if (!create_debuginfo(gv,&hi,s))
          error(17,lf->pathname,"HUNK_DEBUG",u?u->objname:lf->filename);
        break;

      case HUNK_OVERLAY:
      case HUNK_BREAK:
        ierror("readconv(): HUNK_OVERLAY/BREAK not yet supported");
        break;

      case HUNK_END:
        nextword32(&hi);
        if (s) {
          addtail(&u->sections,&s->n);  /* add Section to ObjectUnit */
          indexhunk = hi.libbase != NULL;  /* next unit in HUNK_INDEX */
          if (!indexhunk) {
            s = NULL;
            secname = NULL;
          }
        }
        else
          error(17,lf->pathname,"HUNK_END",u ? u->objname : lf->filename);
        break;

      default:
        error(13,lf->pathname);  /* File format corrupted */
        break;
    }

    if (indexhunk) {
      if (hi.indexcnt > 2) {
        if (u!=NULL && s!=NULL && hunksleft && secname!=NULL) {
          /* add external definitions for last section */
          const char *xname;
          uint32_t xval;
          int xtype;

          w = readindex(&hi);
          skipindex(&hi,w<<1);  /* ignore external references */

          w = readindex(&hi);
          while (w--) {
            xname = readstrpool(&hi);
            xval = readindex(&hi);
            xtype = (int)readindex(&hi);
            if ((xtype&0xbf) == EXT_ABS) {
              xval |= (xtype&0xff00) << 8;
              if (xtype & 0x40)
                xval |= 0xff000000;
            }
            else if (xtype != EXT_DEF)
              error(18,lf->pathname,xname,u->objname,xtype);

            create_xdef(gv,s,xname,(int32_t)xval,
                        xtype==EXT_DEF?SYM_RELOC:SYM_ABS,SYMB_GLOBAL);
          }
          s = NULL;
          secname = NULL;

          if (--hunksleft == 0) {
            /* unit is complete, add it */
            add_objunit(gv,u,TRUE);
            u = NULL;
            if (hi.indexcnt <= 2)
              goto hunk_lib_done;
          }
        }

        if (u == NULL) {
          /* get the next HUNK_UNIT from an indexed HUNK_LIB library */
          u = create_objunit(gv,lf,readstrpool(&hi));
          hi.hunkptr = hi.libbase + (readindex(&hi) << 2);
          hi.hunkcnt = 0x10000000;
          hunksleft = readindex(&hi);
          index = 0;
        }

        if (hunksleft && secname==NULL) {
          /* read next section name */
          secname = (char *)readstrpool(&hi);
          skipindex(&hi,4);  /* ignore hunk size and type */
        }
        indexhunk = FALSE;  /* continue normally until HUNK_END */
      }
      else {
hunk_lib_done:
        /* finished with HUNK_LIB - clean up */
        hi.hunkptr = hi.indexptr + hi.indexcnt;
        hi.hunkcnt = hi.savedhunkcnt;
        hi.libbase = NULL;
        indexhunk = FALSE;
      }
    }
  }

  add_objunit(gv,u,TRUE);  /* add last one to glob. ObjUnit list */
}



/*****************************************************************/
/*                      Link ADOS / EHF                          */
/*****************************************************************/


static uint8_t cmpsecflags(struct LinkedSection *ls,struct Section *sec)
/* compare and verify target-specific section flags, */
/* return 0xff if sections are incompatible, otherwise return new flags */
{
  if (ls->flags&SF_EHFPPC != sec->flags&SF_EHFPPC)
    return 0xff;
  if (!ls->memattr || !sec->memattr || ls->memattr==sec->memattr)
    return ls->flags | sec->flags;
  return 0xff;
}


static int targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                      struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  static char *merged = "__MERGED";

  /* AmigaDOS doesn't merge unnamed sections, unless the Small- */
  /* Data/Code option was set */
  if (!(gv->small_code && s->type==ST_CODE) &&
      !(gv->small_data && (s->type==ST_DATA || s->type==ST_UDATA)))
    if (*(ls->name)==0 && *(s->name)==0)
      return -1;

  /* sections with name "_NOMERGE" are never combined */
  if (!strcmp(s->name,"_NOMERGE"))
    return -1;

  if (!strcmp(ls->name,merged) && !strcmp(s->name,merged)) {
    /* data and bss section with name __MERGED are always combined */
    if (s->type == ST_CODE)
      error(57,getobjname(s->obj)); /* Merging code section "__MERGED" */
    return 1;
  }

  return 0;
}


static struct Symbol *ados_lnksym(struct GlobalVars *gv,struct Section *sec,
                                  struct Reloc *xref)
/* Checks, if undefined symbol is an ADOS-linker symbol */
{
  struct Symbol *sym;
  int i;

  if (!gv->dest_object) {
    for (i=0; i<=LAST_LNKSYM; i++) {
      if (!strcmp(ados_symnames[i],xref->xrefname)) {
        if (i==SASCT || i==SASDT) {
          /* map to ___CTOR_LIST__ / ___DTOR_LIST__ */
          return findlnksymbol(gv,(i == SASCT) ?
                                  "___CTOR_LIST__" : "___DTOR_LIST__");
        }
        else {
          sym = addlnksymbol(gv,ados_symnames[i],0,SYM_ABS,
                             SYMF_LNKSYM,SYMI_OBJECT,SYMB_GLOBAL,0);
          if (i==PHXDB || i==SASPT || i==SASBB || i==DICDB ||
              i==ELFSD || i==ELFS2) {
            sym->type = SYM_RELOC;
          }
          if ((i==SASPT || i==PHXDB || i==DICDB) &&
              findlnksymbol(gv,sdabase_name)==NULL) {
            /* Reference to _LinkerDB, _DATA_BAS_ or __DATA_BAS
               creates _SDA_BASE_ */
            struct Symbol *sdabase = addlnksymbol(gv,sdabase_name,0,SYM_ABS,
                                                  SYMF_LNKSYM,SYMI_OBJECT,
                                                  SYMB_GLOBAL,0);
            sdabase->type = SYM_RELOC;
            sdabase->extra = ELFSD;
          }
          sym->extra = i;  /* for easy identification in ados_setlnksym */
          return sym;  /* new linker symbol created */
        }
      }
    }
  }
  return NULL;
}


static void ados_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
/* Initialize ADOS linker symbol structure during resolve_xref() */
{
  if (xdef->flags & SYMF_LNKSYM) {
    struct LinkedSection *ls,*sdsec=NULL;

    if (xdef->extra == ELFS2) {
      if (!(sdsec = find_lnksec(gv,sdata2_name,ST_DATA,0,0,0)))
        if (!(sdsec = find_lnksec(gv,sbss2_name,ST_UDATA,0,0,0)))
          sdsec = smalldata_section(gv);
      xdef->relsect = (struct Section *)sdsec->sections.first;
    }
    else if (xdef->extra!=SASCT && xdef->extra!=SASDT) {
      sdsec = smalldata_section(gv);
      xdef->relsect = (struct Section *)sdsec->sections.first;
    }
    switch (xdef->extra) {
      case PHXDL:
      case SASBB:
      case DICDL:
        xdef->value = (lword)sdsec->filesize;
        break;
      case PHXBL:
      case SASBL:
      case DICBL:
        xdef->value = (lword)(sdsec->size - sdsec->filesize);
        break;
      case SASPT:
      case ELFSD:
      case ELFS2:
        xdef->value = (lword)fff[gv->dest_format]->baseoff;
        break;
      case GNUTL:
        if (ls = find_lnksec(gv,NULL,ST_CODE,0,0,0))
          xdef->value = (lword)ls->size;
        break;
      case GNUDL:
        if (ls = find_lnksec(gv,NULL,ST_DATA,0,0,0))
          xdef->value = (lword)ls->size;
        break;
      case GNUBL:
        if (ls = find_lnksec(gv,NULL,ST_UDATA,0,0,0))
          xdef->value = (lword)ls->size;
        break;        
    }
    xdef->flags &= ~SYMF_LNKSYM;  /* do not init again */
  }
}


static struct Symbol *ehf_findsymbol(struct GlobalVars *gv,
                                     struct Section *sec,const char *name)
{
  struct Symbol *sym = gv->symbols[elf_hash(name)%SYMHTABSIZE];
  struct Symbol *second_choice = NULL;

  while (sym) {
    if (!strcmp(name,sym->name)) {
      if (second_choice == NULL)
        second_choice = sym;

      if (sec!=NULL && sym->type==SYM_RELOC) {
        /* we prefer symbols from a section which has the same CPU-flags
           as the caller's section */
        if ((sec->flags & SF_EHFPPC) == (sym->relsect->flags & SF_EHFPPC))
          break;
      }
      else
        break;
    }
    sym = sym->glob_chain;
  }

  /* accept symbol from a section for a different CPU, if it's the only one */
  if (!sym && second_choice)
    sym = second_choice;

  if (sym)
    if (sym->type == SYM_INDIR)
      return ehf_findsymbol(gv,sec,sym->indir_name);

  return sym;
}


static struct Symbol *ehf_lnksym(struct GlobalVars *gv,struct Section *sec,
                                 struct Reloc *xref)
/* Checks if undefined symbol is an EHF-linker symbol */
{
  if (!gv->dest_object || gv->alloc_addr) {

    if (!strncmp(ehf_addrsym,xref->xrefname,sizeof(ehf_addrsym)-1)) {
      const char *symname = xref->xrefname + (sizeof(ehf_addrsym) - 1);

      if (find_any_symbol(gv,sec,symname)) {
        /* Reference to an unknown symbol, which starts with "@_". */
        /* The symbol without "@_" has to exist. */
        char *objname = alloc(strlen(symname)+3);
        uint8_t *dat = alloczero(sizeof(uint32_t)); /* space for a 32-bit ptr */
        struct SecAttrOvr *sao;
        struct ObjectUnit *ou;
        struct Section *s;
        struct Symbol *sym;
        struct Reloc *r;

        /* create an artificial object with a ".tocd" data section */
        sprintf(objname,"%s.o",symname);
        ou = art_objunit(gv,objname,dat,sizeof(uint32_t));
        s = add_section(ou,tocd_name,dat,sizeof(uint32_t),ST_DATA,
                        SF_ALLOC,SP_READ|SP_WRITE,2,FALSE);
        if (sao = getsecattrovr(gv,tocd_name,SAO_MEMFLAGS))
          s->memattr = sao->memflags;

        /* "@__name" contains a 32-bit reloc pointer, which has an */
        /* external reference to the symbol "_name". */
        r = newreloc(gv,s,symname,NULL,0,0,R_ABS,0);
        addreloc(s,r,0,32,-1);

        /* make "@__name" visible for the further linking process: */
        if (addsymbol(gv,s,xref->xrefname,NULL,0,SYM_RELOC,0,SYMI_OBJECT,
                      SYMB_GLOBAL,sizeof(uint32_t),FALSE))
          ierror("ehf_lnksym(): %s was assumed to be undefined, but "
                 "in reality it *is* defined",xref->xrefname);

        if (!(sym = findsymbol(gv,sec,xref->xrefname)))
          ierror("ehf_lnksym(): The just defined symbol %s has "
                 "disappeared",xref->xrefname);
        return sym;
      }
    }
  }

  return ados_lnksym(gv,sec,xref);
}


static void ehf_setlnksym(struct GlobalVars *gv,struct Symbol *xdef)
/* Initialize EHF linker symbol structure during resolve_xref() */
{
  ados_setlnksym(gv,xdef);
}



/*****************************************************************/
/*                     Write ADOS / EHF                          */
/*****************************************************************/


static unsigned long headersize(struct GlobalVars *gv)
{
  return 0;  /* irrelevant for ADOS/EHF */
}


static void hunk_memdata(FILE *f,uint32_t mem,uint32_t dat)
/* write a data word with memory flags, add extension word for full
   list of memory attributes, when needed (other than CHIP or FAST) */
{
  if ((mem & ~MEMF_PUBLIC) == 0) {
    fwrite32be(f,dat);
  }
  else if ((mem & ~MEMF_PUBLIC) == MEMF_CHIP) {
    fwrite32be(f,HUNKF_CHIP|dat);
  }
  else if ((mem & ~MEMF_PUBLIC) == MEMF_FAST) {
    fwrite32be(f,HUNKF_FAST|dat);
  }
  else {
    fwrite32be(f,HUNKF_FAST|HUNKF_CHIP|dat);
    fwrite32be(f,mem);
  }
}


static void hunk_name_len(FILE *f,const char *name)
/* writes a string in hunk-format style, i.e. first longword contains */
/* strlen in longwords and then follows the string itself, long-aligned */
{
  size_t l=strlen(name);

  fwrite32be(f,l?((l+3)>>2):0);
  fwritex(f,name,l);
  fwrite_align(f,2,l);
}


static void hunk_name(FILE *f,const char *name)
/* writes a longword-aligned string, like hunk_name_len(), but */
/* without writing the length */
{
  size_t l=strlen(name);

  fwritex(f,name,l);
  fwrite_align(f,2,l);
}


static int strlen32(const char *s)
/* strlen in 32-bit words */
{
  int l=strlen(s);

  return l?((l+3)>>2):0;
}


static void ext_defs(struct GlobalVars *gv,FILE *f,struct LinkedSection *sec,
                     uint8_t bind,uint8_t stype,uint32_t xdeftype)
{
  struct Symbol *nextsym,*sym=(struct Symbol *)sec->symbols.first;
  bool xdefs = FALSE;

  while (nextsym = (struct Symbol *)sym->n.next) {
    if (sym->type==stype && sym->bind==bind && sym->info<=SYMI_FUNC) {
      remnode(&sym->n);

      if (!discard_symbol(gv,sym)) {
        if (xdeftype != EXT_IGNORE) {
          if (!xdefs) {
            xdefs = TRUE;
            if (xdeftype == EXT_SYMB) {
              if (!symhunk) {
                symhunk = TRUE;
                fwrite32be(f,HUNK_SYMBOL);
              }
            }
            else {
              if (!exthunk) {
                exthunk = TRUE;
                fwrite32be(f,HUNK_EXT);
              }
            }
          }
          /* generate xdef or symbol table entry */
          if (xdeftype==EXT_SYMB && strlen(sym->name)>124) {
            /* LoadSeg<=V40 doesn't allow more than 31 longwords per symbol,
               and will respond with "bad loadfile hunk" otherwise -
               so just strip the rest! */
            fwrite32be(f,(xdeftype << 24) | 31);
            fwritex(f,sym->name,124);
          }
          else {
            fwrite32be(f,(xdeftype << 24) | strlen32(sym->name));
            hunk_name(f,sym->name);           /* write symbol's name */
          }
          fwrite32be(f,(uint32_t)sym->value);  /* ... and its value */
        }

        else { /* EXT_IGNORE */
          if (stype==SYM_COMMON && !(sym->flags & SYMF_REFERENCED))
            /* Warning: unreferenced common symbol will disappear! */
            error(93,fff_amigahunk.tname,sym->name);
        }
      }
    }
    sym = nextsym;
  }
}


static void unsupp_symbols(struct LinkedSection *sec)
{
  struct Symbol *sym;

  while (sym = (struct Symbol *)remhead(&sec->symbols)) {
    if (sym->info <= SYMI_FUNC)
      error(33,fff_amigahunk.tname,sym->name,sym_bind[sym->bind],
            sym_type[sym->type],sym_info[sym->info]);
    else
      ;  /* SYMI_SECTION and SYMI_FILE symbols are ignored for now */
  }
}


static void unsupp_relocs(struct LinkedSection *sec)
{
  struct Reloc *rel;

  while (rel = (struct Reloc *)remhead(&sec->relocs)) {
    error(32,fff_amigahunk.tname,reloc_name[rel->rtype],
          (int)rel->insert->bpos,(int)rel->insert->bsiz,
          rel->insert->mask,sec->name,rel->offset);
  }
}


static void ext_refs(FILE *f,struct LinkedSection *sec,bool ehf)
{
  struct list xnodelist;  /* xrefs with same ref. type and symbol name */
  struct XRefNode *xn,*nextxn;
  struct Reloc *xref;

  initlist(&xnodelist);
  while (xref = (struct Reloc *)remhead(&sec->xrefs)) {
    const char *name = xref->xrefname;  /* name of xref'ed symbol */
    uint8_t rtype = 0;

    if (xref->relocsect.symbol) {
      if (xref->relocsect.symbol->type == SYM_COMMON) {
        if (isstdreloc(xref,R_ABS,32)) {
          rtype = EXT_ABSCOMMON;
          goto rtype_done;
        }
        else if (isstdreloc(xref,R_PC,32)) {
          rtype = EXT_RELCOMMON;
          goto rtype_done;
        }
        else if (isstdreloc(xref,R_SD,32)) {
          rtype = EXT_DEXT32COMMON;
          goto rtype_done;
        }
        else if (isstdreloc(xref,R_SD,16)) {
          rtype = EXT_DEXT16COMMON;
          goto rtype_done;
        }
        else if (isstdreloc(xref,R_SD,8)) {
          rtype = EXT_DEXT8COMMON;
          goto rtype_done;
        }
      }
    }

    /* reference reloc type mapping */
    if (isstdreloc(xref,R_ABS,32)) rtype = EXT_ABSREF32;
    else if (isstdreloc(xref,R_ABS,16)) rtype = EXT_ABSREF16;
    else if (isstdreloc(xref,R_ABS,8)) rtype = EXT_ABSREF8;
    else if (isstdreloc(xref,R_PC,32)) rtype = EXT_RELREF32;
    else if (isstdreloc(xref,R_PC,16)) rtype = EXT_RELREF16;
    else if (isstdreloc(xref,R_PC,8)) rtype = EXT_RELREF8;
    else if (isstdreloc(xref,R_SD,32)) rtype = EXT_DEXT32;
    else if (isstdreloc(xref,R_SD,16)) rtype = EXT_DEXT16;
    else if (isstdreloc(xref,R_SD,8)) rtype = EXT_DEXT8;

    else if (ehf && xref->rtype==R_PC) {
      /* also check EHF/PowerPC relocation types */
      struct RelocInsert *ri;

      if (ri = xref->insert) {
        if (ri->bpos==6 && ri->bsiz==24 &&
            (ri->mask&0x3ffffff)==0x3fffffc) {
          rtype = EXT_RELREF26;
        }
        else if ((ri->bpos&15)==0 && ri->bsiz==14 &&
                 (ri->mask&0xffff)==0xfffc) {
          rtype = EXT_RELREF16;
        }
      }
    }

rtype_done:
    if (!rtype) {
      error(32,fff_amigahunk.tname,reloc_name[xref->rtype],
            (int)xref->insert->bpos,(int)xref->insert->bsiz,
            xref->insert->mask,sec->name,xref->offset);
      rtype = EXT_RELREF8;  /* @@@ to keep the loop running */
    }

    /* search appropriate XRefNode for referenced symbol and type */
    xn = (struct XRefNode *)xnodelist.first;
    while (nextxn = (struct XRefNode *)xn->n.next) {
      if (!strcmp(name,xn->sym_name) && rtype==xn->ref_type)
        break;
      xn = nextxn;
    }
    if (nextxn==NULL) {  /* we have to create a new XRefNode? */
      xn = alloc(sizeof(struct XRefNode));
      xn->sym_name = name;
      xn->ref_type = rtype;
      xn->com_size = (rtype==EXT_ABSCOMMON || rtype==EXT_RELCOMMON ||
                      (rtype>=EXT_DEXT32COMMON && rtype<=EXT_DEXT8COMMON)) ?
                     xref->relocsect.symbol->size : 0;
      xn->noffsets = 0;
      initlist(&xn->xreflist);
      addtail(&xnodelist,&xn->n);
    }

    /* add new offset to xreflist for same ref. type and symbol name */
    addtail(&xn->xreflist,&xref->n);
    xn->noffsets++;
  }

  if (xnodelist.first->next) {  /* at least one reference in this section? */
    if (!exthunk) {
      exthunk = TRUE;
      fwrite32be(f,HUNK_EXT);
    }
    while (xn = (struct XRefNode *)remhead(&xnodelist)) {
      fwrite32be(f,((uint32_t)xn->ref_type << 24) | strlen32(xn->sym_name));
      hunk_name(f,xn->sym_name);  /* symbol's name */
      if (xn->com_size)  /* store size of common block? */
        fwrite32be(f,xn->com_size);
      fwrite32be(f,(uint32_t)xn->noffsets);  /* number of references */
      while (xref = (struct Reloc *)remhead(&xn->xreflist)) {
        fwrite32be(f,(uint32_t)xref->offset);  /* offset */
      }
      free(xn);
    }
  }
}


static void linedebug_hunks(struct GlobalVars *gv,FILE *f,
                            struct LinkedSection *ls)
{
  struct Section *sec = (struct Section *)ls->sections.first;
  struct Section *nextsec;
  struct LineDebug *ldb;

  while (nextsec = (struct Section *)sec->n.next) {
    if (ldb = (struct LineDebug *)sec->special) {
      do {
        if (ldb->tgext.id==TGEXT_AMIGAOS && ldb->tgext.sub_id==SUBID_LINE) {
          uint32_t i,*lptr,*optr;

          fwrite32be(f,HUNK_DEBUG);
          fwrite32be(f,3 + strlen32(ldb->source_name) +
                     (ldb->num_entries<<1));
          fwrite32be(f,(uint32_t)sec->offset);
          fwrite32be(f,0x4c494e45);  /* "LINE" */
          hunk_name_len(f,ldb->source_name);
          for (i=0,lptr=ldb->lines,optr=ldb->offsets;
               i<ldb->num_entries; i++) {
            fwrite32be(f,*lptr++);
            fwrite32be(f,*optr++);
          }
        }
      }
      while (ldb = (struct LineDebug *)ldb->tgext.next);
    }
    sec = nextsec;
  }
}


static void fix_reloc_addends(struct GlobalVars *gv,struct LinkedSection *ls)
{
  struct Reloc *rel;

  for (rel=(struct Reloc *)ls->relocs.first;
       rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next) {
    writesection(gv,ls->data+rel->offset,rel,rel->addend);
  }
}


static void fix_xref_addends(struct GlobalVars *gv,struct LinkedSection *ls)
{
  struct Reloc *xref;

  for (xref=(struct Reloc *)ls->xrefs.first;
       xref->n.next!=NULL; xref=(struct Reloc *)xref->n.next) {
    writesection(gv,ls->data+xref->offset,xref,xref->addend);
  }
}


static void reloc_hunk(struct GlobalVars *gv,FILE *f,
                       struct LinkedSection *sec,uint32_t relhunk,
                       uint8_t rtype,uint16_t rsize)
/* generate an AmigaDOS/EHF relocation hunk for a specific reloc type */
{
  struct Reloc *nextrel,*rel=(struct Reloc *)sec->relocs.first;
  struct list **rlist=alloc(gv->nsecs*sizeof(struct list *));
  int *rcnt=alloczero(gv->nsecs*sizeof(int)); /* reloc cnt for all sect. */
  bool hunk_required=FALSE,small_offsets=TRUE;
  lword chkmask,rmask=makemask(rsize);
  uint16_t rpos=0;
  int i;

  for (i=0; i<gv->nsecs; i++) {  /* empty reloc lists for each section */
    rlist[i] = alloc(sizeof(struct list));
    initlist(rlist[i]);
  }

  /* EHF-PowerPC relocations need special treatment */
  if (rsize == 24) {
    rpos = 6;
    rmask = 0x3ffffff;
    chkmask = 0x3fffffc;
  }
  else if (rsize == 14) {
    rpos = 16;
    rmask = 0xffff;
    chkmask = 0xfffc;
  }
  else
    chkmask = rmask;

  while (nextrel = (struct Reloc *)rel->n.next) {
    struct RelocInsert *ri;
    int newrcnt;

    if (rel->rtype==rtype && (ri=rel->insert)!=NULL) {
      if (ri->bpos==rpos && ri->bsiz==rsize && (ri->mask&rmask)==chkmask) {
        /* move reloc node of correct type into relocssect's rlist */
        remnode(&rel->n);
        addtail(rlist[rel->relocsect.lnk->index],&rel->n);
        rel->offset += rpos >> 3;
        if (++rcnt[rel->relocsect.lnk->index] >= 0x10000 ||
            rel->offset >= 0x10000)
          small_offsets = FALSE; /* no short-reloc hunk would be possible */
        hunk_required = TRUE;
      }
    }
    rel = nextrel;
  }

  if (hunk_required) {  /* there's at least one relocation */

    if ((relhunk==HUNK_ABSRELOC32 &&
         gv->reloctab_format==RTAB_SHORTOFF && small_offsets) ||
        (relhunk==HUNK_RELRELOC32 && !gv->dest_object)) {
      /* Make a short hunk with 16-bit offsets.
         For executables, HUNK_DREL32 is used instead of the correct
         HUNK_RELOC32SHORT to be compatible with OS2.0.
         Due to a bug in OS3.x HUNK_RELRELOC32 requires 16-bit offsets
         in executables. */
      int cnt=0;

      if (!small_offsets) {
        /* cannot represent those relocs, so put them back */
        for (i=0; i<gv->nsecs; i++) {
          while (rel = (struct Reloc *)remhead(rlist[i]))
            addtail(&sec->relocs,&rel->n);
        }
        goto free_rlists;
      }
      if (!gv->dest_object && relhunk==HUNK_ABSRELOC32)
        relhunk = HUNK_DREL32;
      fwrite32be(f,relhunk);  /* reloc hunk id */

      for (i=0; i<gv->nsecs; i++) {
        if (rcnt[i]) {
          fwrite16be(f,(uint16_t)rcnt[i]);  /* number of relocations */
          fwrite16be(f,(uint16_t)i);  /* section index */
          cnt += 2;

          /* store relocation offsets */
          while (rel = (struct Reloc *)remhead(rlist[i])) {
            fwrite16be(f,(uint16_t)rel->offset);
            cnt++;
          }
        }
      }
      /* no more relocation entries */
      if (cnt & 1)  /* 0-word for 32-bit alignment */
        fwrite16be(f,0);
      else
        fwrite32be(f,0);
    }

    else {
      /* all other relocation hunks */
      fwrite32be(f,relhunk);  /* reloc hunk id */
      for (i=0; i<gv->nsecs; i++) {
        while (rcnt[i]) {
          /* never write more than 65536 relocs at once - there is a bug */
          /* in dos.library which rejects the executable file otherwise */
          int n = (rcnt[i]>0x10000) ? 0x10000 : rcnt[i];

          fwrite32be(f,(uint32_t)n);  /* number of relocations */
          fwrite32be(f,(uint32_t)i);  /* section index */
          rcnt[i] -= n;

          /* store relocation offsets */
          while (n--) {
            if (rel = (struct Reloc *)remhead(rlist[i])) {
              fwrite32be(f,(uint32_t)rel->offset);
            }
          }
        }
      }
      fwrite32be(f,0);  /* no more relocation entries */
    }
  }

  free_rlists:
  /* free dynamically allocated rlists and rcnt array */
  for (i=0; i<gv->nsecs; free(rlist[i++]));
  free(rcnt);
}


static void writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void writeobject(struct GlobalVars *gv,FILE *f,bool ehf)
/* creates a target-amigahunk relocatable object file */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextls;

  fwrite32be(f,HUNK_UNIT);
  hunk_name_len(f,gv->dest_name);  /* unit name is output file name */

  if (ls->n.next == NULL) {
    /* special case: no sections, create dummy section */
    fwrite32be(f,HUNK_CODE);
    fwrite32be(f,0);
    fwrite32be(f,HUNK_END);
    return;
  }

  /* section loop */
  while (nextls = (struct LinkedSection *)ls->n.next) {
    exthunk = symhunk = FALSE;
    fwrite32be(f,HUNK_NAME);
    hunk_name_len(f,ls->name);  /* section name */

    switch (ls->type) {  /* section type */
      case ST_CODE:
        if ((ls->flags & SF_EHFPPC) && ehf)
          hunk_memdata(f,ls->memattr,HUNK_PPC_CODE);
        else
          hunk_memdata(f,ls->memattr,HUNK_CODE);
        break;
      case ST_DATA:
        hunk_memdata(f,ls->memattr,HUNK_DATA);
        break;
      case ST_UDATA:
        hunk_memdata(f,ls->memattr,HUNK_BSS);
        break;
      default:
        ierror("writeobject(): Illegal section type %u",ls->type);
        break;
    }

    fix_reloc_addends(gv,ls);
    fix_xref_addends(gv,ls);
    fwrite32be(f,(ls->size+3)>>2);  /* section size */
    if (!(ls->flags & SF_UNINITIALIZED)) {
      fwritex(f,ls->data,ls->size);  /* write section contents */
      fwrite_align(f,2,ls->size);
    }

    /* relocation hunks */
    reloc_hunk(gv,f,ls,HUNK_ABSRELOC32,R_ABS,32);
    reloc_hunk(gv,f,ls,HUNK_RELRELOC32,R_PC,32);
    reloc_hunk(gv,f,ls,HUNK_RELRELOC16,R_PC,16);
    reloc_hunk(gv,f,ls,HUNK_DREL16,R_SD,16);
    if ((ls->flags & SF_EHFPPC) && ehf) {
      reloc_hunk(gv,f,ls,HUNK_RELRELOC26,R_PC,24);
      reloc_hunk(gv,f,ls,HUNK_RELRELOC16,R_PC,14);
    }
    unsupp_relocs(ls);  /* print unsupported relocations */

    /* external references and global definitions */
    ext_refs(f,ls,ehf);
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_RELOC,EXT_DEF);
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_ABS,EXT_ABS);
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_COMMON,EXT_IGNORE);
    if (exthunk)
      fwrite32be(f,0);  /* close HUNK_EXT block, if required */

    /* symbol table */
    ext_defs(gv,f,ls,SYMB_LOCAL,SYM_RELOC,EXT_SYMB);
    ext_defs(gv,f,ls,SYMB_LOCAL,SYM_ABS,EXT_IGNORE);
    if (symhunk)
      fwrite32be(f,0);  /* close HUNK_SYMBOL block, if required */
    unsupp_symbols(ls);  /* print unsupported symbol definitions */

    /* line debug hunks */
    if (gv->strip_symbols < STRIP_DEBUG) {
      if (checktargetext(ls,TGEXT_AMIGAOS,SUBID_LINE))
        linedebug_hunks(gv,f,ls);
    }

    fwrite32be(f,HUNK_END);  /* end of this section */
    ls = nextls;
  }
}


static void ados_writeobject(struct GlobalVars *gv,FILE *f)
{
  writeobject(gv,f,FALSE);
}


static void ehf_writeobject(struct GlobalVars *gv,FILE *f)
{
  writeobject(gv,f,TRUE);
}


static void writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-amigahunk executable file (which is relocatable) */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextls;
  int i=0;

  fwrite32be(f,HUNK_HEADER);
  fwrite32be(f,0);  /* resident libraries no longer supp. since OS2.0 */

  if (ls->n.next == NULL) {
    /* special case: no sections, create dummy section */
    fwrite32be(f,1);
    fwrite32be(f,0);
    fwrite32be(f,0);
    fwrite32be(f,0);
    fwrite32be(f,HUNK_CODE);
    fwrite32be(f,0);
    fwrite32be(f,HUNK_END);
    return;
  }

  fwrite32be(f,gv->nsecs);  /* number of sections - no overlay support! @@@ */
  fwrite32be(f,0);
  fwrite32be(f,gv->nsecs-1);

  /* write section size specifiers */
  while (nextls = (struct LinkedSection *)ls->n.next) {
    hunk_memdata(f,ls->memattr,(ls->size+3)>>2);
    ls = nextls;
    i++;
  }
  if (i != gv->nsecs)
    ierror("writeexec(): %d sections in list, but it should be %d",
           i,gv->nsecs);

  /* section loop */
  ls = (struct LinkedSection *)gv->lnksec.first;
  while (nextls = (struct LinkedSection *)ls->n.next) {
    exthunk = symhunk = FALSE;

    switch (ls->type) {  /* section type */
      case ST_CODE:
        fwrite32be(f,HUNK_CODE);
        break;
      case ST_DATA:
        fwrite32be(f,HUNK_DATA);
        break;
      case ST_UDATA:
        fwrite32be(f,HUNK_BSS);
        break;
      default:
        ierror("writeexec(): Illegal section type %u",ls->type);
        break;
    }

    fix_reloc_addends(gv,ls);
    if (ls->flags & SF_UNINITIALIZED) {
      fwrite32be(f,(ls->size+3)>>2);  /* bss - size only */
    }
    else {
      fwrite32be(f,(ls->filesize+3)>>2);  /* initialized section size */
      fwritex(f,ls->data,ls->filesize);   /* write section contents */
      fwrite_align(f,2,ls->filesize);
    }

    /* relocation hunks */
    reloc_hunk(gv,f,ls,HUNK_ABSRELOC32,R_ABS,32);
    reloc_hunk(gv,f,ls,HUNK_RELRELOC32,R_PC,32);
    unsupp_relocs(ls);  /* print unsupported relocations */

    /* symbol table */
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_RELOC,EXT_SYMB);
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_ABS,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_GLOBAL,SYM_INDIR,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_LOCAL,SYM_RELOC,EXT_SYMB);
    ext_defs(gv,f,ls,SYMB_LOCAL,SYM_ABS,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_LOCAL,SYM_INDIR,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_WEAK,SYM_RELOC,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_WEAK,SYM_ABS,EXT_IGNORE);
    ext_defs(gv,f,ls,SYMB_WEAK,SYM_INDIR,EXT_IGNORE);
    if (symhunk)
      fwrite32be(f,0);  /* close HUNK_SYMBOL block, if required */
    unsupp_symbols(ls);  /* print unsupported symbol definitions */

    /* line debug hunks */
    if (gv->strip_symbols < STRIP_DEBUG) {
      if (checktargetext(ls,TGEXT_AMIGAOS,SUBID_LINE))
        linedebug_hunks(gv,f,ls);
    }

    fwrite32be(f,HUNK_END);  /* end of this section */
    ls = nextls;
  }
}


#endif
