/* $VER: vlink t_elf32arm.c V0.13 (02.11.10)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2010  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2010 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#include "config.h"
#if defined(ELF32_ARM_LE)
#define T_ELF32ARM_C
#include "vlink.h"
#include "elf32.h"
#include "rel_elfarm.h"


static int armle_identify(char *,uint8_t *,unsigned long,bool);
static void armle_readconv(struct GlobalVars *,struct LinkFile *);
static void armle_dyncreate(struct GlobalVars *);
static void armle_writeobject(struct GlobalVars *,FILE *);
static void armle_writeshared(struct GlobalVars *,FILE *);
static void armle_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_elf32armle = {
  "elf32armle",
  NULL,
  NULL,
  elf32_headersize,
  armle_identify,
  armle_readconv,
  NULL,
  elf_targetlink,
  NULL,
  elf_lnksym,
  elf_setlnksym,
  elf32_initdynlink,
  NULL,
  armle_dyncreate,
  armle_writeobject,
  armle_writeshared,
  armle_writeexec,
  bss_name,sbss_name,
  0x1000,
  0x1000, /* +/- 12-bit offset */
  0,
  0,
  RTAB_STANDARD,RTAB_STANDARD|RTAB_ADDEND,
  _LITTLE_ENDIAN_,
  32
};



/*****************************************************************/
/*                          Read ELF                             */
/*****************************************************************/


static int armle_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
/* identify ELF-ARM-32Bit-LittleEndian */
{
  return (elf_identify(&fff_elf32armle,name,p,plen,
                       ELFCLASS32,ELFDATA2LSB,EM_ARM,ELF_VER));
}


static uint8_t armle_reloc_elf2vlink(uint8_t rtype,struct RelocInsert *ri)
/* Determine vlink internal reloc type from ELF reloc type and fill in
   reloc-insert description informations.
   All fields of the RelocInsert structure are preset to zero. */
{
  /* Reloc conversion table for V.4-ABI - @@@ INCOMPLETE!!! */
  static struct ELF2vlink convertV4[] = {
    R_NONE,0,0,-1,
    R_PC,8,24,0x3fffffc,        /* PC24, deprecated! Use CALL or JUMP24! */
    R_ABS,0,32,-1,              /* ABS32 */
    R_PC,0,32,-1,               /* REL32 */
    R_PC,20,12,0x1fff,          /* LDR_PC_G0 */
    R_ABS,0,16,-1,              /* ABS16 */
    R_ABS,20,12,0xfff,          /* ABS12 */
    R_ABS,5,5,0x1f,             /* THM_ABS5 */
    R_ABS,0,8,-1,               /* ABS8 */
    R_SD,0,32,-1,               /* SBREL32 */
    R_PC,5,11,0,                /* THM_CALL, needs 2nd ri */
    R_PC,8,8,0x3fc,             /* THM_PC8 */
    R_NONE,0,0,-1,
    R_ABS,8,24,0xffffff,        /* SWI24, obsolete! */
    R_ABS,8,8,0xff,             /* THM_SWI8, obsolete! */
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_PC,8,24,0x3fffffc,        /* CALL, PC24 for uncond. bl/blx only */
    R_PC,8,24,0x3fffffc,        /* JUMP24, PC24 for other branches */
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_PC,24,8,0xff,             /* ALU_PCREL_7_0, obsolete! */
    R_PC,24,8,0xff00,           /* ALU_PCREL_15_8, obsolete! */
    R_PC,24,8,0xff0000,         /* ALU_PCREL_23_15, obsolete! */
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
    R_NONE,0,0,-1,
  };
  static struct RelocInsert ri2;

  if (rtype < R_ARM_V4BX) {
    ri->bpos = convertV4[rtype].bpos;
    ri->bsiz = convertV4[rtype].bsiz;
    if ((ri->mask = convertV4[rtype].mask) == 0) {
      /* needs a 2nd RelocInsert */
      memset(&ri2,0,sizeof(struct RelocInsert));
      ri->next = &ri2;
      if (rtype == R_ARM_THM_CALL) {
        /* a 23-bit branch consisting of two THUMB instruction */
        ri->mask = 0x7ff000;
        ri2.mask = 0xffe;
        ri2.bpos = 16+5;
        ri2.bsiz = 11;
      }
      else {
        ierror("armle_reloc_elf2vlink(): reloc %d unknown to expect "
               "a 2nd RelocInsert",rtype);
      }
    }
    return convertV4[rtype].rtype;
  }

  return R_NONE;
}


