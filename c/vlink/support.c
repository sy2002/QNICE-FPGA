/* $VER: vlink support.c V0.14a (03.09.11)
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


#define SUPPORT_C
#include "vlink.h"

#define GAPBUFSIZE 1024  /* for fwritegap() */

const char *endian_name[2] = { "little", "big" };
static char *unnamed_txt = "unnamed";



void *alloc(size_t size)
/* allocate memory and print error message if not enough available */
{
  void *p;

  if (!size)
    size = 1;
  if (!(p = malloc(size)))
    error(1);  /* out of memory */
  return p;
}


void *re_alloc(void *old,size_t size)
/* reallocate memory block, preserve old contents */
{
  void *p;

  if (!size)
    size = 1;
  if (!(p = realloc(old,size)))
    error(1);  /* out of memory */
  return p;
}


void *alloczero(size_t size)
/* same as alloc() but zeroes the allocated memory */
{
  void *p = alloc(size);

  memset(p,0,size);
  return p;
}


const char *allocstring(const char *s)
/* allocate space for a single string */
/* @@@ this should be improved by some kind of string buffer */
{
  char *p = alloc(strlen(s)+1);

  strcpy(p,s);
  return p;
}


void *alloc_hashtable(size_t entries)
{
  return alloczero(entries * sizeof(void *));
}


void initlist(struct list *l)
/* initializes a list structure */
{
  l->first = (struct node *)&l->dummy;
  l->dummy = NULL;
  l->last = (struct node *)&l->first;
}


void insertbefore(struct node *n,struct node *sn)
/* insert node n directly before node sn */
/* sn must be a real node - no dummy nodes allowed! */
{
  struct node *pn = sn->pred;

  n->next = sn;
  n->pred = pn;
  pn->next = sn->pred = n;
}


void insertbehind(struct node *pn,struct node *n)
/* insert node n directly behind node pn */
/* pn must be a real node - no dummy nodes allowed! */
{
  struct node *sn = pn->next;

  n->next = sn;
  n->pred = pn;
  pn->next = sn->pred = n;
}


void addhead(struct list *l,struct node *n)
/* add node as first element of list */
{
  struct node *fn = l->first;

  n->pred = fn->pred;
  fn->pred = n;
  n->next = fn;
  l->first = n;
}


void addtail(struct list *l,struct node *n)
/* add node as last element of list */
{
  struct node *ln = l->last;

  n->next = ln->next;
  ln->next = n;
  n->pred = ln;
  l->last = n;
}


struct node *remhead(struct list *l)
/* remove first node in list and return a pointer to it */
{
  struct node *n = l->first;

  if (n->next) {
    l->first = n->next;
    n->next->pred = n->pred;
    return n;
  }
  return NULL;
}


struct node *remnode(struct node *n)
/* remove a node from a list */
{
  n->next->pred = n->pred;
  n->pred->next = n->next;
  return n;
}


static size_t filesize(FILE *fp,const char *name)
{
  /* somebody knows a better way to determine file size in ANSI C? */
  long oldpos,size;

  if ((oldpos = ftell(fp)) >= 0)
    if (fseek(fp,0,SEEK_END) >= 0)
      if ((size = ftell(fp)) >= 0)
        if (fseek(fp,oldpos,SEEK_SET) >= 0)
          return (size_t)size;
  fclose(fp);
  error(5,name);  /* read error - doesn't return */
  return 0;
}


char *mapfile(const char *name)
/* Map a complete file into memory and return its address. */
/* The file's length is returned in *(p-sizeof(size_t)). */
/* The last byte is followed by a 0-byte, indicating EOF for */
/* functions which need it. */
{
  FILE *fp;
  char *p=NULL;
  size_t fsiz;

  if (fp = fopen(name,"rb")) {
    fsiz = filesize(fp,name);
    p = alloc(fsiz+sizeof(size_t)+1);
    *(size_t *)p = fsiz;  /* store file size before the text starts */
    p += sizeof(size_t);
    *(p+fsiz) = 0;        /* terminated by 0-byte */
    if (fread(p,1,fsiz,fp) != fsiz) {
      fclose(fp);
      error(7,name);  /* read error */
    }
    fclose(fp);
  }
  return p;
}


