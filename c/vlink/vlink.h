/* $VER: vlink vlink.h V0.15a (09.12.15)
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stddef.h>
#include <ctype.h>
#include "config.h"

/* program's name */
#define PNAME "vlink"

/* integer types - non ISO-C99 compliant compilers have to define TYPESxxBIT */
#if defined(TYPES32BIT)
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef signed short int int16_t;
typedef unsigned short int uint16_t;
typedef signed long int int32_t;
typedef unsigned long int uint32_t;
typedef signed long long int int64_t;
typedef unsigned long long int uint64_t;
#elif defined(TYPES64BIT)
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef signed short int16_t;
typedef unsigned short uint16_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;
typedef signed long int int64_t;
typedef unsigned long int uint64_t;
#elif defined(_MSC_VER) && (_MSC_VER < 1600)
typedef __int8 int8_t;	            /* prior to VS2010 stdint.h is missing */
typedef unsigned __int8 uint8_t;
typedef __int16 int16_t;
typedef unsigned __int16 uint16_t;
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>  /* C99 */
#endif

/* linker word for addresses, values, offsets, etc. */
typedef int64_t lword;

/* boolean values */
typedef int bool;

/* program constants */
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef NULL
#define NULL 0
#endif
#define INVALID (~0)
#define ADDR_NONE (~0)		/* no defined address: 0xffffffff */

#define MAXLEN 256		/* maximum length for symbols and buffers */
#define FNAMEBUFSIZE 1024       /* buffer size for file names */
#define MAX_FWALIGN 8192        /* max. aligment, when writing target file */


/* structures */

struct node {
  struct node *next;
  struct node *pred;
};

struct list {
  struct node *first;
  struct node *dummy;
  struct node *last;
};


struct LibPath {                /* libpaths list. */
  struct node n;                /* Here we search for library archives */
  const char *path;             /* and shared objects. */
};

struct Flavours {               /* library flavours */
  int n_flavours;
  int flavours_len;
  char **flavours;
  char *flavour_dir;
};

struct InputFile {              /* inputlist nodes */
  struct node n;                /* contains names & flags of all inp. files */
  const char *name;
  bool lib;                     /* search library */
  bool dynamic;                 /* try to link dynamic first */
  int so_ver;                   /* minimum version of shared object */
  uint16_t flags;
};

#define IFF_DELUNDERSCORE 1     /* remove preceding underscore from symbols */
#define IFF_ADDUNDERSCORE 2     /* add preceding underscore to symbols */


struct LinkFile {
  struct node n;
  const char *pathname;         /* full path: /usr/lib/libm.a */
  const char *filename;         /* file name: libm.a */
  const char *objname;          /* current obj. name: sin.o (archives only)*/
  uint8_t *data;                /* pointer to file data */
  unsigned long length;         /* length of file */
  uint8_t format;               /* file format - index into targets table */
  uint8_t type;                 /* ID_OBJECT/SHAREDOBJ/LIBARCH */
  uint16_t flags;               /* flags from InputFile */
};


struct Expr {
  int type;
  struct Expr *left;
  struct Expr *right;
  lword val;
};

/* expression types */
enum {
  ADD,SUB,MUL,DIV,MOD,NEG,CPL,LAND,LOR,BAND,BOR,XOR,NOT,LSH,RSH,
  LT,GT,LEQ,GEQ,NEQ,EQ,ABS,REL
};


struct ObjectUnit {
  struct node n;
  struct LinkFile *lnkfile;     /* LinkFile, where the obj. belongs to */
  const char *objname;          /* name of object, if available, e.g. sin.o */
  struct list sections;         /* list of all sections in this object */
  struct Section *common;       /* dummy section for common symbols */
  struct Section *scommon;      /* dummy section for baserel. common sym. */
  struct Symbol **objsyms;      /* all symbols from this object unit */
  struct list stabs;            /* stab debugging symbols */
  struct list pripointers;      /* PriPointers of this unit */
  uint16_t flags;
  uint8_t  min_alignment;       /* minimal alignment for all sections */
  uint8_t  extra;               /* multi-purpose field */
};

#define OUF_LINKED 0x0001       /* object unit is marked as linked */
#define OUF_SCRIPT 0x8000       /* linker script dummy object */
#define OBJSYMHTABSIZE 0x20     /* number of entries in symbol hash table */

struct RelRef {
  struct RelRef *next;
  struct Section *refsec;       /* relative referenced sections */
};

struct TargetExt {
  struct TargetExt *next;
  uint8_t id;                   /* target identification */
  uint8_t sub_id;               /* sub-id for target */
  uint16_t flags;
  /* target specific data follows */
};
/* ids */
#define TGEXT_UNDEF 0
#define TGEXT_AMIGAOS 1
#define TGEXT_ELF 2
#define TGEXT_AOUT 3

struct Section {
  struct node n;
  struct ObjectUnit *obj;       /* link to ObjectUnit */
  struct LinkedSection *lnksec; /* ptr to joined sections */
  const char *name;             /* section's name, e.g. .text, .data, ... */
  uint32_t id;                  /* unique section id - target dependant */
  uint8_t type;                 /* type: code, data, bss */
  uint8_t flags;
  uint8_t protection;           /* readable, writable, executable, ... */
  uint8_t alignment;            /* number of bits, which have to be zero */
  uint32_t memattr;             /* target-specific memory attributes */
  unsigned long va;             /* the section's virtual address */
  unsigned long offset;         /* offset relative to 1st sec. of same type */
  uint8_t *data;                /* the section's contents */
  unsigned long size;           /* the section's size in bytes (+alignment) */
  struct list relocs;           /* relocations for this section */
  struct list xrefs;            /* external references to unknown symbols */
  struct RelRef *relrefs;       /* all sections which are referenced rel. */
  struct TargetExt *special;    /* link to target specific data */
  int link;                     /* link to other section (e.g. ELF-strtab) */
  uint16_t filldata;            /* used to fill gaps */
};

