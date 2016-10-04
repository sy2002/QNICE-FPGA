/* $VER: vlink t_rawbin.c V0.14b (28.07.13)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2013  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2013 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#include "config.h"
#if defined(RAWBIN1) || defined(RAWBIN2) || \
    defined(SREC19) || defined(SREC28) || defined(SREC37) || \
    defined(IHEX) || defined(SHEX1) || defined(AMSDOS) || defined(CBMPRG)
#define T_RAWBIN_C
#include "vlink.h"

#define MAXGAP 16  /* from MAXGAP bytes on, a new file will be created */
#define MAXSREC 32 /* max. number of bytes in an S1/S2/S3 record */
#define MAXIREC 32 /* max. number of bytes in an ihex record (actually 255) */


static unsigned long rawbin_headersize(struct GlobalVars *);
static int rawbin_identify(char *,uint8_t *,unsigned long,bool);
static void rawbin_readconv(struct GlobalVars *,struct LinkFile *);
static int rawbin_targetlink(struct GlobalVars *,struct LinkedSection *,
                              struct Section *);
static void rawbin_writeobject(struct GlobalVars *,FILE *);
static void rawbin_writeshared(struct GlobalVars *,FILE *);
static void rawbin_writeexec(struct GlobalVars *,FILE *,bool,char);
#ifdef RAWBIN1
static void rawbin_writesingle(struct GlobalVars *,FILE *);
#endif
#ifdef RAWBIN2
static void rawbin_writemultiple(struct GlobalVars *,FILE *);
#endif
#ifdef AMSDOS
static unsigned long amsdos_headersize(struct GlobalVars *);
static void amsdos_write(struct GlobalVars *,FILE *);
#endif
#ifdef CBMPRG
static unsigned long cbmprg_headersize(struct GlobalVars *);
static void cbmprg_write(struct GlobalVars *,FILE *);
#endif
#ifdef SREC19
static void srec19_write(struct GlobalVars *,FILE *);
#endif
#ifdef SREC28
static void srec28_write(struct GlobalVars *,FILE *);
#endif
#ifdef SREC37
static void srec37_write(struct GlobalVars *,FILE *);
#endif
#ifdef IHEX
static void ihex_write(struct GlobalVars *,FILE *);
#endif
#ifdef SHEX1
static void shex1_write(struct GlobalVars *,FILE *);
#endif

static const char defaultscript[] =
  "SECTIONS {\n"
  "  .text: { *(.text CODE text) *(seg*) *(.rodata*) }\n"
  "  .data: { *(.data DATA data) }\n"
  "  .bss: { *(.bss BSS bss) *(COMMON) }\n"
  "  .comment 0 : { *(.comment) }\n"
  "}\n";


#ifdef RAWBIN1
struct FFFuncs fff_rawbin1 = {
  "rawbin1",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  rawbin_writesingle,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32,
  FFF_SECTOUT
};
#endif

#ifdef RAWBIN2
struct FFFuncs fff_rawbin2 = {
  "rawbin2",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  rawbin_writemultiple,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32,
  FFF_SECTOUT
};
#endif

#ifdef AMSDOS
static const char amsdosscript[] =
  "MEMORY {\n"
  "  m: org=., len=0x10000-.\n"
  "  b1: org=0x4000, len=0x4000\n"
  "  b2: org=0x4000, len=0x4000\n"
  "  b3: org=0x4000, len=0x4000\n"
  "  b4: org=0x4000, len=0x4000\n"
  "}\n"
  "SECTIONS {\n"
  "  bin: { *(.text) *(.rodata*) *(.data*) *(.bss) *(COMMON) } > m\n"
  "  c4 : { *(.c4) } > b1 AT> m\n"
  "  c5 : { *(.c5) } > b2 AT> m\n"
  "  c6 : { *(.c6) } > b3 AT> m\n"
  "  c7 : { *(.c7) } > b4 AT> m\n"
  "}\n";

