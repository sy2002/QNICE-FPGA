/* $VER: vlink elfcommon.h V0.15a (22.01.15)
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


#ifndef ELFCOMMON_H
#define ELFCOMMON_H


#define ELF_VER 1

/* e_indent indexes */
#define EI_NIDENT  16
#define EI_MAG0    0
#define EI_MAG1    1
#define EI_MAG2    2
#define EI_MAG3    3
#define EI_CLASS   4
#define EI_DATA    5
#define EI_VERSION 6
#define EI_PAD     7

/* EI_CLASS */
#define ELFCLASSNONE 0
#define ELFCLASS32   1
#define ELFCLASS64   2

/* EI_DATA */
#define ELFDATANONE 0
#define ELFDATA2LSB 1
#define ELFDATA2MSB 2

/* e_type */
#define ET_NONE   0                 /* No file type */
#define ET_REL    1                 /* Relocatable file */
#define ET_EXEC   2                 /* Executable file */
#define ET_DYN    3                 /* Shared object file */
#define ET_CORE   4                 /* Core file */
#define ET_NUM    5                 /* Number of defined types */
#define ET_LOOS   0xFE00            /* OS-specific range start */
#define ET_HIOS   0xFEFF            /* OS-specific range end */
#define ET_LOPROC 0xFF00            /* Processor-specific */
#define ET_HIPROC 0xFFFF            /* Processor-specific */

/* e_version */
#define EV_NONE    0
#define EV_CURRENT 1

/* e_machine */
#define EM_NONE           0
#define EM_M32            1
#define EM_SPARC          2
#define EM_386            3
#define EM_68K            4
#define EM_88K            5
#define EM_860            7
#define EM_MIPS           8
#define EM_MIPS_RS4_BE    10
#define EM_SPARC64        11
#define EM_PARISC         15
#define EM_PPC_OLD        17
#define EM_SPARC32PLUS    18
#define EM_PPC            20
#define EM_ARM            40
#define EM_COLDFIRE       52
#define EM_68HC12         53
#define EM_X86_64         62
#define EM_JAGRISC        0x9004
#define EM_CYGNUS_POWERPC 0x9025
#define EM_ALPHA          0x9026

/* values for program header, p_type field */
#define PT_NULL         0           /* Program header table entry unused */
#define PT_LOAD         1           /* Loadable program segment */
#define PT_DYNAMIC      2           /* Dynamic linking information */
#define PT_INTERP       3           /* Program interpreter */
#define PT_NOTE         4           /* Auxiliary information */
#define PT_SHLIB        5           /* Reserved, unspecified semantics */
#define PT_PHDR         6           /* Entry for header table itself */
#define PT_TLS          7           /* Thread-local storage segment */
#define PT_NUM          8           /* Number of defined types */
#define PT_LOOS         0x60000000  /* Start of OS-specific */
#define PT_GNU_EH_FRAME 0x6474e550  /* GCC .eh_frame_hdr segment */
#define PT_GNU_STACK    0x6474e551  /* Indicates stack executability */
#define PT_GNU_RELRO    0x6474e552  /* Read-only after relocation */
#define PT_LOSUNW       0x6ffffffa
#define PT_SUNWBSS      0x6ffffffa  /* Sun Specific segment */
#define PT_SUNWSTACK    0x6ffffffb  /* Stack segment */
#define PT_HISUNW       0x6fffffff
#define PT_HIOS         0x6fffffff  /* End of OS-specific */
#define PT_LOPROC       0x70000000  /* Processor-specific */
#define PT_HIPROC       0x7FFFFFFF  /* Processor-specific */

/* Program segment permissions, in program header p_flags field */
#define PF_X        (1 << 0)        /* Segment is executable */
#define PF_W        (1 << 1)        /* Segment is writable */
#define PF_R        (1 << 2)        /* Segment is readable */
#define PF_MASKOS   0x0FF00000      /* OS-specific */
#define PF_MASKPROC 0xF0000000      /* Processor-specific reserved bits */