/* section types */
#define ST_UNDEFINED 0
#define ST_CODE 1               /* section contains code */
#define ST_DATA 2               /* section contains initialized data */
#define ST_UDATA 3              /* section contains uninitialized data */
#define ST_TMP 4                /* a temporary, linker-generated section */
#define ST_LAST 4               /* last section type */

/* section flags */
#define SF_ALLOC           0x01 /* allocate section in memory */
#define SF_UNINITIALIZED   0x02 /* section has uninitialized contents */
#define SF_SMALLDATA       0x04 /* section is referenced base-relative */
#define SF_LINKONCE        0x08 /* link only a single section with this name */
#define SF_PORTABLE_MASK   0x1f /* mask for target-independant flags */
/* target specific section flags: amiga */
#define SF_EHFPPC          0x20  /* target ehf: section contains PPC code */

/* protection */
#define SP_READ 1
#define SP_WRITE 2
#define SP_EXEC 4
#define SP_SHARE 8


struct RelocInsert {            /* describes how to insert a reloc addend */
  struct RelocInsert *next;
  uint16_t bpos;                /* bit-position counted from leftmost bit */
  uint16_t bsiz;                /* field size in bits */
  lword mask;                   /* mask to apply to addend */
};                              /*  addend will be normalized after that! */

struct Reloc {                  /* relocation information */
  struct node n;
  const char *xrefname;         /* not 0: this a an external sym. reference */
  union {
    uint32_t id;                /* section index */
    struct Section *ptr;        /* base addr of this sect. has to be added */
    struct LinkedSection *lnk;  /* base addr of joined sections */
    struct Symbol *symbol;      /* symbol-pointer, if x-ref. was resolved */
  } relocsect;
  unsigned long offset;         /* section-offset of relocation */
  lword addend;                 /* add this to relocation value */
  struct RelocInsert *insert;   /* reloc insert field description */
  uint8_t rtype;                /* general reloc type - see below */
  uint8_t flags;                /* relocation specific flags */
};

/* general relocation types */
#define R_NONE 0
#define R_ABS 1                 /* absolute address relocation */
#define R_PC 2                  /* pc-relative relocation */
#define R_GOT 3                 /* symbol's pointer in global offset table */
#define R_GOTPC 4               /* pc-relative global offset table reloc */
#define R_GOTOFF 5              /* offset to global offset table base */
#define R_GLOBDAT 6             /* set global offset table entry */
#define R_PLT 7                 /* absolute procedure linkage table reloc */
#define R_PLTPC 8               /* pc-relative procedure linkage table reloc */
#define R_PLTOFF 9              /* offset to procedure linkage table */
#define R_SD 10                 /* small data, base-relative reloc */
#define R_UABS 11               /* unaligned absolute address relocation */
#define R_LOCALPC 12            /* pc-relative to local symbol */
#define R_LOADREL 13            /* relative to load address, no symbol */
#define R_COPY 14               /* copy from shared object */
#define R_JMPSLOT 15            /* procedure linkage table entry */
#define R_SECOFF 16             /* symbol's offset to start of section */
#define LAST_STANDARD_RELOC R_SECOFF

/* CPU specific relocation types */
#define R_SD2 32                /* PPC: small data 2, base-relative reloc */
#define R_SD21 33               /* PPC-EABI: SD for base-reg 0, 2 or 13 */
#define R_MOSDREL 34            /* PPC-MOS: baserel(r13) rel. to __r13_init */
#define R_AOSBREL 35            /* PPC-OS4: baserel(r2) rel. to data segm. */

/* internal relocation types */
#define R_ABSCOPY 128           /* absolute sh.obj. ref., needs R_COPY */
#define R_PCCOPY 129            /* pc-relative sh.obj. ref., needs R_COPY */

/* Reloc flags */
#define RELF_WEAK 1             /* reference is weak and defaults to 0 */
#define RELF_INTERNAL 0x10      /* linker-internal relocation, not exported */
#define RELF_PLT 0x40           /* dynamic PLT relocation */
#define RELF_DYN 0x80           /* other dynamic relocation */
#define RELF_DYNLINK 0xc0       /* takes part in dynamic linking */


struct Symbol {
  struct node n;
  struct Symbol *glob_chain;    /* next symbol in global hash chain */
  struct Symbol *obj_chain;     /* next symbol in object hash chain */
  const char *name;             /* symbol's name */
  const char *indir_name;       /* indirect symbol name (SYM_INDIR) */
  lword value;                  /* abs. value, reloc. offset or alignment */
  struct Section *relsect;      /* symbol def. relative to this section */
  /* SYM_ABS are rel. to 1st section, SYM_COMMON rel. to a BSS section, */
  /* Linker-script symbols do have a NULL here */
  uint8_t type;                 /* absolute, relocatable or extern */
  uint8_t flags;
  uint8_t info;                 /* section, function or object */
  uint8_t bind;                 /* local, global or weak binding */
  uint32_t size;                /* symbol's size in bytes */
  uint32_t extra;               /* extra data, used by some targets */
};

