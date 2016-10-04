/* $VER: vlink elf64.h V0.14 (13.06.11)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2011  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2011 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#include "elfcommon.h"

struct Elf64_Ehdr {
  unsigned char	e_ident[EI_NIDENT];	/* ELF "magic number" */
  unsigned char	e_type[2];          /* Identifies object file type */
  unsigned char	e_machine[2];       /* Specifies required architecture */
  unsigned char	e_version[4];       /* Identifies object file version */
  unsigned char	e_entry[8];         /* Entry point virtual address */
  unsigned char	e_phoff[8];         /* Program header table file offset */
  unsigned char	e_shoff[8];         /* Section header table file offset */
  unsigned char	e_flags[4];         /* Processor-specific flags */
  unsigned char	e_ehsize[2];        /* ELF header size in bytes */
  unsigned char	e_phentsize[2];     /* Program header table entry size */
  unsigned char	e_phnum[2];         /* Program header table entry count */
  unsigned char	e_shentsize[2];     /* Section header table entry size */
  unsigned char	e_shnum[2];         /* Section header table entry count */
  unsigned char	e_shstrndx[2];      /* Section header string table index */
};

struct Elf64_Phdr {
  unsigned char p_type[4];          /* Identifies program segment type */
  unsigned char p_flags[4];         /* Segment flags */
  unsigned char p_offset[8];        /* Segment file offset */
  unsigned char p_vaddr[8];         /* Segment virtual address */
  unsigned char p_paddr[8];         /* Segment physical address */
  unsigned char p_filesz[8];        /* Segment size in file */
  unsigned char p_memsz[8];         /* Segment size in memory */
  unsigned char p_align[8];         /* Segment alignment, file & memory */
};

struct Elf64_Shdr {
  unsigned char sh_name[4];         /* Section name, index in string tbl */
  unsigned char sh_type[4];         /* Type of section */
  unsigned char sh_flags[8];        /* Miscellaneous section attributes */
  unsigned char sh_addr[8];         /* Section virtual addr at execution */
  unsigned char sh_offset[8];       /* Section file offset */
  unsigned char sh_size[8];         /* Size of section in bytes */
  unsigned char sh_link[4];         /* Index of another section */
  unsigned char sh_info[4];         /* Additional section information */
  unsigned char sh_addralign[8];    /* Section alignment */
  unsigned char sh_entsize[8];      /* Entry size if section holds table */
};

struct Elf64_Sym {
  unsigned char st_name[4];         /* Symbol name, index in string tbl */
  unsigned char st_info[1];         /* Type and binding attributes */
  unsigned char st_other[1];        /* No defined meaning, 0 */
  unsigned char st_shndx[2];        /* Associated section index */
  unsigned char st_value[8];        /* Value of the symbol */
  unsigned char st_size[8];         /* Associated symbol size */
};
#define ELF64_ST_BIND(i) ((i)>>4)
#define ELF64_ST_TYPE(i) ((i)&0xf)
#define ELF64_ST_INFO(b,t) (((b)<<4)+((t)&0xf))

struct Elf64_Note {
  unsigned char namesz[4];          /* Size of entry's owner string */
  unsigned char descsz[4];          /* Size of the note descriptor */
  unsigned char type[4];            /* Interpretation of the descriptor */
  char          name[1];            /* Start of the name+desc data */
};

struct Elf64_Rel {
  unsigned char r_offset[8];    /* Location at which to apply the action */
  unsigned char r_info[8];      /* index and type of relocation */
};

struct Elf64_Rela {
  unsigned char r_offset[8];    /* Location at which to apply the action */
  unsigned char r_info[8];      /* index and type of relocation */
  unsigned char r_addend[8];    /* Constant addend used to compute value */
};

#define ELF64_R_SYM(i) ((i) >> 32)
#define ELF64_R_TYPE(i)	((i) & 0xffffffff)
#define ELF64_R_INFO(sym,type) (((sym) << 32) + (type))

struct Elf64_Dyn {
  unsigned char d_tag[8];           /* entry tag value */
  union {
    unsigned char d_val[8];
    unsigned char d_ptr[8];
  } d_un;
};
