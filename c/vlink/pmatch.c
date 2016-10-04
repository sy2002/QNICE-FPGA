/* $VER: vlink pmatch.c V0.9f (04.08.04)
 *
 * This file is part of vlink, a portable linker for multiple
 * object formats.
 * Copyright (c) 1997-2005  Frank Wille
 *
 * vlink is freeware and part of the portable and retargetable ANSI C
 * compiler vbcc, copyright (c) 1995-2005 by Volker Barthelmann.
 * vlink may be freely redistributed as long as no modifications are
 * made and nothing is charged for it. Non-commercial usage is allowed
 * without any restrictions.
 * EVERY PRODUCT OR PROGRAM DERIVED DIRECTLY FROM MY SOURCE MAY NOT BE
 * SOLD COMMERCIALLY WITHOUT PERMISSION FROM THE AUTHOR.
 */


#define PMATCH_C
#include "vlink.h"

#ifdef AMIGAOS
#pragma amiga-align
#include <dos/dos.h>
#include <proto/dos.h>
#pragma default-align

#elif defined(_WIN32) || defined(ATARI)
/* portable pattern matching routines - no headers */

#elif defined(_SGI_SOURCE)
#include <libgen.h>

#else /* UNIX */
#include <fnmatch.h>
#endif



#ifdef AMIGAOS

bool pattern_match(const char *pat,const char *str)
{
  char c;
  char *pat1,*pat2;
  LONG len;
  bool rc = FALSE;

  /* convert Unix to AmigaDos pattern */
  pat2 = pat1 = alloc(2*strlen(pat)+1);
  while (c = *pat++) {
    if (c == '*') {
      *pat2++ = '#';
      *pat2++ = '?';
    }
    else
      *pat2++ = c;
  }
  *pat2 = '\0';

  /* tokenize pattern and match it against str */
  len = 2*strlen(pat1)+3;
  pat2 = alloc(len);
  if (ParsePattern((STRPTR)pat1,(STRPTR)pat2,len) >= 0) {
    if (MatchPattern((STRPTR)pat2,(STRPTR)str))
      rc = TRUE;
  }
  else
    ierror("pattern_match(): ParsePattern() failed for \"%s\"",pat);

  free(pat2);
  free(pat1);
  return (rc);
}


#elif defined(_WIN32) || defined(ATARI)

static bool portable_pattern_match(const char *mask, const char *name)
{
  int           wild  = 0,
                q     = 0;
  const char  * m     = mask,
              * n     = name,
              * ma    = mask,
              * na    = name;

  for(;;) {
    if (*m == '*') {
      while (*m == '*')
        ++m;
      wild = 1;
      ma = m;
      na = n;
    }
    if (!*m) {
      if (!*n)
        return(FALSE);
      for (--m; (m > mask) && (*m == '?'); --m);
      if ((*m == '*') && (m > mask) && (m[-1] != '\\'))
        return(FALSE);
      if (!wild)
        return(TRUE);
      m = ma;
    }
    else if (!*n) {
      while(*m == '*')
        ++m;
      return(*m != 0);
    }
    if ((*m == '\\') && ((m[1] == '*') || (m[1] == '?'))) {
      ++m;
      q = 1;
    }
    else {
      q = 0;
    }
    if ((tolower(*m) != tolower(*n)) && ((*m != '?') || q)) {
      if (!wild)
        return(TRUE);
      m = ma;
      n = ++na;
    }
    else {
      if (*m) ++m;
      if (*n) ++n;
    }
  }
}


bool pattern_match(const char *mask, const char *name)
{
  return !portable_pattern_match(mask,name);
}


#else /* UNIX */

bool pattern_match(const char *pat,const char *str)
{
#ifdef _SGI_SOURCE
  return (gmatch(str,pat) != 0);
#else
  return (fnmatch(pat,str,0) == 0);
#endif
}


#endif


bool patternlist_match(char **patlist,const char *str)
/* match string against a list of patterns */
{
  if (patlist) {
    while (*patlist) {
      if (pattern_match(*patlist,str))
        return (TRUE);
      patlist++;
    }
  }
  return (FALSE);
}