/* symbol type */
#define SYM_UNDEF 0
#define SYM_ABS 1               /* absolute value */
#define SYM_RELOC 2             /* relocation offset, relative to section */
#define SYM_COMMON 3            /* alignment constraints in value */
#define SYM_INDIR 4             /* indirect symbol, use indir_name instead */

/* symbol flags */
#define SYMF_LNKSYM 1           /* a linker-generated symbol */
#define SYMF_REFERENCED 2       /* symbol was referenced */
#define SYMF_PROTECTED 4        /* symbol is protected against stripping */
#define SYMF_PROVIDED 8         /* provided symbols, removed when unref. */
#define SYMF_SHLIB 0x10         /* symbol definition from a shared library */
#define SYMF_DYNIMPORT 0x40     /* imported symbol for dynamic linking */
#define SYMF_DYNEXPORT 0x80     /* exported symbol for dynamic linking */
#define SYMF_DYNLINK 0xc0       /* takes part in dynamic linking */

/* object type */
#define SYMI_NOTYPE 0
#define SYMI_OBJECT 1
#define SYMI_FUNC 2
#define SYMI_SECTION 3
#define SYMI_FILE 4

/* symbol bind */
#define SYMB_NONE 0
#define SYMB_LOCAL 1
#define SYMB_GLOBAL 2
#define SYMB_WEAK 3

/* extra */
#define SYMX_SPECIAL 0x80000000 /* Bit 31 = target-specific lnk. symbol */


struct SymNames {
  struct SymNames *next;        /* next symbol name in hash chain */
  const char *name;             /* symbol's name */
};


struct StabDebug {
  struct node n;
  struct Section *relsect;      /* symbol def. relative to this section */
  union {
    char *ptr;                  /* NULL-pointer reflects an n_strx of 0 */
    long idx;
  } name;
  uint8_t n_type;               /* stab type */
  int8_t n_othr;
  int16_t n_desc;
  uint32_t n_value;
};


struct MemoryDescr {
  struct MemoryDescr *next;
  const char *name;
  lword org;
  lword len;
  lword current;
};

/* default memory region parameters */
#define MEM_DEFORG (0LL)
#define MEM_DEFLEN (0x7fffffffffffffffLL)


/* overwrite attributes of an input section */
struct SecAttrOvr {
  struct SecAttrOvr *next;
  uint32_t flags;
  uint32_t memflags;
  char name[1];
};

#define SAO_MEMFLAGS 0x00000001 /* overwrite input section's memory flags */


struct LinkedSection {          /* linked sections of same type and name */
  struct node n;
  int index;                    /* section index 0..gv->nsecs */
  const char *name;             /* section's name, e.g. .text, .data, ... */
  uint8_t type;                 /* type: code, data, bss */
  uint8_t flags;
  uint8_t protection;           /* readable, writable, executable, ... */
  uint8_t alignment;            /* number of bits, which have to be zero */
  uint32_t memattr;             /* target-specific memory attributes */
  uint16_t ld_flags;            /* linker-flags for this section */
  uint16_t reserved;
  struct MemoryDescr *destmem;  /* destination memory block (ld-scripts) */
  struct MemoryDescr *relocmem; /* relocation memory block (ld-scripts) */
  unsigned long copybase;       /* section's virtual copy address (destmem) */
  unsigned long base;           /* the section's virtual address (relocmem) */
  unsigned long size;           /* the section's size in bytes */
  unsigned long filesize;       /* size in file, rest ist filled with '0' */
  unsigned long gapsize;        /* bytes to fill until next section */
  struct list sections;         /* s. which have been linked together */
  uint8_t *data;                /* the section's contents */
  struct list relocs;           /* relocations for this section */
  struct list xrefs;            /* external references to unknown symbols */
  struct list symbols;          /* the section's symbol definitions */
};

/* linking flags (ld_flags) */
#define LSF_NOLOAD         0x01 /* used on empty LinkedSection (ldscript) */
#define LSF_PRESERVE       0x02 /* don't delete when unused/empty */


struct Phdr {
  struct Phdr *next;
  const char *name;
  struct MemoryDescr *vmregion; /* assigned memory regions */
  struct MemoryDescr *lmregion;
  uint32_t type;                /* PT_LOAD, PT_DYNAMIC, ... */
  uint16_t flags;               /* PF_X/W/R and header-flags, see below */
  uint8_t alignment;            /* number of bits, which have to be zero */
  uint8_t reserved;
  lword start_vma;              /* start VMA of segment */
  lword start;                  /* overwrites LMA from sections */
  lword file_end;               /* end LMA in file (initialized) */
  lword mem_end;                /* end LMA in memory (will be cleared) */
  unsigned long offset;         /* file offset */
  unsigned long alignment_gap;  /* gap at start of seg. for page alignm. */
};

#define PHDR_CLOSED     0x8000  /* segment can't receive any more sections */
#define PHDR_FILEHDR    0x0800  /* FILEHDR included in segment */
#define PHDR_PHDRS      0x0400  /* PHDRS included in segment */
#define PHDR_ADDR       0x0080  /* load address for segment (LMA) given */
#define PHDR_FLAGS      0x0040  /* flags given */
#define PHDR_USED       0x0010  /* this program header is used for output */
#define PHDR_PFMASK     0x000f  /* mask for seg. permissions "PF_?" */