/* special sections indexes */
#define SHN_UNDEF 0
#define SHN_ABS 0xfff1
#define SHN_COMMON 0xfff2

/* sh_type */
#define SHT_NULL          0           /* Section header table entry unused */
#define SHT_PROGBITS      1           /* Program specific (private) data */
#define SHT_SYMTAB        2           /* Link editing symbol table */
#define SHT_STRTAB        3           /* A string table */
#define SHT_RELA          4           /* Relocation entries with addends */
#define SHT_HASH          5           /* A symbol hash table */
#define SHT_DYNAMIC       6           /* Information for dynamic linking */
#define SHT_NOTE          7           /* Information that marks file */
#define SHT_NOBITS        8           /* Section occupies no space in file */
#define SHT_REL           9           /* Relocation entries, no addends */
#define SHT_SHLIB         10          /* Reserved, unspecified semantics */
#define SHT_DYNSYM        11          /* Dynamic linking symbol table */
#define SHT_INIT_ARRAY    14          /* Array of constructors */
#define SHT_FINI_ARRAY    15          /* Array of destructors */
#define SHT_PREINIT_ARRAY 16          /* Array of pre-constructors */
#define SHT_GROUP         17          /* Section group */
#define SHT_SYMTAB_SHNDX  18          /* Extended section indeces */ 
#define SHT_NUM           19          /* Number of defined types.  */
#define SHT_LOOS          0x60000000  /* Start OS-specific */   
#define SHT_GNU_LIBLIST   0x6ffffff7  /* Prelink library list */
#define SHT_CHECKSUM      0x6ffffff8  /* Checksum for DSO content.  */
#define SHT_LOSUNW        0x6ffffffa  /* Sun-specific low bound.  */
#define SHT_SUNW_move     0x6ffffffa
#define SHT_SUNW_COMDAT   0x6ffffffb
#define SHT_SUNW_syminfo  0x6ffffffc
#define SHT_GNU_verdef    0x6ffffffd  /* Version definition section.  */
#define SHT_GNU_verneed   0x6ffffffe  /* Version needs section.  */
#define SHT_GNU_versym    0x6fffffff  /* Version symbol table.  */   
#define SHT_HISUNW        0x6fffffff  /* Sun-specific high bound.  */
#define SHT_HIOS          0x6fffffff  /* End OS-specific type */
#define SHT_LOPROC        0x70000000  /* Processor-specific semantics, lo */
#define SHT_HIPROC        0x7FFFFFFF  /* Processor-specific semantics, hi */
#define SHT_LOUSER        0x80000000  /* Application-specific semantics */
#define SHT_HIUSER        0x8FFFFFFF  /* Application-specific semantics */

/* sh_flags */
#define SHF_WRITE            (1 << 0)   /* Writable data during execution */
#define SHF_ALLOC            (1 << 1)   /* Occupies memory during execution */
#define SHF_EXECINSTR        (1 << 2)   /* Executable machine instructions */
#define SHF_MERGE            (1 << 4)   /* Might be merged */
#define SHF_STRINGS          (1 << 5)   /* Contains nul-terminated strings */
#define SHF_INFO_LINK        (1 << 6)   /* `sh_info' contains SHT index */  
#define SHF_LINK_ORDER       (1 << 7)   /* Preserve order after combining */
#define SHF_OS_NONCONFORMING (1 << 8)   /* Non-standard OS specific handling
                                           required */
#define SHF_GROUP            (1 << 9)   /* Section is member of a group.  */  
#define SHF_TLS              (1 << 10)  /* Section hold thread-local data.  */
#define SHF_MASKOS           0x0ff00000 /* OS-specific.  */
#define SHF_MASKPROC         0xf0000000 /* Processor-specific */
#define SHF_ORDERED          (1 << 30)  /* Special ordering requirement
                                           (Solaris).  */
