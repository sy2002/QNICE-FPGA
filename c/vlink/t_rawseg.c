/* $VER: vlink t_rawseg.c V0.14b (17.02.13)
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
#if defined(RAWSEG)
#define T_RAWSEG_C
#include "vlink.h"
#include "elfcommon.h"


struct SegReloc {
  struct SegReloc *next;
  struct Phdr *seg;
  unsigned long offset;
};


static unsigned long rawseg_headersize(struct GlobalVars *);
static int rawseg_identify(char *,uint8_t *,unsigned long,bool);
static void rawseg_readconv(struct GlobalVars *,struct LinkFile *);
static int rawseg_targetlink(struct GlobalVars *,struct LinkedSection *,
                              struct Section *);
static void rawseg_writeobject(struct GlobalVars *,FILE *);
static void rawseg_writeshared(struct GlobalVars *,FILE *);
static void rawseg_writeexec(struct GlobalVars *,FILE *);

static const char defaultscript[] =
  "PHDRS {\n"
  "  text PT_LOAD;\n"
  "  data PT_LOAD;\n"
  "}\n"
  "SECTIONS {\n"
  "  .text: { *(.text*) *(CODE*) *(text*) *(seg*) } :text\n"
  "  .data: { *(.data*) *(DATA*) *(data*) } :data\n"
  "  .bss: { *(.bss*) *(BSS*) *(bss*) }\n"
  "}\n";


#ifdef RAWSEG
struct FFFuncs fff_rawseg = {
  "rawseg",
  defaultscript,
  NULL,
  rawseg_headersize,
  rawseg_identify,
  rawseg_readconv,
  NULL,
  rawseg_targetlink,
  NULL,
  NULL,
  NULL,
  NULL,NULL,NULL,
  rawseg_writeobject,
  rawseg_writeshared,
  rawseg_writeexec,
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


static unsigned long rawseg_headersize(struct GlobalVars *gv)
{
  return 0;  /* no header - it's pure binary! */
}


static int rawseg_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify a binary file */
{
  return ID_UNKNOWN;  /* binaries are only allowed to be written! */
}


static void rawseg_readconv(struct GlobalVars *gv,struct LinkFile *lf)
{
  ierror("rawseg_readconv(): Can't read raw-binaries");
}


static int rawseg_targetlink(struct GlobalVars *gv,struct LinkedSection *ls,
                             struct Section *s)
/* returns 1, if target requires the combination of the two sections, */
/* returns -1, if target doesn't want to combine them, */
/* returns 0, if target doesn't care - standard linking rules are used. */
{
  ierror("rawseg_targetlink(): Impossible to link raw-binaries");
  return 0;
}


/*****************************************************************/
/*                        Write Binary                           */
/*****************************************************************/

static void rawseg_writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void rawseg_writeobject(struct GlobalVars *gv,FILE *f)
{
  error(62);  /* Target file format doesn't support relocatable objects */
}