static void armle_readconv(struct GlobalVars *gv,struct LinkFile *lf)
/* Read ELF-ARM little-endian executable / object / shared obj. */
{
  if (lf->type == ID_LIBARCH) {
    struct ar_info ai;

    if (ar_init(&ai,(char *)lf->data,lf->length,lf->filename)) {
      while (ar_extract(&ai)) {
        lf->objname = allocstring(ai.name);
        elf_check_ar_type(fff[lf->format],lf->pathname,ai.data,
                          ELFCLASS32,ELFDATA2LSB,ELF_VER,1,EM_ARM);
        elf32_parse(gv,lf,(struct Elf32_Ehdr *)ai.data,armle_reloc_elf2vlink);
      }
    }
    else
      ierror("armle_readconv(): archive %s corrupted since last access",
             lf->pathname);
  }
  else {
    lf->objname = lf->filename;
    elf32_parse(gv,lf,(struct Elf32_Ehdr *)lf->data,armle_reloc_elf2vlink);
  }
}


static void armle_dyncreate(struct GlobalVars *gv)
{
  elf32_dyncreate(gv,plt_name);  /* @@@ correct? */
}



/*****************************************************************/
/*                          Write ELF                            */
/*****************************************************************/


static uint8_t armle_reloc_vlink2elf(struct Reloc *r)
/* Try to map vlink-internal representation to a valid ELF reloc type */
{
  struct RelocInsert *ri;

  if (ri = r->insert) {
    int pos = (int)ri->bpos;
    int size = (int)ri->bsiz;
    lword mask = ri->mask;
    struct RelocInsert *ri2 = ri->next;

    switch (r->rtype) {
      case R_ABS:
        if (!(pos&7) && mask==-1 && !ri2) {
          switch (size) {
            case 32: return R_ARM_ABS32;
            case 16: return R_ARM_ABS16;
            case 8: return R_ARM_ABS8;
          }
        }
        else if (size==24 && (pos&31)==8 && mask==0xffffff && !ri2)
          return R_ARM_SWI24; /* @@@ obsolete */
        else if (size==12 && (pos&31)==20 && mask==0xfff && !ri2)
          return R_ARM_ABS12;
        else if (size==8 && (pos&15)==8 && mask==0xff && !ri2)
          return R_ARM_THM_SWI8; /* @@@ obsolete */
        else if (size==5 && (pos&15)==5 && mask==0x1f && !ri2)
          return R_ARM_THM_ABS5;
        break;

      case R_PC:
        if (size==32 && !(pos&7) && mask==-1 && !ri2)
          return R_ARM_REL32;
        else if (size==24 && (pos&31)==8 && mask==0x3fffffc && !ri2)
          return R_ARM_PC24;  /* @@@ deprecated: use R_ARM_CALL/JUMP24!!! */
        else if (size==12 && (pos&31)==20 && mask==0x1fff && !ri2)
          return R_ARM_LDR_PC_G0;
        else if (size==8 && (pos&31)==24 && mask==0xff && !ri2)
          return R_ARM_ALU_PCREL_7_0;  /* @@@ obsolete */
        else if (size==8 && (pos&31)==24 && mask==0xff00 && !ri2)
          return R_ARM_ALU_PCREL_15_8;  /* @@@ obsolete */
        else if (size==8 && (pos&31)==24 && mask==0xff0000 && !ri2)
          return R_ARM_ALU_PCREL_23_15;  /* @@@ obsolete */
        else if (size==8 && (pos&15)==8 && mask==0x3fc && !ri2)
          return R_ARM_THM_PC8;
        else if (size==11 && (pos&15)==5 && ri2) {
          if (ri2->bsiz==11 && (ri2->bpos&15)==5) {
            if ((mask==0x7ff000 && ri2->mask==0xffe) ||
                (mask==0xffe && ri2->mask==0x7ff000))
              return R_ARM_THM_CALL;
          }
        }
        break;
    }
  }

  return R_NONE;
}


static void armle_writeshared(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32armle shared object (which is pos. independant) */
{
  ierror("armle_writeshared(): Shared object generation has not "
         "yet been implemented");
}


static void armle_writeobject(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32armle relocatable object file */
{
  elf32_writeobject(gv,f,EM_ARM,_LITTLE_ENDIAN_,armle_reloc_vlink2elf);
}


static void armle_writeexec(struct GlobalVars *gv,FILE *f)
/* creates a target-elf32armle executable file (with absolute addresses) */
{
  elf32_writeexec(gv,f,EM_ARM,_LITTLE_ENDIAN_,armle_reloc_vlink2elf);
}


#endif /* ELF32_ARM_LE */
