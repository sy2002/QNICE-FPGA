/* $VER: vlink ar.h V0.13 (02.11.10)
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


#define ARMAG     "!<arch>\n"   /* ar "magic number" */
#define SARMAG    8             /* strlen(ARMAG) */
#define AR_EFMT1  "#1/"         /* extended format #1, long names (BSD-ar) */ 
#define ARFMAG    "`\n"
#define MAXARNAME 255           /* max. size for file names */

struct ar_hdr {
  char ar_name[16];             /* name */
  char ar_date[12];             /* modification time */
  char ar_uid[6];               /* user id */
  char ar_gid[6];               /* group id */
  char ar_mode[8];              /* octal file permissions */
  char ar_size[10];             /* size in bytes */
  char ar_fmag[2];              /* consistency check */
};

struct ar_info {
  char *arname;                 /* name of this archive */
  struct ar_hdr *next;          /* next archive member header, or NULL */
  unsigned long arlen;          /* remaining bytes in archive */
  char *long_names;             /* pointer to long names region (GNU-ar) */
  char name[MAXARNAME+1];       /* null-terminated file name */
  struct ar_hdr *header;        /* current header */
  uint8_t *data;                 /* pointer to archive member */
  unsigned long size;           /*  and its size in bytes */
};


#ifndef AR_C
extern bool ar_init(struct ar_info *,char *,unsigned long,const char *);
extern bool ar_extract(struct ar_info *);
#endif
