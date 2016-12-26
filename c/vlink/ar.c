/* $VER: vlink ar.c V0.13 (02.11.10)
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


#define AR_C
#include "vlink.h"


bool ar_init(struct ar_info *ai,char *p,unsigned long plen,const char *name)
/* check for valid archive header and initialize ar_info, if successful */
{
  /* check for "!<arch>\n" id */
  if (plen<SARMAG || strncmp(p,ARMAG,SARMAG))
    return FALSE;

  memset(ai,0,sizeof(struct ar_hdr));
  ai->arname = (char *)name;
  ai->next = (struct ar_hdr *)(p+SARMAG);
  ai->arlen = plen - SARMAG;
  return TRUE;
}


bool ar_extract(struct ar_info *ai)
/* fill ar_info structure with informations about the next */
/* archive member */
{
  struct ar_hdr *ah;
  uint8_t *p;
  bool cont;
  unsigned long size;

  do {
    cont = FALSE;
    if (ai->next==NULL || ai->arlen<sizeof(struct ar_hdr))
      return FALSE;  /* archive ends here */

    ah = ai->next;
    p = ((uint8_t *)ah) + sizeof(struct ar_hdr);
    ai->arlen -= sizeof(struct ar_hdr);
    ai->name[0] = 0;
    sscanf(ah->ar_size,"%lu",&ai->size);  /* file size */

    if (!strncmp(ah->ar_name,"/ ",2) ||             /* GNU symbol table */
        !strncmp(ah->ar_name,"__.SYMDEF ",10))      /* BSD symbol table */
      cont = TRUE;

    if (!strncmp(ah->ar_name,"ARFILENAMES/",12) ||  /* GNU long names 1 */
        !strncmp(ah->ar_name,"// ",3)) {            /* GNU long names 2 */
      ai->long_names = (char *)p;
      cont = TRUE;
    }

    if (ai->long_names &&                           /* long name (GNU) */
        (ah->ar_name[0]=='/' || ah->ar_name[0]==' ') &&
        (ah->ar_name[1]>='0' && ah->ar_name[1]<='9')) {
      int i,offset;
      char c,*s,*d=ai->name;

      sscanf(&ah->ar_name[1],"%d",&offset);  /* name offset */
      s = ai->long_names + offset;
      for (i=0; i<MAXARNAME; i++) {
        c = *s++;
        if (c==0 || c=='/' || c=='\n')
          break;
        *d++ = c;
      }
      *d = 0;
    }
    else if (!strncmp(ah->ar_name,"#1/",3)) {  /* ext. name fmt. #1 (BSD) */
      int d,len;

      sscanf(&ah->ar_name[3],"%d",&d);  /* ext.fmt. name length */
      if (d > ai->arlen)
        error(37,ai->arname,ai->name);  /* Malformatted archive member */
      len = (d>MAXARNAME) ? MAXARNAME : d;
      memcpy(ai->name,p,len);
      ai->name[len] = 0;
      p += d;  /* set real beginning of file and size */
      ai->size -= d;
      ai->arlen -= d;
    }
    else {  /* normal file name < 16 chars */
      char *n = &ah->ar_name[16];
      int len;

      for (len=16; len>0; len--)
        if (*(--n) != ' ')
          break;
      if (len && *n=='/')  /* GNU */
        --len;
      memcpy(ai->name,ah->ar_name,len);
      ai->name[len] = 0;
    }

    if (strncmp(ah->ar_fmag,ARFMAG,2))
      error(42,ai->arname,ai->name);  /* consistency check failed */
    ai->header = ah;
    ai->data = p;
    size = ((unsigned long)(p + ai->size) & 1) ? (ai->size+1) : ai->size;
    ai->next = (struct ar_hdr *)(p + size);
    if ((long)(ai->arlen -= size) < 0)
      error(37,ai->arname,ai->name);  /* Malformatted archive member */
  }
  while (cont);
  return TRUE;
}