#define SHF_EXCLUDE          (1 << 31)  /* Section is excluded unless
                                           referenced or allocated (Solaris).*/

/* Values of note segment descriptor types for core files. */
#define NT_PRSTATUS 1               /* Contains copy of prstatus struct */
#define NT_FPREGSET 2               /* Contains copy of fpregset struct */
#define NT_PRPSINFO 3               /* Contains copy of prpsinfo struct */

#define STN_UNDEF 0                 /* undefined symbol index */

/* ST_BIND */
#define STB_LOCAL  0                /* Symbol not visible outside obj */
#define STB_GLOBAL 1                /* Symbol visible outside obj */
#define STB_WEAK   2                /* Like globals, lower precedence */
#define STB_NUM    3                /* Number of defined types.  */
#define STB_LOOS   10               /* Start of OS-specific */
#define STB_HIOS   12               /* End of OS-specific */
#define STB_LOPROC 13               /* Application-specific semantics */
#define STB_HIPROC 15               /* Application-specific semantics */

/* ST_TYPE */
#define STT_NOTYPE  0               /* Symbol type is unspecified */
#define STT_OBJECT  1               /* Symbol is a data object */
#define STT_FUNC    2               /* Symbol is a code object */
#define STT_SECTION 3               /* Symbol associated with a section */
#define STT_FILE    4               /* Symbol gives a file name */
#define STT_COMMON  5               /* Symbol is a common data object */
#define STT_TLS     6               /* Symbol is thread-local data object*/
#define STT_NUM     7               /* Number of defined types.  */  
#define STT_LOOS    10              /* Start of OS-specific */
#define STT_HIOS    12              /* End of OS-specific */
#define STT_LOPROC  13              /* Application-specific semantics */
#define STT_HIPROC  15              /* Application-specific semantics */

/* Dynamic section tags */
#define DT_NULL         0
#define DT_NEEDED       1
#define DT_PLTRELSZ     2
#define DT_PLTGOT       3
#define DT_HASH         4
#define DT_STRTAB       5
#define DT_SYMTAB       6
#define DT_RELA         7
#define DT_RELASZ       8
#define DT_RELAENT      9
#define DT_STRSZ        10
#define DT_SYMENT       11
#define DT_INIT         12
#define DT_FINI         13
#define DT_SONAME       14
#define DT_RPATH        15
#define DT_SYMBOLIC     16
#define DT_REL          17
#define DT_RELSZ        18
#define DT_RELENT       19
#define DT_PLTREL       20
#define DT_DEBUG        21
#define DT_TEXTREL      22
#define DT_JMPREL       23
#define DT_BIND_NOW     24          /* Process relocations of object */
#define DT_INIT_ARRAY   25          /* Array with addresses of init fct */
#define DT_FINI_ARRAY   26          /* Array with addresses of fini */
#define DT_INIT_ARRAYSZ 27          /* Size in bytes of DT_INIT_ARRAY */  
#define DT_FINI_ARRAYSZ 28          /* Size in bytes of DT_FINI */
#define DT_RUNPATH      29          /* Library search path */
#define DT_FLAGS        30          /* Flags for the object being loaded */
#define DT_ENCODING     32          /* Start of encoded range */
#define DT_PREINIT_ARRAY 32         /* Array with addresses of preinit fct */
#define DT_PREINIT_ARRAYSZ 33       /* size in bytes of DT_PREINIT_ARRAY */
#define DT_NUM          34          /* Number used */
#define DT_LOOS         0x6000000d  /* Start of OS-specific */
#define DT_HIOS         0x6ffff000  /* End of OS-specific */
#define DT_LOPROC       0x70000000
#define DT_HIPROC       0x7fffffff


/* common ELF32/64 header */
struct Elf_CommonHdr {
  unsigned char e_ident[EI_NIDENT]; /* ELF "magic number" */
  unsigned char e_type[2];          /* Identifies object file type */
  unsigned char e_machine[2];       /* Specifies required architecture */
  unsigned char e_version[4];       /* Identifies object file version */ 
  /* the rest differs between ELF32 and ELF64 */
};