struct FFFuncs fff_amsdos = {
  "amsdos",
  amsdosscript,
  NULL,
  amsdos_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  amsdos_write,
  NULL,NULL,
  0,
  0,
  0,
  0,
  RTAB_UNDEF,0,
  0, /* little endian */
  16,
  FFF_SECTOUT
};
#endif

#ifdef CBMPRG
struct FFFuncs fff_cbmprg = {
  "cbmprg",
  defaultscript,
  NULL,
  cbmprg_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  cbmprg_write,
  NULL,NULL,
  0,
  0,
  0,
  0,
  RTAB_UNDEF,0,
  0, /* little endian */
  16,
  FFF_SECTOUT
};
#endif

#ifdef SREC19
struct FFFuncs fff_srec19 = {
  "srec19",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  srec19_write,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32
};
#endif

#ifdef SREC28
struct FFFuncs fff_srec28 = {
  "srec28",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  srec28_write,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32
};
#endif

#ifdef SREC37
struct FFFuncs fff_srec37 = {
  "srec37",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  srec37_write,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32
};
#endif

#ifdef IHEX
struct FFFuncs fff_ihex = {
  "ihex",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  ihex_write,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32
};
#endif

#ifdef SHEX1
struct FFFuncs fff_shex1 = {
  "oilhex",
  defaultscript,
  NULL,
  rawbin_headersize,
  rawbin_identify,
  rawbin_readconv,
  NULL,
  rawbin_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawbin_writeobject,
  rawbin_writeshared,
  shex1_write,
  NULL,NULL,
  0,
  0x8000,
  0,
  0,
  RTAB_UNDEF,0,
  -1, /* endianess undefined, only write */
  32
};
#endif


/*****************************************************************/
/*                        Read Binary                            */
/*****************************************************************/


static unsigned long rawbin_headersize(struct GlobalVars *gv)
{
  return 0;  /* no header - it's pure binary! */
}


#ifdef AMSDOS
static unsigned long amsdos_headersize(struct GlobalVars *gv)
{
  return 128;
}
#endif


#ifdef CBMPRG
static unsigned long cbmprg_headersize(struct GlobalVars *gv)
{
  return 2;
}
#endif


static int rawbin_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify a binary file */
{
  return ID_UNKNOWN;  /* binaries are only allowed to be written! */
}


static void rawbin_readconv(struct GlobalVars *gv,struct LinkFile *lf)
{
  ierror("rawbin_readconv(): Can't read raw-binaries");
}


static int rawbin_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                             struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  ierror("rawbin_targetlink(): Impossible to link raw-binaries");
  return 0;
}



/*****************************************************************/
/*                        Write Binary                           */
/*****************************************************************/

static struct LinkedSection *get_next_section(struct GlobalVars *gv)
/* returns pointer to next section with lowest base address */
{
  struct LinkedSection *ls = (struct LinkedSection *)gv->lnksec.first;
  struct LinkedSection *nextls,*minls = NULL;

  while (nextls = (struct LinkedSection *)ls->n.next) {
    if (minls) {
      if (ls->copybase < minls->copybase)
        minls = ls;
    }
    else
      minls = ls;
    ls = nextls;
  }
  if (minls) {
    remnode(&minls->n);
  }
  return minls;
}


#ifdef AMSDOS
static void amsdos_header(FILE *f,uint16_t loadaddr,uint16_t execaddr,
                          unsigned size)
{
  uint8_t buffer[128];
  uint16_t checksum;
  int i;

  memset(buffer,0,128);                 /* initialize header with zeros */
  memset(&buffer[1],' ',11);            /*  1 > 11: spaces */
  buffer[18] = 2;                       /* 18     : filetype = 2 - binary */
  write16le(&buffer[19],size);          /* 19 > 20: data length */
  write16le(&buffer[21],loadaddr);      /* 21 > 22: load address */
  buffer[23] = 0xff;                    /* 23     : 0xFF */
  write16le(&buffer[24],size);          /* 24 > 25: logical length */
  write16le(&buffer[26],execaddr);      /* 26 > 27: entry point */
  write32le(&buffer[64],size);          /* 64 > 66: filesize (3 bytes) */
  for (checksum=0,i=0; i<67; i++)
    checksum += buffer[i];
  write16le(&buffer[67],checksum);      /* 67 > 68: checksum */
  fwritex(f,buffer,128);
}
#endif


