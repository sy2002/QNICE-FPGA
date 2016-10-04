/* $VER: vlink t_aouti386.c V0.13 (02.11.10)
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
#if defined(AOUT_BSDI386) || defined(AOUT_PC386)
#define T_AOUTI386_C
#include "vlink.h"
#include "aout.h"


static const char zmagic_exe[] = {
  "SECTIONS\n"
  "{\n"
  "  . = 0x1020;\n"
  "  .text :\n"
  "  {\n"
  "    /*CREATE_OBJECT_SYMBOLS*/\n"
  "    *(.text)\n"
  "    *(.dynrel)\n"
  "    *(.hash)\n"
  "    *(.dynsym)\n"
  "    *(.dynstr)\n"
  "    *(.rules)\n"
  "    *(.need)\n"
  "    _etext = .;\n"
  "    __etext = .;\n"
  "  }\n"
  "  . = ALIGN(0x1000);\n"
  "  .data :\n"
  "  {\n"
  "    *(.dynamic)\n"
  "    *(.got)\n"
  "    *(.plt)\n"
  "    *(.data)\n"
  "    /*CONSTRUCTORS*/\n"
  "    _edata  =  .;\n"
  "    __edata  =  .;\n"
  "  }\n"
  "  .bss :\n"
  "  {\n"
  "    __bss_start = .;\n"
  "   *(.bss)\n"
  "   *(COMMON)\n"
  "   _end = ALIGN(4);\n"
  "   __end = ALIGN(4);\n"
  "  }\n"
  "}\n"
};


#ifdef AOUT_BSDI386
static int aoutbsdi386_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutbsdi386 = {
  "aoutbsdi386",
  zmagic_exe,
  NULL,
  aout_headersize,
  aoutbsdi386_identify,
  aoutstd_readconv,
  NULL,
  aout_targetlink,
  NULL,
  aout_lnksym,
  aout_setlnksym,
  NULL,NULL,NULL,
  aoutstd_writeobject,
  aoutstd_writeshared,
  aoutstd_writeexec,
  bss_name,NULL,
  0x1000,
  0x8000, /* @@@ ? */
  0,
  MID_I386,
  RTAB_STANDARD,RTAB_STANDARD,
  _LITTLE_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif

#ifdef AOUT_PC386
static int aoutpc386_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutpc386 = {
  "aoutpc386",
  zmagic_exe,
  NULL,
  aout_headersize,
  aoutpc386_identify,
  aoutstd_readconv,
  NULL,
  aout_targetlink,
  NULL,
  aout_lnksym,
  aout_setlnksym,
  NULL,NULL,NULL,
  aoutstd_writeobject,
  aoutstd_writeshared, /* @@@ ? */
  aoutstd_writeexec,   /* @@@ ? */
  bss_name,NULL,
  0x1000, /* @@@ ? */
  0x8000, /* @@@ ? */
  0,
  MID_PC386,
  RTAB_STANDARD,RTAB_STANDARD,
  _LITTLE_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif


#ifdef AOUT_BSDI386
static int aoutbsdi386_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return (aout_identify(&fff_aoutbsdi386,name,(struct aout_hdr *)p,plen));
}
#endif


#ifdef AOUT_PC386
static int aoutpc386_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return (aout_identify(&fff_aoutpc386,name,(struct aout_hdr *)p,plen));
}
#endif

#endif
