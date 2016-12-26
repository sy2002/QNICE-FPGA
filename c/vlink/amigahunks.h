/* $VER: vlink amigahunks.h V0.15a (09.12.15)
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


/* hunk types */
#define HUNK_UNIT         999
#define HUNK_NAME         1000
#define HUNK_CODE         1001
#define HUNK_DATA         1002
#define HUNK_BSS          1003
#define HUNK_RELOC32      1004
#define HUNK_ABSRELOC32	  HUNK_RELOC32
#define HUNK_RELOC16      1005
#define HUNK_RELRELOC16   HUNK_RELOC16
#define HUNK_RELOC8       1006
#define HUNK_RELRELOC8    HUNK_RELOC8
#define HUNK_EXT          1007
#define HUNK_SYMBOL       1008
#define HUNK_DEBUG        1009
#define HUNK_END          1010
#define HUNK_HEADER       1011
#define HUNK_OVERLAY      1013
#define HUNK_BREAK        1014
#define HUNK_DREL32       1015
#define HUNK_DREL16       1016
#define HUNK_DREL8        1017
#define HUNK_LIB          1018
#define HUNK_INDEX        1019
#define HUNK_RELOC32SHORT 1020
#define HUNK_RELRELOC32   1021
#define HUNK_ABSRELOC16   1022
/* EHF extensions */
#define HUNK_PPC_CODE     1257
#define HUNK_RELRELOC26   1260

#define HUNKB_ADVISORY    29
#define HUNKB_CHIP        30
#define HUNKB_FAST        31
#define HUNKF_ADVISORY    (1L<<29)
#define HUNKF_CHIP        (1L<<30)
#define HUNKF_FAST        (1L<<31)
#define HUNKF_MEMTYPE     (HUNKF_CHIP|HUNKF_FAST)

/* hunk_ext sub-types */
#define EXT_SYMB          0
#define EXT_DEF           1
#define EXT_ABS           2
#define EXT_RES           3
#define EXT_REF32         129
#define EXT_ABSREF32      EXT_REF32
#define EXT_COMMON        130
#define EXT_ABSCOMMON     EXT_COMMON
#define EXT_REF16         131
#define EXT_RELREF16      EXT_REF16
#define EXT_REF8          132
#define EXT_RELREF8       EXT_REF8
#define EXT_DEXT32        133
#define EXT_DEXT16        134
#define EXT_DEXT8         135
#define EXT_RELREF32      136
#define EXT_RELCOMMON     137
#define EXT_ABSREF16      138
#define EXT_ABSREF8       139

/* vbcc extensions */
#define EXT_DEXT32COMMON  208
#define EXT_DEXT16COMMON  209
#define EXT_DEXT8COMMON   210

/* EHF extensions */
#define EXT_RELREF26      229

/* memory attributes */
#define MEMF_PUBLIC       1
#define MEMF_CHIP         2
#define MEMF_FAST         4

/* target amigahunk specific structures and defines */
#define EXT_IGNORE 0x100

struct HunkInfo {
  uint8_t *hunkbase;    /* base address of amigaos/ehf file */
  uint8_t *hunkptr;     /* current hunk data pointer */
  long hunkcnt;         /* remaining bytes in this file */
  const char *filename;
  bool exec;            /* executable file? */
  uint8_t *libbase;     /* base address HUNK_LIB data (hunk data) */
  uint8_t *indexbase;   /* HUNK_INDEX data base address */
  uint8_t *indexptr;    /* current HUNK_INDEX data pointer */
  long indexcnt;        /* remaining bytes in HUNK_INDEX */
  long savedhunkcnt;    /* hunkcnt to restore after HUNK_LIB is parsed */
};

struct XRefNode {
  struct node n;
  const char *sym_name;
  uint8_t ref_type;
  uint32_t com_size;
  int noffsets;
  struct list xreflist;
};

#define SUBID_LINE 1
struct LineDebug {
  struct TargetExt tgext;   /* id = TGEXT_AMIGAOS, subid = SUBID_LINE */
  const char *source_name;  /* full path to source text */
  uint32_t num_entries;     /* number of entries in line/offset table */
  uint32_t *lines;
  uint32_t *offsets;
};