static void rawseg_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a new file for each segment, writes file name, start address */
/* and length into the output file */
{
  const char *fn = "rawseg_writeexec(): ";
  bool firstsec;
  unsigned long addr;
  FILE *segf;
  struct Phdr *p;
  struct LinkedSection *ls,*prevls;
  struct SegReloc *srlist;
  char buf[256];

  for (p=gv->phdrlist; p; p=p->next) {
    if (p->type==PT_LOAD && (p->flags&PHDR_USED) &&
        p->start!=ADDR_NONE && p->start_vma!=ADDR_NONE) {

      firstsec = TRUE;
      srlist = NULL;
      snprintf(buf,256,"%s.%s",gv->dest_name,p->name);
      segf = fopen(buf,"wb");
      if (segf == NULL) {
        error(29,buf);  /* cannot create file */
        continue;
      }

      /* write file name, start address and length of segment to output */
      fprintf(f,"\"%s\" 0x%llx 0x%llx\n",buf,p->start,p->mem_end-p->start);

      /* write segment's sections */
      for (ls=(struct LinkedSection *)gv->lnksec.first;
           ls->n.next!=NULL; ls=(struct LinkedSection *)ls->n.next) {
        if (ls->copybase>=(unsigned long)p->start &&
            (ls->copybase+ls->size)<=(unsigned long)p->mem_end &&
            (ls->flags & SF_ALLOC)) {

          if (gv->keep_relocs) {
            /* remember relocations, adjusted from section to segment base */
            struct Reloc *r;
            struct RelocInsert *ri;
            struct LinkedSection *relsec;
            struct Phdr *relph;

            for (r=(struct Reloc *)ls->relocs.first;
                 r->n.next!=NULL; r=(struct Reloc *)r->n.next) {
              if (ri = r->insert) {
                if (r->rtype!=R_ABS || ri->bpos!=0 || ri->bsiz!=32) {
                  /* only absolute 32-bit relocs are supported */
                  error(32,fff_rawseg.tname,reloc_name[r->rtype],
                        (int)ri->bpos,(int)ri->bsiz,ri->mask,
                        ls->name,r->offset);
                  continue;
                }
              }
              else
                continue;

              if (r->relocsect.lnk == NULL) {
                if (r->flags & RELF_DYNLINK)
                  continue;  /* NULL, because it was resolved by a sh.obj. */
                else
                  ierror("%sReloc type %d (%s) at %s+0x%lx "
                         "(addend 0x%llx) is missing a relocsect.lnk",
                         fn,(int)r->rtype,reloc_name[r->rtype],ls->name,
                         r->offset,r->addend);
              }
              relsec = r->relocsect.lnk;

              /* find out to which segment relsec belongs */
              for (relph=gv->phdrlist; relph; relph=relph->next) {
                if (relph->type==PT_LOAD && (relph->flags&PHDR_USED) &&
                    relph->start!=ADDR_NONE && relph->start_vma!=ADDR_NONE) {
                  if (relsec->copybase>=(unsigned long)relph->start &&
                      (relsec->copybase+relsec->size)<=
                      (unsigned long)relph->mem_end &&
                      (relsec->flags & SF_ALLOC))
                    break;
                }
              }
              /* use segment's base address for relocation instead */
              if (relph) {
                lword segoffs,a,v;
                struct SegReloc *newsr,*srp;

                segoffs = (lword)relsec->copybase - relph->start;
                v = writesection(gv,ls->data+r->offset,r,r->addend+segoffs);
                if (v != 0) {
                  /* Calculated value doesn't fit into relocation type x ... */
                  if (ri = r->insert)
                    error(35,gv->dest_name,ls->name,r->offset,v,
                          reloc_name[r->rtype],(int)ri->bpos,
                          (int)ri->bsiz,ri->mask);
                  else
                    ierror("%sReloc (%s+%lx), type=%s, without RelocInsert",
                           fn,ls->name,r->offset,reloc_name[r->rtype]);
                }

                /* remember relocation offset and segment for later */
                newsr = alloc(sizeof(struct SegReloc));
                newsr->next = NULL;
                newsr->seg = relph;
                newsr->offset = (ls->copybase - (unsigned long)p->start) +
                                r->offset;
                if (srp = srlist) {
                  while (srp->next)
                    srp = srp->next;
                  srp->next = newsr;
                }
                else
                  srlist = newsr;
              }
              else
                ierror("%sNo segment for reloc offset section '%s'",
                       fn,relsec->name);
            }
          }
          else
            calc_relocs(gv,ls);

          if (!firstsec) {
            /* write an alignment gap, when needed */
            if (ls->copybase > addr)
              fwritegap(segf,ls->copybase-addr);
            else if (ls->copybase < addr)
              error(98,fff[gv->dest_format]->tname,ls->name,prevls->name);
          }
          else
            firstsec = FALSE;

          fwritex(segf,ls->data,ls->size);

          addr = ls->copybase + ls->size;
          prevls = ls;
        }
      }
      fclose(segf);

      if (srlist) {
        /* write relocation files for this segment */
        struct Phdr *relph;
        struct SegReloc *sr;
        uint32_t rcnt;
        FILE *rf;

        for (relph=gv->phdrlist; relph; relph=relph->next) {
          for (sr=srlist,rf=NULL,rcnt=0; sr; sr=sr->next) {
            if (sr->seg == relph) {
              if (!rf) {
                snprintf(buf,256,"%s.%s.rel%s",
                         gv->dest_name,p->name,relph->name);
                rf = fopen(buf,"wb");
                if (rf == NULL) {
                  error(29,buf);  /* cannot create file */
                  continue;
                }
                fwritegap(rf,4);  /* number of relocs will be stored here */
              }
              if (gv->endianess == _BIG_ENDIAN_)
                fwrite32be(rf,sr->offset);
              else
                fwrite32le(rf,sr->offset);
              rcnt++;
            }
          }
          if (rf) {
            /* write number of relocs into the first word */
            fseek(rf,0,SEEK_SET);
            if (gv->endianess == _BIG_ENDIAN_)
              fwrite32be(rf,rcnt);
            else
              fwrite32le(rf,rcnt);
            fclose(rf);
          }
        }
      }
    }
  }
}

#endif
