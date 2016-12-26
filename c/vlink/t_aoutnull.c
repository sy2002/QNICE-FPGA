/* $VER: vlink t_aoutnull.c V0.13 (02.11.10)
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
#if defined(AOUT_NULL)
#define T_AOUTNULL_C
#include "vlink.h"
#include "aout.h"


static const char null_exe[] = {
  "SECTIONS\n"
  "{\n"
  "  . = 0x1020;\n"
  "  .text :\n"
  "  {\n"
  "    *(.i* i* I*)\n"
  "    *(.t* t* T* .c* c* C*)\n"
  "    *(.f* f* F*)\n"
  "    _etext = .;\n"
  "    __etext = .;\n"
  "    . = ALIGN(4);\n"
  "  }\n"
  "  .data: {\n"
  "    PROVIDE(_LinkerDB = . + 0x8000);\n"
  "    PROVIDE(_SDA_BASE_ = . + 0x8000);\n"
  "    VBCC_CONSTRUCTORS\n"
  "    *(.rodata*)\n"
  "    *(.d* d* D*)\n"
  "    *(.sdata*)\n"
  "    *(__MERGED)\n"
  "    _edata = .;\n"
  "    __edata = .;\n"
  "    . = ALIGN(4);\n"
  "  }\n"
  "  .bss: {\n"
  "    *(.sbss*)\n"
  "    *(.scommon)\n"
  "    *(.b* b* B* .u* u* U*)\n"
  "    *(COMMON)\n"
  "    _end = ALIGN(4);\n"
  "    __end = ALIGN(4);\n"
  "  }\n"
  "}\n"
};


static int aoutnull_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutnull = {
  "aoutnull",
  null_exe,
  NULL,
  aout_headersize,
  aoutnull_identify,
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
  0,
  RTAB_STANDARD,RTAB_STANDARD,
  -1,  /* endianess unknown */
  32,
  FFF_BASEINCR
};


static int aoutnull_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return aout_identify(&fff_aoutnull,name,(struct aout_hdr *)p,plen);
}

#endif