static void rawbin_writeheader(struct GlobalVars *gv,FILE *f,
                               struct LinkedSection *ls,char header)
{
  /* write a header, when needed */
#ifdef AMSDOS
  if (header == 'a')  /* Amstrad/Schneider CPC */
    amsdos_header(f,ls->copybase,entry_address(gv),ls->filesize);
#endif
#ifdef CBMPRG
  if (header == 'c')  /* Commodore PET, VIC-20, 64, etc. */
    fwrite16le(f,ls->copybase);
#endif
}


static void rawbin_writeexec(struct GlobalVars *gv,FILE *f,bool singlefile,
                             char header)
/* creates executable raw-binary files (with absolute addresses) */
{
  FILE *firstfile = f;
  bool firstsec = TRUE;
  unsigned long addr;
  struct LinkedSection *ls,*prevls;
  char *name;

  while (ls = get_next_section(gv)) {
    if (ls->size==0 || !(ls->flags & SF_ALLOC) || (ls->ld_flags & LSF_NOLOAD))
      continue;  /* ignore empty sections */

    /* resolve all relocations */
    calc_relocs(gv,ls);

    if (gv->output_sections) {
      /* make a new file for each output section */
      if (gv->trace_file)
        fprintf(gv->trace_file,"Base address section %s = 0x%08lx.\n",
                ls->name,ls->copybase);
      if (f != NULL)
        fclose(f);
      if (gv->osec_base_name != NULL) {
        /* use a common base name before the section name */
        name = alloc(strlen(gv->osec_base_name)+strlen(ls->name)+2);
        sprintf(name,"%s.%s",gv->osec_base_name,ls->name);
      }
      else
        name = (char *)ls->name;
      if (!(f = fopen(name,"wb"))) {
        error(29,name);
        break;
      }
      if (gv->osec_base_name != NULL)
        free(name);
      rawbin_writeheader(gv,f,ls,header);
    }
    else if (firstsec) {
      if (gv->trace_file)
        fprintf(gv->trace_file,"Base address = 0x%08lx.\n",ls->copybase);
      firstsec = FALSE;
      rawbin_writeheader(gv,f,ls,header);
    }
    else {
      /* handle gaps between this and the previous section */
      if (ls->copybase > addr) {
        if (ls->copybase-addr < MAXGAP || singlefile) {
          fwritegap(f,ls->copybase-addr);
        }
        else {  /* open a new file for this section */
          if (f != firstfile)
            fclose(f);
          name = alloc(strlen(gv->dest_name)+strlen(ls->name)+2);
          sprintf(name,"%s.%s",gv->dest_name,ls->name);
          if (!(f = fopen(name,"wb"))) {
            error(29,name);
            break;
          }
          free(name);
          rawbin_writeheader(gv,f,ls,header);
        }
      }
      else if (ls->copybase < addr)
        error(98,fff[gv->dest_format]->tname,ls->name,prevls->name);
    }

    /* write section contents */
    fwritex(f,ls->data,ls->filesize);
    if (ls->filesize < ls->size)
      fwritegap(f,ls->size - ls->filesize);

    addr = ls->copybase + ls->size;
    prevls = ls;
  }

  if (f!=NULL && f!=firstfile)
    fclose(f);
}


static void rawbin_writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void rawbin_writeobject(struct GlobalVars *gv,FILE *f)
{
  error(62);  /* Target file format doesn't support relocatable objects */
}


#ifdef RAWBIN1
static void rawbin_writesingle(struct GlobalVars *gv,FILE *f)
/* creates a single raw-binary file, fill gaps between */
/* sections with zero */
{
  rawbin_writeexec(gv,f,TRUE,0);
}
#endif