/* Global defines */
#define DEF_MAXERRORS 999999    /* don't want this feature now... */
#define STRIP_NONE 0
#define STRIP_DEBUG 1           /* strip debugger symbols only */
#define STRIP_ALL 2             /* strip all symbols */
#define DISLOC_NONE 0
#define DISLOC_TMP 1            /* discard temporary local symbols */
#define DISLOC_ALL 2            /* discard all local symbols */


struct GlobalVars {
  /* options */
  struct list libpaths;         /* paths where to search for libraries */
  struct list inputlist;        /* list of input files */
  struct Flavours flavours;     /* library flavours */
  const char *dest_name;        /* output (executable) file name */
  const char *osec_base_name;   /* base name when outputting sections */
  uint8_t dest_format;          /* output file format */
  bool dest_object;             /* output file is a relocatable object */
  bool dest_sharedobj;          /* output as shared object */
  bool dyn_exp_all;             /* export all globals as dynamic symbols */
  bool keep_relocs;             /* keep relocations in final executable */
  bool alloc_common;            /* force allocation of common symbols */
  bool alloc_addr;              /* force allocation of address symbols */
  bool whole_archive;           /* always link with whole archives */
  uint8_t strip_symbols;        /* strip symbols */
  uint8_t discard_local;        /* discard local symbols */
  uint8_t reloctab_format;      /* format of relocation table (.rel/.rela) */
  bool small_code;              /* combine all code sections */
  bool small_data;              /* combine all data sections */
  bool multibase;               /* don't merge all base-rel. accessed sect.*/
  bool no_page_align;           /* page-alignment disabled */
  bool fix_unnamed;             /* unnamed section get a default name */
  bool textbaserel;             /* allow base-relative access on code secs. */
  bool textbasedsyms;           /* symbol offsets based on text section */
  bool output_sections;         /* output each section as a new file */
  uint8_t min_alignment;        /* minimal section alignment (default 0) */
  bool auto_merge;              /* merge sections with pc-rel. references */
  uint8_t opt_reserved[3];
  FILE *map_file;               /* map file */
  FILE *trace_file;             /* linker trace output */
  struct SymNames **trace_syms; /* trace-symbol hash table */
  struct SymNames *prot_syms;   /* list of protected symbols */
  struct SymNames *undef_syms;  /* list of undefined symbols */
  struct SecAttrOvr *secattrovrs; /* input section attribute overwrites */
  const char *scriptname;
  const char *ldscript;         /* linker-script to be used for output file */
  const char *entry_name;       /* entry point symbol or addr (-e option) */
  lword start_addr;             /* -Ttext sets base address of first sect. */
  const char *soname;           /* real name of shared object (-soname) */
  const char *interp_path;      /* path to program interpreter (ELF) */
  struct list rpaths;           /* library paths for dynamic linker (ELF) */
  uint32_t tosflags;            /* flags field in TOS header */

  /* errors */
  bool dontwarn;                /* suppress warnings */
  bool errflag;                 /* if true, don't create output file */
  int maxerrors;                /* # of errors to display, before aborting */
  int errcnt;                   /* number of errors displayed */
  int returncode;               /* return code for exit() */

  /* linking process */
  struct list linkfiles;        /* list of all link files (obj., libs,...)*/
  struct list selobjects;       /* list of included object units */
  struct list libobjects;       /* list of non-included library-objects */
  struct list sharedobjects;    /* list of shared objects */
  struct Symbol **symbols;      /* global symbol hash table */
  struct Symbol **lnksyms;      /* target-specific linker symbols hash tab */
  struct list scriptsymbols;    /* symbols defined by linker script */
  struct list pripointers;      /* list of PriPointer nodes */
  struct list lnksec;           /* list of linked sections */
  int nsecs;                    /* total number of sections in lnksec */
  struct ObjectUnit *dynobj;    /* artif. object for dynamic sections */
  struct LinkedSection *firstSD;/* first small data section */
  struct Section *dummysec;     /* contains nothing, has base addr. 0 */
  struct Phdr *phdrlist;        /* list of defined PHDRs (ELF only) */
  uint16_t filldata;            /* used to fill alignment-gaps */
  int8_t endianess;             /* linking in big endian mode (1), */
                                /*  little endian (0), undefined (-1) */
  uint8_t collect_ctors_type;   /* method to collect constructors */
  const char *collect_ctors_secname; /* default section name for construct. */
  struct Symbol *ctor_symbol;   /* constructor list label: __CTOR_LIST__ */
  struct Symbol *dtor_symbol;   /* destructor list label: __DTOR_LIST__ */
  const char *common_sec_name;  /* section name for common symbols */
  const char *scommon_sec_name; /* section name for small data com.symbols */
  const char *got_base_name;    /* GOT label: _GLOBAL_OFFSET_TABLE_ */
  const char *plt_base_name;    /* PLT label: _PROCEDURE_LINKAGE_TABLE_ */
  bool dynamic;                 /* dynamic linking - requires interpreter */
  bool use_ldscript;            /* true means there are LinkedSections, */
                                /*  generated by a linker-script */
  uint8_t scriptflags;          /* flags set by the script parser */
};

#define SYMHTABSIZE 0x10000     /* number of entries in symbol hash table */
#define TRSYMHTABSIZE 0x40
#define DEFAULT_INTERP_PATH "/usr/lib/ld.so.1"

/* endianess */
#define _LITTLE_ENDIAN_ (0)
#define _BIG_ENDIAN_ (1)

/* reloctab_format */
#define RTAB_UNDEF      0x00    /* format not preset by user */
#define RTAB_STANDARD   0x01    /* standard, addends in code */
#define RTAB_ADDEND     0x02    /* table includes addends */
#define RTAB_SHORTOFF   0x04    /* table uses short offsets (e.g. 16 bit) */