const char *base_name(const char *s)
/* returns last part of a path - the file name itself */
{
  char c;
  int l = strlen(s);

  while (l--) {
    c = s[l];
    if (c== '/' || c==':')
      return &s[l+1];
  }
  return s;
}


char *check_name(char *name)
/* returns "unnamed", if name is a NULL-pointer */
{
  if (name)
    return name;
  return unnamed_txt;
}


bool checkrange(lword val,bool sign,int size)
/* Checks if 'val' (signed or unsigned) fits into 'size' bits.
   Returns FALSE when 'val' is out of range! */
{
  if (size) {
    lword min = -(1LL<<(size-1));
    lword max = sign ? ((1LL<<(size-1))-1LL) : ((1LL<<size)-1LL);

    if (val<min || val>max)
      return FALSE;

    return TRUE;
  }

  ierror("checkrange(): size==0 (val=%lld)\n",val);
  return FALSE;  /* size==0 is illegal */
}


int8_t host_endianess(void)
{
  static uint32_t x = 0x01020304;

  return *((uint8_t *)&x)==1 ? _BIG_ENDIAN_ : _LITTLE_ENDIAN_;
}


uint16_t swap16(uint16_t x)
/* 16-bit endian conversion */
{
  return (x&0xff)<<8 | (x&0xff00)>>8;
}


uint32_t swap32(uint32_t x)
/* 32-bit endian conversion */
{
  return (x&0xff)<<24 | (x&0xff00)<<8 |
         (x&0xff0000)>>8 | (x&0xff000000)>>24;
}


uint64_t swap64(uint64_t x)
/* 64-bit endian conversion */
{
  return (x&0xff)<<56 | (x&0xff00)<<40 |
         (x&0xff0000)<<24 | (x&0xff000000)<<8 |
         (x&0xff00000000LL)>>8 | (x&0xff0000000000LL)>>24 |
         (x&0xff000000000000LL)>>40 | (x&0xff00000000000000LL)>>56;
}


uint16_t read16be(void *vp)
/* read 16 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint16_t)*p)<<8 | ((uint16_t)*(p+1));
}


uint32_t read32be(void *vp)
/* read 32 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint32_t)*p)<<24 | ((uint32_t)*(p+1))<<16 |
         ((uint32_t)*(p+2))<<8 | ((uint32_t)*(p+3));
}


uint64_t read64be(void *vp)
/* read 64 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint64_t)*p)<<56 | ((uint64_t)*(p+1))<<48 |
         ((uint64_t)*(p+2))<<40 | ((uint64_t)*(p+3))<<32 |
         ((uint64_t)*(p+4))<<24 | ((uint64_t)*(p+5))<<16 |
         ((uint64_t)*(p+6))<<8 | ((uint64_t)*(p+7));
}


void write16be(void *vp,uint16_t x)
/* write 16 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)((x>>8)&0xff);
  *p = (uint8_t)(x&0xff);
}


void write32be(void *vp,uint32_t x)
/* write 32 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)((x>>24)&0xff);
  *p++ = (uint8_t)((x>>16)&0xff);
  *p++ = (uint8_t)((x>>8)&0xff);
  *p = (uint8_t)(x&0xff);
}


void write64be(void *vp,uint64_t x)
/* write 64 bit word in big endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)((x>>56)&0xff);
  *p++ = (uint8_t)((x>>48)&0xff);
  *p++ = (uint8_t)((x>>40)&0xff);
  *p++ = (uint8_t)((x>>32)&0xff);
  *p++ = (uint8_t)((x>>24)&0xff);
  *p++ = (uint8_t)((x>>16)&0xff);
  *p++ = (uint8_t)((x>>8)&0xff);
  *p = (uint8_t)(x&0xff);
}


uint16_t read16le(void *vp)
/* read 16 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint16_t)*p) | ((uint16_t)*(p+1))<<8;
}


uint32_t read32le(void *vp)
/* read 32 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint32_t)*p) | ((uint32_t)*(p+1))<<8 |
         ((uint32_t)*(p+2))<<16 | ((uint32_t)*(p+3))<<24;
}


uint64_t read64le(void *vp)
/* read 64 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  return ((uint64_t)*p) | ((uint64_t)*(p+1))<<8 |
         ((uint64_t)*(p+2))<<16 | ((uint64_t)*(p+3))<<24 |
         ((uint64_t)*(p+4))<<32 | ((uint64_t)*(p+5))<<40 |
         ((uint64_t)*(p+6))<<48 | ((uint64_t)*(p+7))<<56;
}


void write16le(void *vp,uint16_t x)
/* write 16 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)(x&0xff);
  *p = (uint8_t)((x>>8)&0xff);
}


void write32le(void *vp,uint32_t x)
/* write 32 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)(x&0xff);
  *p++ = (uint8_t)((x>>8)&0xff);
  *p++ = (uint8_t)((x>>16)&0xff);
  *p = (uint8_t)((x>>24)&0xff);
}


void write64le(void *vp,uint64_t x)
/* write 64 bit word in little endian format */
{
  uint8_t *p = (uint8_t *)vp;

  *p++ = (uint8_t)(x&0xff);
  *p++ = (uint8_t)((x>>8)&0xff);
  *p++ = (uint8_t)((x>>16)&0xff);
  *p++ = (uint8_t)((x>>24)&0xff);
  *p++ = (uint8_t)((x>>32)&0xff);
  *p++ = (uint8_t)((x>>40)&0xff);
  *p++ = (uint8_t)((x>>48)&0xff);
  *p = (uint8_t)((x>>56)&0xff);
}