#ifdef RAWBIN2
static void rawbin_writemultiple(struct GlobalVars *gv,FILE *f)
/* creates raw-binary which might get splitted over several */
/* files, because of different section base addresses */
{
  rawbin_writeexec(gv,f,FALSE,0);
}
#endif


#ifdef AMSDOS
static void amsdos_write(struct GlobalVars *gv,FILE *f)
/* creates one or more raw-binary files with an AMSDOS header, suitable */
/* for loading as an executable on Amstrad/Scheider CPC computers */
{
  rawbin_writeexec(gv,f,FALSE,'a');
}
#endif


#ifdef CBMPRG
static void cbmprg_write(struct GlobalVars *gv,FILE *f)
/* creates one or more raw-binary files with a Commodore header, suitable */
/* for loading as an executable on PET, VIC-20, 64, etc. computers */
{
  rawbin_writeexec(gv,f,FALSE,'c');
}
#endif


#if defined(SREC19) || defined(SREC28) || defined(SREC37)
static void SRecOut(FILE *f,int stype,uint8_t *buf,int len)
{
  uint8_t chksum = 0xff-len-1;

  fprintf(f,"S%1d%02X",stype,(unsigned)(len+1));
  for (; len>0; len--) {
    fprintf(f,"%02X",(unsigned)*buf);
    chksum -= *buf++;
  }
  fprintf(f,"%02X\n",(unsigned)chksum);
}


static void srec_write(struct GlobalVars *gv,FILE *f,int addrsize)
{
  bool firstsec = TRUE;
  struct LinkedSection *ls;
  unsigned long len,addr;
  uint8_t *p,buf[MAXSREC+8];

  /* write header */
  buf[0] = buf[1] = 0;
  strncpy((char *)&buf[2],gv->dest_name,MAXSREC+6);
  SRecOut(f,0,buf,(strlen(gv->dest_name)<(MAXSREC+6)) ?
          strlen(gv->dest_name)+2 : MAXSREC+8);

  while (ls = get_next_section(gv)) {
    if (ls->size == 0 || !(ls->flags & SF_ALLOC) || (ls->ld_flags & LSF_NOLOAD))
      continue;  /* ignore empty sections */

    if (firstsec) {
      if (gv->trace_file)
        fprintf(gv->trace_file,"Base address = 0x%08lx.\n",ls->copybase);
      firstsec = FALSE;
    }

    /* resolve all relocations and write section contents */
    calc_relocs(gv,ls);

    for (p=ls->data,addr=ls->copybase,len=ls->filesize; len>0; ) {
      int nbytes = (len>MAXSREC) ? MAXSREC : len;

      switch (addrsize) {
        case 2:
          write16be(buf,(uint16_t)addr);
          memcpy(buf+2,p,nbytes);
          SRecOut(f,1,buf,2+nbytes);
          break;
        case 3:
          buf[0] = (uint8_t)((addr>>16)&0xff);
          buf[1] = (uint8_t)((addr>>8)&0xff);
          buf[2] = (uint8_t)(addr&0xff);
          memcpy(buf+3,p,nbytes);
          SRecOut(f,2,buf,3+nbytes);
          break;
        case 4:
          write32be(buf,(uint32_t)addr);
          memcpy(buf+4,p,nbytes);
          SRecOut(f,3,buf,4+nbytes);
          break;
        default:
          ierror("srec_write(): Illegal SRec-type: %d",addrsize);
          nbytes = len;
          break;
      }
      p += nbytes;
      addr += nbytes;
      len -= nbytes;
    }
  }

  /* write trailer */
  memset(buf,0,4);
  SRecOut(f,11-addrsize,buf,addrsize);
}

#endif


#ifdef SREC19
static void srec19_write(struct GlobalVars *gv,FILE *f)
/* creates a Motorola S-Record file (S0,S1,S9), using 16-bit addresses */
{
  srec_write(gv,f,2);
}
#endif


#ifdef SREC28
static void srec28_write(struct GlobalVars *gv,FILE *f)
/* creates a Motorola S-Record file (S0,S2,S8), using 24-bit addresses */
{
  srec_write(gv,f,3);
}
#endif


