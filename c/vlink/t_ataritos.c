/* $VER: vlink t_ataritos.c V0.15a (16.05.15)
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
#ifdef ATARI_TOS
#define T_ATARITOS_C
#include "vlink.h"
#include "tosdefs.h"


static int identify(char *,uint8_t *,unsigned long,bool);
static void readconv(struct GlobalVars *,struct LinkFile *);
static int targetlink(struct GlobalVars *,struct LinkedSection *,
                      struct Section *);
static unsigned long headersize(struct GlobalVars *);
static void writeobject(struct GlobalVars *,FILE *);
static void writeshared(struct GlobalVars *,FILE *);
static void writeexec(struct GlobalVars *,FILE *);


struct FFFuncs fff_ataritos = {
  "ataritos",
  defaultscript,
  NULL,
  headersize,
  identify,
  readconv,
  NULL,
  targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  writeobject,
  writeshared,
  writeexec,
  bss_name,NULL,
  0,
  0x7ffe,
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};



/*****************************************************************/
/*                       Read Atari TOS                          */
/*****************************************************************/


static int identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify a TOS file */
{
  return ID_UNKNOWN;  /* @@@ no read-support at the moment */
}


static void readconv(struct GlobalVars *gv,struct LinkFile *lf)
{
  ierror("readconv(): Can't read Atari TOS");
}



/*****************************************************************/
/*                       Link Atari TOS                          */
/*****************************************************************/


static int targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                      struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  /* TOS requires that all sections of type CODE or DATA or BSS */
  /* will be combined, because there are only those three available! */
  if (ls->type == s->type)
    return 1;

  return 0;
}



/*****************************************************************/
/*                      Write Atari TOS                          */
/*****************************************************************/


static int tos_initwrite(struct GlobalVars *gv,
                         struct LinkedSection **sections)
/* find exactly one ST_CODE, ST_DATA and ST_UDATA section, which
   will become .text, .data and .bss,
   then count the number of symbol definitions and references */
{
  static const char *fn = "tos_initwrite(): ";
  struct LinkedSection *ls;
  struct Symbol *sym;
  struct Reloc *xref;
  int i,cnt;

  get_text_data_bss(gv,sections);

  /* count symbols and unresolved references */
  for (i=0,cnt=0; i<3; i++) {
    if (sections[i]) {
      for (sym=(struct Symbol *)sections[i]->symbols.first;
           sym->n.next!=NULL; sym=(struct Symbol *)sym->n.next) {
        if (!discard_symbol(gv,sym)) {
          ++cnt;
          if (strlen(sym->name) > DRI_NAMELEN)
            ++cnt;  /* extra symbol for long name */
        }
      }
      if (gv->dest_object) {
        for (xref=(struct Reloc *)sections[i]->xrefs.first;
             xref->n.next!=NULL; xref=(struct Reloc *)xref->n.next) {
          ++cnt;
          if (strlen(xref->xrefname) > DRI_NAMELEN)
            ++cnt;  /* extra symbol for long name */
        }
      }
    }
  }

  text_data_bss_gaps(sections);  /* calculate gap size between sections */

  return cnt;
}


static void tos_header(FILE *f,unsigned long tsize,unsigned long dsize,
                       unsigned long bsize,unsigned long ssize,
                       unsigned long flags)
{
  PH hdr;

  write16be(hdr.ph_branch,0x601a);
  write32be(hdr.ph_tlen,tsize);
  write32be(hdr.ph_dlen,dsize);
  write32be(hdr.ph_blen,bsize);
  write32be(hdr.ph_slen,ssize);
  write32be(hdr.ph_magic,0);
  write32be(hdr.ph_flags,flags);
  write16be(hdr.ph_abs,0);

  fwritex(f,&hdr,sizeof(PH));
}


static void write_dri_sym(FILE *f,const char *name,
                          uint16_t type,uint32_t value)
{
  struct DRIsym stab;
  int longname = strlen(name) > DRI_NAMELEN;

  strncpy(stab.name,name,DRI_NAMELEN);
  write16be(stab.type,longname?(type|STYP_LONGNAME):type);
  write32be(stab.value,value);
  fwritex(f,&stab,sizeof(struct DRIsym));

  if (longname) {
    char rest_of_name[sizeof(struct DRIsym)];

    memset(rest_of_name,0,sizeof(struct DRIsym));
    strncpy(rest_of_name,name+DRI_NAMELEN,sizeof(struct DRIsym));
    fwritex(f,rest_of_name,sizeof(struct DRIsym));
  }
}


static void tos_symboltable(struct GlobalVars *gv,FILE *f,
                            struct LinkedSection **sections)
{
  struct Symbol *sym;
  struct Reloc *xref;
  int i;