uint16_t read16(bool be,void *p)
{
  return (be)?(read16be(p)):(read16le(p));
}


uint32_t read32(bool be,void *p)
{
  return (be)?(read32be(p)):(read32le(p));
}


uint64_t read64(bool be,void *p)
{
  return (be)?(read64be(p)):(read64le(p));
}


void write16(bool be,void *p,uint16_t d)
{
  if (be)
    write16be(p,d);
  else
    write16le(p,d);
}


void write32(bool be,void *p,uint32_t d)
{
  if (be)
    write32be(p,d);
  else
    write32le(p,d);
}


void write64(bool be,void *p,uint64_t d)
{
  if (be)
    write64be(p,d);
  else
    write64le(p,d);
}


int writetaddr(struct GlobalVars *gv,void *p,lword d)
{
  bool be = fff[gv->dest_format]->endianess == _BIG_ENDIAN_;

  switch (fff[gv->dest_format]->addr_bits) {
    case 16:
      write16(be,p,(uint16_t)d);
      return 2;
    case 32:
      write32(be,p,(uint32_t)d);
      return 4;
    case 64:
      write64(be,p,(uint64_t)d);
      return 8;
    default:
      ierror("writetaddr(): target address has %d bits",
             (int)fff[gv->dest_format]->addr_bits);
      break;
  }
  return 0;
}


uint32_t readbf32(bool be,void *p,int offset,int size)
/* read value from 32-bit bitfield */
{
  if (size>0 && offset+size<=32) {
    uint32_t mask=(1<<size)-1;

    return (be)?((read32be(p) >> (32-(offset+size))) & mask)
                :((read32le(p) >> offset) & mask);
  }
  ierror("readbf32(): Illegal arguments: offset=%d size=%d",offset,size);
  return 0;
}


void writebf32(bool be,void *p,int offset,int size,uint32_t d)
/* write value to 32-bit bitfield */
{
  if (size>0 && offset+size<=32) {
    uint32_t mask=(1<<size)-1;

    if (be) {
      int s = 32-(offset+size);
      write32be(p,(read32be(p) & ~(mask<<s)) | ((d & mask) << s));
    }
    else
      write32le(p,(read32le(p) & ~(mask<<offset)) | ((d & mask) << offset));
  }
  else
    ierror("writebf32(): Illegal arguments: offset=%d size=%d",offset,size);
}


void fwritex(FILE *fp,const void *buf,size_t len)
/* write a buffer of len bytes, with check for len=0 and write error */
{
  if (len) {
    if (!fwrite(buf,1,len,fp)) {
      fclose(fp);
      error(31,gvars.dest_name);  /* write error */
    }
  }
}


void fwrite32be(FILE *fp,uint32_t w)
/* write a big endian 32 bit word */
{
  uint8_t be[4];

  be[0] = (w>>24) & 0xff;
  be[1] = (w>>16) & 0xff;
  be[2] = (w>>8) & 0xff;
  be[3] = w & 0xff;
  fwritex(fp,be,4);
}