/* script flags */
#define LDSF_KEEP     0x01      /* don't delete empty sections */
#define LDSF_SORTFIL  0x02      /* sort files machting on pattern */
#define LDSF_SORTSEC  0x04      /* sort sections machting on pattern */

/* collect_ctors_type */
#define CCDT_NONE     0         /* don't look for constructors/destructors */
#define CCDT_GNU      1         /* GNU-style: ??? */
#define CCDT_VBCC     2         /* VBCC-style: __INIT[_<pri=0-9>]_<name>()
                                               __EXIT[_<pri=0-9>]_<name>() */
#define CCDT_VBCC_ELF 3         /* VBCC-style: _INIT[_<pri=0-9>]_<name>()
                                               _EXIT[_<pri=0-9>]_<name>() */
#define CCDT_SASC     4         /* SAS/C-style: __STI[_<pri>]_<name>()
                                                __STD[_<pri>]_<name>() */

typedef union {                 /* argument type for dynentry() */
  const char *name;
  struct Symbol *sym;
  struct Reloc *rel;
} DynArg;

struct FFFuncs {                /* file format specific functions and data */
  const char *tname;            /* name of file format */
  const char *exeldscript;      /* default linker-script for executables */
  const char *soldscript;       /* default linker-script for shared objects */
  unsigned long                 /* size of header before first section */
    (*headersize)(struct GlobalVars *);
  int                           /* format identification */
    (*identify)(char *,uint8_t *,unsigned long,bool);
  void                          /* read file and convert into internal fmt. */
    (*readconv)(struct GlobalVars *,struct LinkFile *);
  uint8_t                       /* compare target-specific section flags */
    (*cmpsecflags)(struct LinkedSection *,struct Section *);
  int                           /* chk. if target requires linking of sect.*/
    (*targetlink)(struct GlobalVars *,struct LinkedSection *,struct Section *);
  struct Symbol *               /* optional target-specific find-symbol */
    (*fndsymbol)(struct GlobalVars *,struct Section *,const char *name);
  struct Symbol *               /* resolve linker-symbol reference */
    (*lnksymbol)(struct GlobalVars *,struct Section *,struct Reloc *);
  void                          /* init sym structure during resolve_xref() */
    (*setlnksym)(struct GlobalVars *,struct Symbol *);
  void                          /* prepare dynamic linking structures */
    (*dyninit)(struct GlobalVars *);
  struct Symbol *               /* make entry into a dynamic linking section */
    (*dynentry)(struct GlobalVars *,DynArg,int);
  void /* create dynamic linking structures from collected information */
    (*dyncreate)(struct GlobalVars *);
  void                          /* write object file */
    (*writeobject)(struct GlobalVars *,FILE *);
  void                          /* write shared object file */
    (*writeshared)(struct GlobalVars *,FILE *);
  void                          /* write executable file */
    (*writeexec)(struct GlobalVars *,FILE *);
  const char *bssname;          /* default name for bss section */
  const char *sbssname;         /* default name for small-data-bss section */
  uint32_t page_size;           /* page size for exec section alignment */
  int32_t baseoff;              /* sec. offset in bytes for base registers */
  int32_t gotoff;               /* offset in .got for _GLOBAL_OFFSET_TABLE_ */
  uint32_t id;                  /* general purpose id (e.g. MID for a.out) */
  uint8_t rtab_format;          /* reloc-table format (GV.reloctab_format) */
  uint8_t rtab_mask;            /* mask of allowed reloc-table formats */
  int8_t endianess;             /* 1=bigEndian, 0=littleEndian */
  int8_t addr_bits;             /* bits in a target address (16, 32, 64) */
  uint32_t flags;               /* general and target-family specific flags */
};

/* Return codes from identify() */
#define ID_IGNORE (-1)          /* ignore file - e.g. an empty archive */
#define ID_UNKNOWN 0            /* unknown file format */
#define ID_OBJECT 1             /* object file in current format */
#define ID_EXECUTABLE 2         /* executable file in current format */
#define ID_ARTIFICIAL 3         /* an art. object, created by the linker */
/* ^ objects and executables must have a smaller id-value! */
#define ID_LIBBASE 4            /* all ids >= 4 are libraries (s.o. or .a) */
#define ID_SHAREDBASE 4
#define ID_SHAREDOBJ 4          /* shared object file in current format */
#define ID_ARCHBASE 8
#define ID_LIBARCH 8            /* linker library archive in curr. format */
/* number of entries in linker symbol hash table */
#define LNKSYMHTABSIZE 0x10

/* types for dynentry() */
#define GOT_ENTRY 1             /* allocate new .got entry */
#define PLT_ENTRY 2             /* allocate a new jump-slot in .plt/.got */
#define BSS_ENTRY 3             /* allocate space in .bss for R_COPY */
#define GOT_LOCAL 4             /* .got entry for local symbol */
#define PLT_LOCAL 5             /* .plt entry for local (does not exist) */
#define STR_ENTRY 6             /* allocate a new string into .dynstr */
#define SYM_ENTRY 7             /* allocate a new symbol into .dynsym */
#define SO_NEEDED 8             /* new shared object is needed */

/* Target flags - bits 24 to 31 are reserved for target-family flags */
#define FFF_BASEINCR 1          /* Section base address is not reset to 0 */
                                /* for the following sections while */
                                /* linking without a linker script */
