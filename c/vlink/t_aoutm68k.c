/* $VER: vlink t_aoutm68k.c V0.13 (02.11.10)
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
#if defined(AOUT_BSDM68K) || defined(AOUT_BSDM68K4K) || \
    defined(AOUT_SUN010) || defined(AOUT_SUN020) || defined(AOUT_JAGUAR)
#define T_AOUTM68K_C
#include "vlink.h"
#include "aout.h"


static const char zmagic_exe1[] = {
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

static const char zmagic_exe2[] = {
  "SECTIONS\n"
  "{\n"
  "  . = 0x2020;\n"
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
  "  . = ALIGN(0x2000);\n"
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


#ifdef AOUT_BSDM68K
static int aoutbsd68k_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutbsd68k = {
  "aoutbsd68k",
  zmagic_exe2,
  NULL,
  aout_headersize,
  aoutbsd68k_identify,
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
  0x2000,
  0x8000, /* @@@ ? */
  0,
  MID_M68K,
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif

#ifdef AOUT_BSDM68K4K
static int aoutbsd68k4k_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutbsd68k4k = {
  "aoutbsd68k4k",
  zmagic_exe1,
  NULL,
  aout_headersize,
  aoutbsd68k4k_identify,
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
  MID_M68K4K,
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif

#ifdef AOUT_SUN010
static int aoutsun010_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutsun010 = {
  "aoutsun010",
  zmagic_exe2,
  NULL,
  aout_headersize,
  aoutsun010_identify,
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
  0x2000,
  0x8000, /* @@@ ? */
  0,
  MID_SUN010,
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif

#ifdef AOUT_SUN020
static int aoutsun020_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutsun020 = {
  "aoutsun020",
  zmagic_exe2,
  NULL,
  aout_headersize,
  aoutsun020_identify,
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
  0x2000,
  0x8000, /* @@@ ? */
  0,
  MID_SUN020,
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};
#endif

#ifdef AOUT_JAGUAR
static const char jaguar_exe[] = {
  "SECTIONS\n"
  "{\n"
  "  . = 0x4020;\n"
  "  .text :\n"
  "  {\n"
  "    *(.text)\n"
  "    _etext = .;\n"
  "    __etext = .;\n"
  "  }\n"
  "  . = ALIGN(4);\n"
  "  .data :\n"
  "  {\n"
  "    *(.data)\n"
  "    VBCC_CONSTRUCTORS\n"
  "    _edata  =  .;\n"
  "    __edata  =  .;\n"
  "  }\n"
  "  . = ALIGN(4);\n"
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

static int aoutjaguar_identify(char *,uint8_t *,unsigned long,bool);

struct FFFuncs fff_aoutjaguar = {
  "aoutjaguar",
  jaguar_exe,
  NULL,
  aout_headersize,
  aoutjaguar_identify, /* NULL */
  NULL,
  NULL,
  aout_targetlink, /* NULL */
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
  0,  /* MID 0! */
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR|AOUT_JAGRELOC
};
#endif


#ifdef AOUT_BSDM68K
static int aoutbsd68k_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return aout_identify(&fff_aoutbsd68k,name,(struct aout_hdr *)p,plen);
}
#endif


#ifdef AOUT_BSDM68K4K
static int aoutbsd68k4k_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return aout_identify(&fff_aoutbsd68k4k,name,(struct aout_hdr *)p,plen);
}
#endif


#ifdef AOUT_SUN010
static int aoutsun010_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return aout_identify(&fff_aoutsun010,name,(struct aout_hdr *)p,plen);
}
#endif


#ifdef AOUT_SUN020
static int aoutsun020_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return aout_identify(&fff_aoutsun020,name,(struct aout_hdr *)p,plen);
}
#endif


#ifdef AOUT_JAGUAR
static int aoutjaguar_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return ID_UNKNOWN;  /* object are read as aoutnull */
}
#endif

#endif