#ifdef SREC37
static void srec37_write(struct GlobalVars *gv,FILE *f)
/* creates a Motorola S-Record file (S0,S3,S7), using 32-bit addresses */
{
  srec_write(gv,f,4);
}
#endif


#ifdef IHEX
static void IHexOut(FILE *f,unsigned long addr,uint8_t *buf,int len)
{
  static unsigned long hiaddr;
  uint8_t chksum;

  if (((addr&0xffff0000)>>16)!=hiaddr) {
    hiaddr = (addr&0xffff0000) >> 16;
    fprintf(f,":02000004%02X%02X%02X\n",
            (unsigned)(hiaddr>>8)&0xff,
            (unsigned)hiaddr&0xff,
            (unsigned)(-(2+4+(hiaddr>>8)+hiaddr))&0xff);
  }
  fprintf(f,":%02X%02X%02X00",
          (unsigned)len&0xff,(unsigned)(addr>>8)&0xff,(unsigned)addr&0xff);
  chksum = len + (addr>>8) + addr;
  for (; len>0; len--) {
    fprintf(f,"%02X",((unsigned)*buf)&0xff);
    chksum += *buf++;
  }
  fprintf(f,"%02X\n",(-chksum)&0xff);
}


static void ihex_write(struct GlobalVars *gv,FILE *f)
{
  bool firstsec = TRUE;
  struct LinkedSection *ls;
  unsigned long len,addr;
  uint8_t *p;

  while (ls = get_next_section(gv)) {
    if (ls->size == 0 || !(ls->flags & SF_ALLOC) || (ls->ld_flags & LSF_NOLOAD))
      continue;  /* ignore empty sections */

    if (firstsec) {
      if (gv->trace_file)
        fprintf(gv->trace_file,"Base address = 0x%08lx.\n",ls->copybase);
      firstsec = FALSE;
    }

    /* resolve all relocations and write section contents */
    calc_relocs(gv,ls);

    for (p=ls->data,addr=ls->copybase,len=ls->filesize; len>0; ) {
      int nbytes = (len>MAXIREC) ? MAXIREC : len;

      if ((((unsigned long)addr)&0xffff)+nbytes > 0xffff)
        nbytes = 0x10000 - (((unsigned long)addr) & 0xffff);
      IHexOut(f,addr,p,nbytes);
      p += nbytes;
      addr += nbytes;
      len -= nbytes;
    }
  }

  fprintf(f,":00000001FF\n");
}
#endif

#ifdef SHEX1
static void SHex1Out(FILE *f,unsigned long addr,uint8_t *buf,int len)
{
  int wordcnt=(len+3)/4;
  int i;

  fprintf(f,"%06lX %d",addr,wordcnt);

  for(i=0;i<len;i++){
    if((i&3)==0)
      fprintf(f," ");
    fprintf(f,"%02X",buf[i]);
  }
  for(i=0;i<wordcnt*4-len;i++)
    fprintf(f,"00");
  fprintf(f,"\n");
}


static void shex1_write(struct GlobalVars *gv,FILE *f)
{
  bool firstsec = TRUE;
  struct LinkedSection *ls;
  unsigned long len,addr;
  uint8_t *p;

  while (ls = get_next_section(gv)) {
    if (ls->size == 0 || !(ls->flags & SF_ALLOC) || (ls->ld_flags & LSF_NOLOAD))
      continue;  /* ignore empty sections */

    if (firstsec) {
      if (gv->trace_file)
        fprintf(gv->trace_file,"Base address = 0x%08lx.\n",ls->copybase);
      firstsec = FALSE;
    }

    /* resolve all relocations and write section contents */
    calc_relocs(gv,ls);

    for (p=ls->data,addr=ls->copybase,len=ls->filesize; len>0; ) {
      int nbytes = (len>32) ? 32 : len;

      SHex1Out(f,addr,p,nbytes);
      p += nbytes;
      addr += nbytes;
      len -= nbytes;
    }
  }
  fprintf(f,"000000 0\n");
}
#endif


#endif