#define FFF_RELOCATABLE 2       /* Target generates relocatable executables */
                                /* - also defines whether the distance */
                                /* between sections is not constant */
#define FFF_PSEUDO_DYNLINK 4    /* Dynamic linking is not really done, only */
                                /* symbol references are checked whether they */
                                /* can be resolved by the shared object */
#define FFF_DYN_RESOLVE_ALL 8   /* All dynamic symbol references have to */
                                /* be resolved at link-time, even the */
                                /* inter-DLL ones. */
#define FFF_SECTOUT 16          /* Target allows to create a new file for */
                                /* each section. */

/* List of artificially generated pointers or long words, which are */
/* sorted by section-name, list-name and priority. */
struct PriPointer {
  struct node n;
  const char *secname;
  const char *listname;
  int priority;
  const char *xrefname;
  lword addend;
};


/* global functions */
#include "ar.h"

/* main.c */
#ifndef MAIN_C
extern struct GlobalVars gvars;

extern void cleanup(struct GlobalVars *);
#endif

/* version.c */
#ifndef VERSION_C
extern void show_version(void);
extern void show_usage(void);
#endif

/* support.c */
#ifndef SUPPORT_C
extern const char *endian_name[];

extern void *alloc(size_t);
extern void *re_alloc(void *,size_t);
extern void *alloczero(size_t);
extern const char *allocstring(const char *);
extern void *alloc_hashtable(size_t);
extern void memset16(struct GlobalVars *,void *,uint16_t,long);
extern void initlist(struct list *);
extern void insertbefore(struct node *,struct node *);
extern void insertbehind(struct node *,struct node *);
extern void addhead(struct list *,struct node *);
extern void addtail(struct list *,struct node *);
extern struct node *remhead(struct list *);
extern struct node *remnode(struct node *);
extern char *mapfile(const char *);
extern const char *base_name(const char *);
extern char *check_name(char *);
extern bool checkrange(lword,bool,int);
extern int8_t host_endianess(void);
extern uint16_t swap16(uint16_t);
extern uint32_t swap32(uint32_t);
extern uint64_t swap64(uint64_t);
extern uint16_t read16be(void *);
extern uint32_t read32be(void *);
extern uint64_t read64be(void *);
extern void write16be(void *,uint16_t);
extern void write32be(void *,uint32_t);
extern void write64be(void *,uint64_t);
extern uint16_t read16le(void *);
extern uint32_t read32le(void *);
extern uint64_t read64le(void *);
extern void write16le(void *,uint16_t);
extern void write32le(void *,uint32_t);
extern void write64le(void *,uint64_t);
extern uint16_t read16(bool,void *);
extern uint32_t read32(bool,void *);
extern uint64_t read64(bool,void *);
extern void write16(bool,void *,uint16_t);
extern void write32(bool,void *,uint32_t);
extern void write64(bool,void *,uint64_t);
extern int writetaddr(struct GlobalVars *,void *,lword);
extern uint32_t readbf32(bool,void *,int,int);
extern void writebf32(bool,void *,int,int,uint32_t);
extern void fwritex(FILE *,const void *,size_t);
extern void fwrite32be(FILE *,uint32_t);
extern void fwrite16be(FILE *,uint16_t);
extern void fwrite32le(FILE *,uint32_t);
extern void fwrite16le(FILE *,uint16_t);
extern void fwrite8(FILE *,uint8_t);
extern void fwrite_align(FILE *,uint32_t,uint32_t);
extern void fwritegap(FILE *,long);
extern unsigned long elf_hash(const char *);
extern unsigned long align(unsigned long,unsigned long);
extern unsigned long comalign(unsigned long,unsigned long);
extern int shiftcnt(uint32_t);
extern int lshiftcnt(lword);
extern lword sign_extend(lword,int);
void add_symnames(struct SymNames **,const char *);
#endif
#define listempty(x) ((x)->first->next==NULL)
#define makemask(x) ((lword)(1LL<<(x))-1)

/* errors.c */
#ifndef ERRORS_C
extern void error(int,...);
extern void ierror(char *,...);
#endif

/* linker.c */
#ifndef LINKER_C
extern void linker_init(struct GlobalVars *);
extern void linker_load(struct GlobalVars *);
extern void linker_resolve(struct GlobalVars *);
extern void linker_relrefs(struct GlobalVars *);
extern void linker_dynprep(struct GlobalVars *);
extern void linker_join(struct GlobalVars *);
extern void linker_mapfile(struct GlobalVars *);
extern void linker_copy(struct GlobalVars *);
extern void linker_relocate(struct GlobalVars *);
extern void linker_write(struct GlobalVars *);
extern void linker_cleanup(struct GlobalVars *);
extern const char *getobjname(struct ObjectUnit *);
extern void print_function_name(struct Section *,unsigned long);
extern void print_symbol(FILE *,struct Symbol *);
extern bool trace_sym_access(struct GlobalVars *,const char *);
#endif

/* targets.c */
#ifndef TARGETS_C
extern struct FFFuncs *fff[];
extern const char *sym_type[];
extern const char *sym_info[];
extern const char *sym_bind[];
extern const char *reloc_name[];
extern const char text_name[];
extern const char data_name[];
extern const char bss_name[];
extern const char sdata_name[];
extern const char sbss_name[];
extern const char sdata2_name[];
extern const char sbss2_name[];
extern const char ctors_name[];
extern const char dtors_name[];
extern const char got_name[];
extern const char plt_name[];
extern const char sdabase_name[];
extern const char sda2base_name[];
extern const char gotbase_name[];
extern const char pltbase_name[];
extern const char dynamic_name[];
extern const char r13init_name[];
extern const char noname[];
extern bool check_protection(struct GlobalVars *,const char *);
extern struct Symbol *findsymbol(struct GlobalVars *,struct Section *,
                                 const char *);