#define STRHTABSIZE    0x10000
#define SHSTRHTABSIZE  0x100
#define DYNSTRHTABSIZE 0x1000
#define DYNSYMHTABSIZE 0x1000
#define STABHTABSIZE   0x1000

struct StrTabNode {
  struct node n;
  struct StrTabNode *hashchain;
  const char *str;
  uint32_t index;
};

struct StrTabList {
  struct list l;
  struct StrTabNode **hashtab;
  size_t htabsize;
  uint32_t nextindex;
};

struct SymbolNode {
  struct node n;
  struct SymbolNode *hashchain;
  void *elfsym;
  const char *name;
  uint32_t index;
  uint16_t shndx;
};

struct SymTabList {
  struct list l;
  struct StrTabList *strlist;
  struct SymbolNode **hashtab;
  size_t htabsize;
  size_t elfsymsize;
  uint32_t nextindex;
  uint32_t globalindex;
  void (*initsym)(void *,uint32_t,uint64_t,uint64_t,uint8_t,uint8_t,
                  uint16_t,bool);
};

struct DynSymNode {             /* links vlink symbol with .dynsym-symbol */
  struct node n;
  struct Symbol *sym;           /* pointer to vlink symbol */
  uint32_t idx;                 /* index of ELF symbol in .dynsym */
};

struct RelocList {
  struct list l;
  size_t relasize;
  size_t writesize;
  void (*initreloc)(void *,uint64_t,uint64_t,uint32_t,uint32_t,bool);
};

struct RelocNode {
  struct node n; 
  void *elfreloc;
};

/* for conversion from ELF reloc types to vlink internal format */
struct ELF2vlink {
  uint8_t rtype;
  uint16_t bpos;
  uint16_t bsiz;
  lword mask;
};

/* Linker symbol IDs */
#define SDABASE         0   /* _SDA_BASE_ */
#define SDA2BASE        1   /* _SDA2_BASE_ */
#define CTORS           2   /* __CTOR_LIST__ */
#define DTORS           3   /* __DTOR_LIST__ */
#define GLOBOFFSTAB     4   /* _GLOBAL_OFFSET_TABLE_ */
#define PROCLINKTAB     5   /* _PROCEDURE_LINKAGE_TABLE_ */
#define DYNAMICSYM      6   /* _DYNAMIC */


/* global data from t_elf.c */
#ifndef ELF_C
extern struct StrTabList elfshstrlist;
extern struct StrTabList elfstringlist;
extern struct StrTabList elfdstrlist;
extern struct SymTabList elfsymlist;
extern struct SymTabList elfdsymlist;
extern struct list shdrlist;
extern struct list elfdynsymlist;
extern struct Section *elfdynrelocs;       
extern struct Section *elfpltrelocs; 
extern int8_t elf_endianess;
extern uint32_t elfshdridx,elfsymtabidx,elfshstrtabidx,elfstrtabidx;
extern uint32_t elfoffset;
extern unsigned long elf_file_hdr_gap;
extern const char note_name[];
extern const char dyn_name[];
extern const char hash_name[];
extern const char dynsym_name[];
extern const char dynstr_name[];
extern const char *dynrel_name[2];
extern const char *pltrel_name[2];
#endif


/* Prototypes from elf.c */

/* functions for reading */
int elf_identify(struct FFFuncs *,char *,void *,lword,unsigned char,
                 unsigned char,uint16_t,uint32_t);
void elf_check_ar_type(struct FFFuncs *,const char *,void *,unsigned char,
                       unsigned char,uint32_t,int,...);
void elf_check_offset(struct LinkFile *,char *,void *,lword);
struct Section *elf_add_section(struct GlobalVars *,struct ObjectUnit *,
                                char *,uint8_t *,lword,uint32_t,
                                uint64_t,uint8_t);
