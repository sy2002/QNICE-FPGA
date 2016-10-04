/* $VER: vlink t_aoutmint.c V0.14e (23.08.14)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2014  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2014 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */

#include "config.h"
#if defined(AOUT_MINT)
#define T_AOUTMINT_C
#include "vlink.h"
#include "aoutmint.h"


static const char mint_script[] =
  "SECTIONS {\n"
  "  . = 0xe4;\n"
  "  .text: {\n"
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
  "}\n";


static int aoutmint_identify(char *,uint8_t *,unsigned long,bool);
static void aoutmint_writeobject(struct GlobalVars *,FILE *);
static void aoutmint_writeshared(struct GlobalVars *,FILE *);
static void aoutmint_writeexec(struct GlobalVars *,FILE *);

struct FFFuncs fff_aoutmint = {
  "aoutmint",
  mint_script,
  NULL,
  aout_headersize,
  aoutmint_identify,
  aoutstd_readconv,
  NULL,
  aout_targetlink,
  NULL,
  aout_lnksym,
  aout_setlnksym,
  NULL,NULL,NULL,
  aoutmint_writeobject,
  aoutmint_writeshared,
  aoutmint_writeexec,
  bss_name,NULL,
  0,
  0x8000, /* @@@ ? */
  0,
  0,  /* MiNT uses MID 0 */
  RTAB_STANDARD,RTAB_STANDARD,
  _BIG_ENDIAN_,
  32,
  FFF_BASEINCR
};


static struct nlist32 *find_aout_sym(const char *name)
/* returns pointer to aout symbol table entry */
{
  struct SymbolNode **chain = &aoutsymlist.hashtab[elf_hash(name)%SYMHTABSIZE];
  struct SymbolNode *sym;

  while (sym = *chain) {
    if (!strcmp(name,sym->name))
      return &sym->s;
    chain = &sym->hashchain;
  }
  return NULL;
}


static int aoutmint_identify(char *name,uint8_t *p,unsigned long plen,bool lib)
{
  return ID_UNKNOWN;  /* a.out-mint format is for executables only */
}


static void aoutmint_writeobject(struct GlobalVars *gv,FILE *f)
{
  error(62);  /* Target file format doesn't support relocatable objects */
}


static void aoutmint_writeshared(struct GlobalVars *gv,FILE *f)
{
  error(30);  /* Target file format doesn't support shared objects */
}


static void aoutmint_writeexec(struct GlobalVars *gv,FILE *f)
/* creates an a.out-MiNT executable file */
{
  const int be = _BIG_ENDIAN_;
  uint8_t jmp_entry_code[] = { 0x20,0x3a,0x00,0x1a,0x4e,0xfb,0x08,0xfa };
  struct LinkedSection *sections[3];
  uint32_t secsizes[3];
  struct mint_exec me;
  long tparel_offset,tparel_size;
  struct nlist32 *stksize;

  aout_initwrite(gv,sections);
  if (sections[0] == NULL)  /* this requires a .text section! */
    error(97,fff[gv->dest_format]->tname,TEXTNAME);

  memset(&me,0,sizeof(struct mint_exec));  /* init header with zero */
  text_data_bss_gaps(sections);  /* calculate gap size between sections */
  secsizes[0] = sections[0]->size + sections[0]->gapsize;
  secsizes[1] = sections[1] ? sections[1]->size + sections[1]->gapsize : 0;
  secsizes[2] = sections[2] ? sections[2]->size : 0;

  /* init TOS header */
  write16be(me.tos.ph_branch,0x601a);
  write32be(me.tos.ph_tlen,secsizes[0]+TEXT_OFFSET);
  write32be(me.tos.ph_dlen,secsizes[1]);
  write32be(me.tos.ph_blen,secsizes[2]);
  write32be(me.tos.ph_magic,0x4d694e54);  /* "MiNT" */
  write32be(me.tos.ph_flags,gv->tosflags);  /* Atari memory flags */
  write16be(me.tos.ph_abs,0);  /* includes relocations */

  aout_addsymlist(gv,sections,BIND_GLOBAL,0,be);
  aout_addsymlist(gv,sections,BIND_WEAK,0,be);
  aout_addsymlist(gv,sections,BIND_LOCAL,0,be);
  aout_debugsyms(gv,be);
  calc_relocs(gv,sections[0]);
  calc_relocs(gv,sections[1]);

  /* The Atari symbol table size is the sum of a.out symbols and strings,
     which is now known. */
  write32be(me.tos.ph_slen,aoutsymlist.nextindex * sizeof(struct nlist32) +
            (aoutstrlist.nextoffset>4 ? aoutstrlist.nextoffset : 0));

  /* set jmp_entry to  move.l  a_entry(pc),d0
                       jmp     (-6,pc,d0.l)   */
  memcpy(me.jmp_entry,jmp_entry_code,sizeof(jmp_entry_code));

  /* init a.out NMAGIC header */
  SETMIDMAG(&me.aout,NMAGIC,0,0);
  write32be(me.aout.a_text,secsizes[0]);
  write32be(me.aout.a_data,secsizes[1]);
  write32be(me.aout.a_bss,secsizes[2]);
  write32be(me.aout.a_syms,aoutsymlist.nextindex*sizeof(struct nlist32));
  write32be(me.aout.a_entry,TEXT_OFFSET);

  /* save offset to __stksize when symbol is present */
  if (stksize = find_aout_sym("__stksize")) {
    write32be(me.stkpos,
              read32be(&stksize->n_value)+sizeof(me)-TEXT_OFFSET);
  }

  /* write a.out-MiNT header (256 bytes) */
  fwritex(f,&me,sizeof(me));

  /* write sections */
  fwritex(f,sections[0]->data,sections[0]->filesize);
  fwritegap(f,(sections[0]->size-sections[0]->filesize)+sections[0]->gapsize);
  if (sections[1]) {
    fwritex(f,sections[1]->data,sections[1]->filesize);
    fwritegap(f,(sections[1]->size-sections[1]->filesize)+sections[1]->gapsize);
  }

  /* write a.out symbols */
  aout_writesymbols(f);
  aout_writestrings(f,be);

  /* write TPA relocs */
  tparel_offset = ftell(f);
  tos_writerelocs(gv,f,sections);
  tparel_size = ftell(f) - tparel_offset;

  /* we have to patch tparel_pos and tparel_size in the header, as we
     didn't know about the size of the TPA relocs table before */
  fseek(f,offsetof(struct mint_exec,tparel_pos),SEEK_SET);
  fwrite32be(f,tparel_offset);
  fwrite32be(f,tparel_size);
}

#endif