extern void hide_shlib_symbols(struct GlobalVars *);
extern struct Symbol *addsymbol(struct GlobalVars *,struct Section *,
                                const char *,const char *,lword,
                                uint8_t,uint8_t,uint8_t,uint8_t,uint32_t,bool);
extern struct Symbol *findlocsymbol(struct GlobalVars *,struct ObjectUnit *,
                                    const char *);
extern void addlocsymbol(struct GlobalVars *,struct Section *,char *,char *,
                         lword,uint8_t,uint8_t,uint8_t,uint32_t);
extern bool addglobsym(struct GlobalVars *,struct Symbol *);
extern struct Symbol *addlnksymbol(struct GlobalVars *,const char *,lword,
                                   uint8_t,uint8_t,uint8_t,uint8_t,uint32_t);
extern struct Symbol *findlnksymbol(struct GlobalVars *,const char *);
extern void fixlnksymbols(struct GlobalVars *,struct LinkedSection *);
extern struct Symbol *find_any_symbol(struct GlobalVars *,
                                      struct Section *,const char *);
extern void reenter_global_objsyms(struct GlobalVars *,struct ObjectUnit *);
extern struct Reloc *newreloc(struct GlobalVars *,struct Section *,
                              const char *,struct Section *,uint32_t,
                              unsigned long,uint8_t,lword);
extern void addreloc(struct Section *,struct Reloc *,uint16_t,uint16_t,lword);
extern bool isstdreloc(struct Reloc *,uint8_t,uint16_t);
extern struct Reloc *findreloc(struct Section *,unsigned long);
extern void addstabs(struct ObjectUnit *,struct Section *,char *,
                     uint8_t,int8_t,int16_t,uint32_t);
extern void fixstabs(struct ObjectUnit *);
extern struct TargetExt *addtargetext(struct Section *,uint8_t,uint8_t,uint16_t,
                                      uint32_t);
extern bool checktargetext(struct LinkedSection *,uint8_t,uint8_t);
extern lword readsection(struct GlobalVars *,uint8_t,uint8_t *,
                         uint16_t,uint16_t,lword);
extern lword writesection(struct GlobalVars *,uint8_t *,struct Reloc *,lword);
extern void calc_relocs(struct GlobalVars *,struct LinkedSection *);
extern void sort_relocs(struct list *);
extern struct Section *create_section(struct ObjectUnit *,const char *,
                                      uint8_t *,unsigned long);
extern struct Section *add_section(struct ObjectUnit *,const char *,
                                   uint8_t *,unsigned long,uint8_t,uint8_t,
                                   uint8_t,uint8_t,bool);
extern struct Section *common_section(struct GlobalVars *,struct ObjectUnit *);
extern struct Section *scommon_section(struct GlobalVars *,struct ObjectUnit *);
extern struct Section *abs_section(struct ObjectUnit *);
extern struct Section *dummy_section(struct GlobalVars *,struct ObjectUnit *);
extern struct LinkedSection *create_lnksect(struct GlobalVars *,const char *,
                                            uint8_t,uint8_t,uint8_t,uint8_t,
                                            uint32_t);
extern struct Section *find_sect_type(struct ObjectUnit *,uint8_t,uint8_t);
extern struct Section *find_sect_id(struct ObjectUnit *,uint32_t);
extern struct Section *find_sect_name(struct ObjectUnit *,const char *);
extern struct Section *find_first_bss_sec(struct LinkedSection *);
extern struct LinkedSection *find_lnksec(struct GlobalVars *,const char *,
                                         uint8_t,uint8_t,uint8_t,uint8_t);
extern struct LinkedSection *smalldata_section(struct GlobalVars *);
extern void add_objunit(struct GlobalVars *,struct ObjectUnit *,bool);
extern struct ObjectUnit *create_objunit(struct GlobalVars *,
                                         struct LinkFile *,const char *);
extern struct ObjectUnit *art_objunit(struct GlobalVars *,const char *,
                                      uint8_t *,unsigned long);
extern void collect_constructors(struct GlobalVars *);
extern void add_priptrs(struct GlobalVars *,struct ObjectUnit *);
extern void make_constructors(struct GlobalVars *);
extern void get_text_data_bss(struct GlobalVars *,struct LinkedSection **);
extern void text_data_bss_gaps(struct LinkedSection **);
extern bool discard_symbol(struct GlobalVars *,struct Symbol *);
extern lword entry_address(struct GlobalVars *gv);
extern struct Symbol *bss_entry(struct ObjectUnit *,const char *,
                                struct Symbol *);
extern struct SecAttrOvr *addsecattrovr(struct GlobalVars *,char *,uint32_t);
extern struct SecAttrOvr *getsecattrovr(struct GlobalVars *,const char *,
                                        uint32_t);
#endif

/* dir.c */
#ifndef DIR_C
extern char *path_append(char *,const char *,const char *,size_t);
extern char *open_dir(const char *);
extern char *read_dir(char *);
extern void close_dir(char *);
extern void set_exec(const char *);
#endif

/* ldscript.c */
#ifndef LDSCRIPT_C
extern bool is_ld_script(struct ObjectUnit *);
extern void update_address(struct MemoryDescr *,struct MemoryDescr *,
                           unsigned long);