void elf_add_symbol(struct GlobalVars *,struct ObjectUnit *,char *,uint8_t,
                    int,uint32_t,uint8_t,uint8_t,lword,uint32_t);

/* functions for linking */
int elf_targetlink(struct GlobalVars *,struct LinkedSection *,
                   struct Section *);
struct Symbol *elf_makelnksym(struct GlobalVars *,int);
struct Symbol *elf_lnksym(struct GlobalVars *,struct Section *,
                          struct Reloc *);
void elf_setlnksym(struct GlobalVars *,struct Symbol *);
struct Section *elf_dyntable(struct GlobalVars *,unsigned long,unsigned long,
                             uint8_t,uint8_t,uint8_t,int);
void elf_adddynsym(struct Symbol *);
void elf_dynreloc(struct ObjectUnit *,struct Reloc *,int,size_t);
struct Section *elf_initdynlink(struct GlobalVars *);
struct Symbol *elf_pltgotentry(struct GlobalVars *,struct Section *,DynArg,
                               uint8_t,unsigned long,unsigned long,int,
                               bool,size_t,size_t);
struct Symbol *elf_bssentry(struct GlobalVars *,const char *,struct Symbol *,
                            bool,size_t,size_t);
size_t elf_num_buckets(size_t);
void elf_putsymtab(uint8_t *,struct SymTabList *);

/* functions for writing */
unsigned long elf_numsegments(struct GlobalVars *);
uint8_t elf_getinfo(struct Symbol *);
uint8_t elf_getbind(struct Symbol *);
uint16_t elf_getshndx(struct GlobalVars *,struct Symbol *,uint8_t);
void elf_putstrtab(uint8_t *,struct StrTabList *);
uint32_t elf_addstrlist(struct StrTabList *,const char *);
uint32_t elf_addshdrstr(const char *);
uint32_t elf_addstr(const char *);
uint32_t elf_adddynstr(const char *);
uint32_t elf_addsym(struct SymTabList *,const char *,uint64_t,uint64_t,
                    uint8_t,uint8_t,uint16_t);
void elf_initsymlist(struct SymTabList *,struct StrTabList *,size_t,size_t,
                     void (*)(void *,uint32_t,uint64_t,uint64_t,
                              uint8_t,uint8_t,uint16_t,bool));
struct SymbolNode *elf_findSymNode(struct SymTabList *,const char *);
uint32_t elf_extsymidx(struct SymTabList *sl,const char *);
void elf_ident(void *,bool,uint8_t,uint16_t,uint16_t);
void elf_stdsymtab(struct GlobalVars *,uint8_t,uint8_t);
void elf_addsymlist(struct GlobalVars *,struct SymTabList *,uint8_t,uint8_t);
uint32_t elf_segmentcheck(struct GlobalVars *,size_t);
void elf_makeshdrs(struct GlobalVars *,
                   void (*)(struct LinkedSection *,bool,uint64_t));
struct RelocList *elf_newreloclist(size_t,size_t,
                                   void (*)(void *,uint64_t,uint64_t,
                                            uint32_t,uint32_t,bool));
void elf_addrelocnode(struct RelocList *,uint64_t,uint64_t,
                      uint32_t,uint32_t,bool);
size_t elf_addrela(struct GlobalVars *,struct LinkedSection *,struct Reloc *,
                   bool,struct RelocList *,uint8_t (*)(struct Reloc *));
void elf_initoutput(struct GlobalVars *,uint32_t,int8_t);
void elf_initsymtabs(size_t,void (*)(void *,uint32_t,uint64_t,uint64_t,
                                     uint8_t,uint8_t,uint16_t,bool));
void elf_writesegments(struct GlobalVars *,FILE *);
void elf_writesections(struct GlobalVars *,FILE *f);
void elf_writestrtab(FILE *,struct StrTabList *);
void elf_writesymtab(FILE *,struct SymTabList *);
void elf_writerelocs(FILE *,struct RelocList *);

#endif