void fwrite16be(FILE *fp,uint16_t w)
/* write a big endian 16 bit word */
{
  uint8_t be[2];

  be[0] = (w>>8) & 0xff;
  be[1] = w & 0xff;
  fwritex(fp,be,2);
}


void fwrite32le(FILE *fp,uint32_t w)
/* write a little endian 32 bit word */
{
  uint8_t le[4];

  le[0] = w & 0xff;
  le[1] = (w>>8) & 0xff;
  le[2] = (w>>16) & 0xff;
  le[3] = (w>>24) & 0xff;
  fwritex(fp,le,4);
}


void fwrite16le(FILE *fp,uint16_t w)
/* write a little endian 16 bit word */
{
  uint8_t le[2];

  le[0] = w & 0xff;
  le[1] = (w>>8) & 0xff;
  fwritex(fp,le,2);
}


void fwrite8(FILE *fp,uint8_t w)
/* write a byte */
{
  fwritex(fp,&w,1);
}


void fwrite_align(FILE *fp,uint32_t a,uint32_t n)
/* writes as many zero bytes as required for alignment a (a bits */
/* must be zero) with current file offset n */
{
  static uint8_t alignment_bytes[MAX_FWALIGN];

  a = 1<<a;
  if ((n = (a-(n&(a-1))&(a-1))) > MAX_FWALIGN)
    ierror("fwrite_align(): Alignment > %d required",MAX_FWALIGN);
  fwritex(fp,alignment_bytes,n);
}


void fwritegap(FILE *f,long bytes)
{
  uint8_t buf[GAPBUFSIZE];

  memset(buf,0,GAPBUFSIZE);
  do
    fwritex(f,buf,bytes>GAPBUFSIZE?GAPBUFSIZE:bytes);
  while ((bytes-=GAPBUFSIZE) > 0);
}


unsigned long elf_hash(const char *_name)
/* calculate a hash code as used in ELF objects */
{
  const unsigned char *name=(const unsigned char *)_name;
  unsigned long h=0,g;

  while (*name) {
    h = (h << 4) + *name++;
    if (g = h & 0xf0000000)
      h ^= g >> 24;
    h &= ~g;
  }
  return h;
}


unsigned long align(unsigned long addr,unsigned long alignment)
/* return number of bytes required to achieve alignment */
{
  unsigned long a = (1<<alignment) - 1;

  return ((addr+a)&~a) - addr;
}


unsigned long comalign(unsigned long addr,unsigned long a)
/* return number of bytes required to achieve alignment */
{
  return ((addr+a-1)&~(a-1)) - addr;
}


int shiftcnt(uint32_t x)
/* returns number of 0-bits before the first 1-bit - something like */
/* an integer-log2() function - returns 0 on x=0 */
{
  int i;

  if (x == 0)
    return 0;
  for (i=0; i<32; i++) {
    if (x & 1)
      break;
    x >>= 1;
  }
  return i;
}


int lshiftcnt(lword x)
/* shiftcnt() of an lword */
{
  int i,n=sizeof(lword)<<3;

  if (x == 0)
    return 0;
  for (i=0; i<n; i++) {
    if (x & 1)
      break;
    x >>= 1;
  }
  return i;
}


void memset16(struct GlobalVars *gv,void *start,uint16_t fill,long n)
{
  if (n > 0) {
    uint8_t f[2];
    uint8_t *p;
    int i;

    write16(fff[gv->dest_format]->endianess==_BIG_ENDIAN_,f,fill);
    for (p=start,i=((unsigned long)start)&1; n; n--,i^=1)
      *p++ = f[i];
  }
}


lword sign_extend(lword v,int n)
/* sign-extend an n-bit value to lword-size */
{
  if (v & (1LL<<(n-1)))
    v |= ~makemask(n);

  return v;
}


void add_symnames(struct SymNames **snlist,const char *name)
/* add a new name to a SymNames list */
{
  struct SymNames *new = alloc(sizeof(struct SymNames));
  struct SymNames *sn;

  new->next = NULL;
  new->name = name;
  if (sn = *snlist) {
    while (sn->next)
      sn = sn->next;
    sn->next = new;
  }
  else
    *snlist = new;
}