  for (i=0; i<3; i++) {
    if (sections[i]) {
      for (sym=(struct Symbol *)sections[i]->symbols.first;
           sym->n.next!=NULL; sym=(struct Symbol *)sym->n.next) {
        if (!discard_symbol(gv,sym)) {
          uint32_t val = sym->value;
          uint16_t t;

          if (sym->type == SYM_ABS) {
            t = STYP_EQUATED;
          }
          else if (sym->type != SYM_COMMON) {
            if (!gv->textbasedsyms)
              val -= sections[i]->base;  /* symbol value as section offset */
            switch (i) {
              case 0: t = STYP_TEXT; break;
              case 1: t = STYP_DATA; break;
              case 2: t = STYP_BSS; break;
            }
          }
          else
            ierror("tos_symboltable(): Common symbol <%s> not supported",
                   sym->name);

          t |= STYP_DEFINED;
          if (sym->bind > SYMB_LOCAL)
            t |= STYP_GLOBAL;

          write_dri_sym(f,sym->name,t,val);
          /* FIXME: symbols in DRI objects do not sypport long names. */
        }
      }

      if (gv->dest_object) {
        for (xref=(struct Reloc *)sections[i]->xrefs.first;
             xref->n.next!=NULL; xref=(struct Reloc *)xref->n.next) {
          /* This is what Devpac does. Relocations and external
             reference types for each word are located after the symbols.
             @@@ WARNING! Relocation and reference table is still missing.
             Reengineered DRI Format of this table (not yet implemented):
             One type-word for each word in a section.
             0x0000 no reloation or reference
             0x0001 data relocation
             0x0002 text relocation
             0x0003 bss relocation
             0x0004 and greater (not 0x0005): external reference
               Bit 15-3: symbol table index of reference (starting with 0)
               Bit 2: always set for external reference
               Bit 1-0: 00 AbsRef, 01 illegal?, 10 PCRelRef, 11 unknown
             0x0005 32-bit prefix. Following word describes a relocation
                    or reference for the 32-bit longword at this position. */

          write_dri_sym(f,xref->xrefname,STYP_DEFINED|STYP_EXTERNAL,0);
          /* FIXME: external symbols do not sypport long names and must
             only appear once! */
        }
      }
    }
  }
}


void tos_writerelocs(struct GlobalVars *gv,FILE *f,
                     struct LinkedSection **sections)
{
  const char *fn = "tos_writerelocs(): ";
  int i;
  struct Reloc *rel;
  struct RelocInsert *ri;
  unsigned long lastoffs = 0;

  for (i=0; i<3; i++) {
    if (sections[i]) {
      sort_relocs(&sections[i]->relocs);
      for (rel=(struct Reloc *)sections[i]->relocs.first;
           rel->n.next!=NULL; rel=(struct Reloc *)rel->n.next) {
        if (ri = rel->insert) {
          if (rel->rtype!=R_ABS || ri->bpos!=0 || ri->bsiz!=32) {
            if (rel->rtype==R_ABS && (ri->bpos!=0 || ri->bsiz!=32))
              error(32,fff_ataritos.tname,reloc_name[rel->rtype],
                    (int)ri->bpos,(int)ri->bsiz,ri->mask,
                    sections[i]->name,rel->offset);
            continue;
          }
        }
        else
          continue;

        if (!lastoffs) {
          /* first relocation offset is 32 bits, the rest are bytes! */
          fwrite32be(f,sections[i]->base + rel->offset);
        }
        else {
          long diff = (sections[i]->base + rel->offset) - lastoffs;

          if (diff < 0) {
            ierror("%snegative offset difference: "
                   "%s(0x%08lx)+0x%08lx - 0x%08lx",fn,sections[i]->name,
                   sections[i]->base,rel->offset,lastoffs);
          }
          while (diff > 254) {
            fwrite8(f,1);
            diff -= 254;
          }
          fwrite8(f,(uint8_t)diff);
        }
        lastoffs = sections[i]->base + rel->offset;
      }
    }
  }

  if (!lastoffs) {
    /* not a single relocation written - write 0-word */
    fwrite32be(f,0);
  }
  else
    fwrite8(f,0);
}


static unsigned long headersize(struct GlobalVars *gv)
{
  return 0;  /* irrelevant */
}


static void writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void writeobject(struct GlobalVars *gv,FILE *f)
/* creates a TOS relocatable object file */
{
  ierror("Atari TOS object file generation has not yet been implemented");
}


static void writeexec(struct GlobalVars *gv,FILE *f)
/* creates a TOS executable file (which is relocatable) */
{
  struct LinkedSection *sections[3];
  int nsyms = tos_initwrite(gv,sections);
  int i;

  tos_header(f,sections[0] ? sections[0]->size+sections[0]->gapsize : 0,
             sections[1] ? sections[1]->size+sections[1]->gapsize : 0,
             sections[2] ? sections[2]->size : 0,
             (unsigned long)nsyms*sizeof(struct DRIsym),gv->tosflags);

  for (i=0; i<3; i++)
    calc_relocs(gv,sections[i]);

  if (sections[0]) {
    fwritex(f,sections[0]->data,sections[0]->filesize);
    fwritegap(f,(sections[0]->size-sections[0]->filesize)+sections[0]->gapsize);
  }

  if (sections[1]) {
    fwritex(f,sections[1]->data,sections[1]->filesize);
    fwritegap(f,(sections[1]->size-sections[1]->filesize)+sections[1]->gapsize);
  }

  if (nsyms)
    tos_symboltable(gv,f,sections);

  tos_writerelocs(gv,f,sections);
}


#endif
