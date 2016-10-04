/* $VER: vlink tosdefs.h V0.13 (02.11.10)
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


/* TOS program header */
typedef struct
{
  uint8_t ph_branch[2]; /* branch to start of program (0x601a) */
  uint8_t ph_tlen[4];   /* .text length */
  uint8_t ph_dlen[4];   /* .data length */
  uint8_t ph_blen[4];   /* .bss length */
  uint8_t ph_slen[4];   /* length of symbol table */
  uint8_t ph_magic[4];
  uint8_t ph_flags[4];  /* Atari special flags */
  uint8_t ph_abs[2];    /* has to be 0, otherwise no relocation takes place */
} PH;


/* DRI symbol table */
#define DRI_NAMELEN 8

struct DRIsym
{
  char name[DRI_NAMELEN];
  uint8_t type[2];
  uint8_t value[4];
};

#define STYP_UNDEF 0
#define STYP_BSS 0x0100
#define STYP_TEXT 0x0200
#define STYP_DATA 0x0400
#define STYP_EXTERNAL 0x0800
#define STYP_REGISTER 0x1000
#define STYP_GLOBAL 0x2000
#define STYP_EQUATED 0x4000
#define STYP_DEFINED 0x8000
#define STYP_LONGNAME 0x0048
#define STYP_TFILE 0x0280
#define STYP_TFARC 0x02c0


/* default script */
static const char defaultscript[] =
  "SECTIONS {\n"
  "  . = 0;\n"
  "  .text: {\n"
  "    *(.i* i* I*)\n"
  "    *(.t* t* T* .c* c* C*)\n"
  "    *(.f* f* F*)\n"
  "    PROVIDE(_etext = .);\n"
  "    PROVIDE(__etext = .);\n"
  "    . = ALIGN(2);\n"
  "  }\n"
  "  .data: {\n"
  "    PROVIDE(_LinkerDB = . + 0x8000);\n"
  "    PROVIDE(_SDA_BASE_ = . + 0x8000);\n"
  "    VBCC_CONSTRUCTORS\n"
  "    *(.rodata*)\n"
  "    *(.d* d* D*)\n"
  "    *(.sdata*)\n"
  "    *(__MERGED)\n"
  "    PROVIDE(_edata = .);\n"
  "    PROVIDE(__edata = .);\n"
  "    . = ALIGN(2);\n"
  "  }\n"
  "  .bss: {\n"
  "    *(.sbss*)\n"
  "    *(.scommon)\n"
  "    *(.b* b* B* .u* u* U*)\n"
  "    *(COMMON)\n"
  "    PROVIDE(_end = ALIGN(4));\n"
  "    PROVIDE(__end = ALIGN(4));\n"
  "  }\n"
  "}\n";


/* t_ataritos.c prototypes */
void tos_writerelocs(struct GlobalVars *,FILE *,struct LinkedSection **);