extern void align_address(struct MemoryDescr *,struct MemoryDescr *,
                          unsigned long);
extern void free_patterns(char *,char **);
extern int test_pattern(struct GlobalVars *,char **,char ***);
extern int next_pattern(struct GlobalVars *,char **,char ***);
extern struct LinkedSection *next_secdef(struct GlobalVars *);
extern void init_secdef_parse(struct GlobalVars *);
extern void init_ld_script(struct GlobalVars *);
#endif

/* pmatch.c */
#ifndef PMATCH_C
extern bool pattern_match(const char *,const char *);
extern bool patternlist_match(char **,const char *);
#endif

/* expr.c */
#ifndef EXPR_C
extern void skip(void);
extern char getchr(void);
extern void skipblock(int,char,char);
extern void back(int);
extern char *gettxtptr(void);
extern char *getarg(uint8_t);
extern char *getquoted(void);
extern int parse_expr(lword,lword *);
extern int getlineno(void);
extern void init_parser(struct GlobalVars *,const char *,const char *,int);
#endif

/* t_amigaos.c */
#ifndef T_AMIGAOS_C
#if defined(ADOS) || defined(EHF)
extern struct FFFuncs fff_amigahunk;
extern struct FFFuncs fff_ehf;
#endif
#endif

/* t_ataritos.c */
#ifndef T_ATARITOS_C
#ifdef ATARI_TOS
extern struct FFFuncs fff_ataritos;
#endif
#endif

/* t_elf32ppcbe.c */
#ifndef T_ELF32PPCBE_C
#if defined(ELF32_PPC_BE)
extern struct FFFuncs fff_elf32ppcbe;
#endif
#if defined(ELF32_AMIGA)
extern struct FFFuncs fff_elf32powerup;
extern struct FFFuncs fff_elf32morphos;
extern struct FFFuncs fff_elf32amigaos;
#endif
#endif

/* t_elf32m68k.c */
#ifndef T_ELF32M68K_C
#ifdef ELF32_M68K
extern struct FFFuncs fff_elf32m68k;
#endif
#endif

/* t_elf32jag.c */
#ifndef T_ELF32JAG_C
#ifdef ELF32_JAG
extern struct FFFuncs fff_elf32jag;
#endif
#endif

/* t_elf32i386.c */
#ifndef T_ELF32I386_C
#ifdef ELF32_386
extern struct FFFuncs fff_elf32i386;
#endif
#ifdef ELF32_AROS
extern struct FFFuncs fff_elf32aros;
#endif
#endif

/* t_elf32arm.c */
#ifndef T_ELF32ARM_C
#ifdef ELF32_ARM_LE
extern struct FFFuncs fff_elf32armle;
#endif
#endif

/* t_elf64x86.c */
#ifndef T_ELF64X86_C
#ifdef ELF64_X86
extern struct FFFuncs fff_elf64x86;
#endif
#endif

/* t_aoutnull.c */
#ifndef T_AOUTNULL_C
#if defined(AOUT_NULL)
extern struct FFFuncs fff_aoutnull;
#endif
#endif

/* t_aoutm68k.c */
#ifndef T_AOUTM68K_C
#if defined(AOUT_SUN010)
extern struct FFFuncs fff_aoutsun010;
#endif
#if defined(AOUT_SUN020)
extern struct FFFuncs fff_aoutsun020;
#endif
#if defined(AOUT_BSDM68K)
extern struct FFFuncs fff_aoutbsd68k;
#endif
#if defined(AOUT_BSDM68K4K)
extern struct FFFuncs fff_aoutbsd68k4k;
#endif
#if defined(AOUT_JAGUAR)
extern struct FFFuncs fff_aoutjaguar;
#endif
#endif

/* t_aoutmint.c */
#ifndef T_AOUTMINT_C
#if defined(AOUT_MINT)
extern struct FFFuncs fff_aoutmint;
#endif
#endif

/* t_aouti386.c */
#ifndef T_AOUTI386_C
#if defined(AOUT_BSDI386)
extern struct FFFuncs fff_aoutbsdi386;
#endif
#if defined(AOUT_PC386)
extern struct FFFuncs fff_aoutpc386;
#endif
#endif

/* t_rawbin.c */
#ifndef T_RAWBIN_C
#if defined(RAWBIN1)
extern struct FFFuncs fff_rawbin1;
#endif
#if defined(RAWBIN2)
extern struct FFFuncs fff_rawbin2;
#endif
#if defined(AMSDOS)
extern struct FFFuncs fff_amsdos;
#endif
#if defined(CBMPRG)
extern struct FFFuncs fff_cbmprg;
#endif
#if defined(SREC19)
extern struct FFFuncs fff_srec19;
#endif
#if defined(SREC28)
extern struct FFFuncs fff_srec28;
#endif
#if defined(SREC37)
extern struct FFFuncs fff_srec37;
#endif
#if defined(IHEX)
extern struct FFFuncs fff_ihex;
#endif
#if defined(SHEX1)
extern struct FFFuncs fff_shex1;
#endif
#endif

/* t_rawseg.c */
#ifndef T_RAWSEG_C
#if defined(RAWSEG)
extern struct FFFuncs fff_rawseg;
#endif
#endif

/* t_vobj.c */
#ifndef T_VOBJ_C
#if defined(VOBJ)
extern struct FFFuncs fff_vobj_le;
extern struct FFFuncs fff_vobj_be;
#endif
#endif
