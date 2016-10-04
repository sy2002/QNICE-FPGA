/* $VER: vlink dir.c V0.14a (07.08.11)
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


#define DIR_C
#include "vlink.h"

#ifdef AMIGAOS
#pragma amiga-align
#include <dos/dosextens.h>
#include <dos/dostags.h>
#include <proto/dos.h>
#pragma default-align

struct Dir {
  struct FileInfoBlock fib;
  BPTR lock;
  char name[FNAMEBUFSIZE];
};


#elif defined(ATARI)
#include <tos.h>
#define MAX_PATH_LEN 127

struct Dir {
  DTA dta;
  DTA *olddta;
  int err;
  char name[MAX_PATH_LEN+1];
};


#elif defined(_WIN32)
#include <windows.h>

struct Dir {
  WIN32_FIND_DATA fnd;
  HANDLE hndl;
  char name[MAX_PATH];
};


#else  /* UNIX */
#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#endif



char *path_append(char *buf,const char *path,const char *add,size_t bufsize)
/* append a file- or path-name to an existing path and convert */
{
  size_t len = strlen(path);
#if defined(AMIGAOS) || defined(_WIN32)
  char *p;
#endif

  if ((len+strlen(add)+1) < bufsize) {
    if (buf != path)
      strcpy(buf,path);

#if defined(AMIGAOS)
    if (len>0 && buf[len-1]!='/' && buf[len-1]!=':')
      buf[len++] = '/';
    strcpy(buf+len,add);
    path = p = buf;
    while (*path) {
      if (*path == '.') {
        if (*(path+1) == '\0') {
          path++;
          continue;
        }
        else if (*(path+1)=='/') {
          path += 2;
          continue;
        }
        else if (*(path+1)=='.' && *(path+2)=='/')
          path += 2;
      }
      *p++ = *path++;
    }
    *p = '\0';

#elif defined(_WIN32)
    if (len>0 && buf[len-1]!='\\' && buf[len-1]!='/' && buf[len-1]!=':')
      buf[len++] = '\\';
    strcpy(buf+len,add);
    for (p=buf; *p; *p++) {
      if (*p == '/')
        *p = '\\';
    }

#else
    if (len>0 && buf[len-1]!='/')
      buf[len++] = '/';
    strcpy(buf+len,add);
#endif

    return buf;
  }

  return NULL;
}


#ifdef AMIGAOS

char *open_dir(const char *dirname)
/* open a directory for examination */
{
  struct Dir *d;

  if (d = malloc(sizeof(struct Dir))) {
    strcpy(d->name,dirname);
    if (!strcmp(d->name,".")) {  /* current directory? */
      d->name[0] = 0;
    }
    if (d->lock = Lock(d->name,ACCESS_READ)) {
      if (Examine(d->lock,&(d->fib))) {
        return (char *)d;
      }
      UnLock(d->lock);
    }
    free(d);
  }
  return NULL;
}


char *read_dir(char *d)
/* get next file name from opened directory, NULL if no more entries */
{
  if (ExNext(((struct Dir *)d)->lock,&(((struct Dir *)d)->fib)))
    return ((struct Dir *)d)->fib.fib_FileName;
  if (IoErr() != ERROR_NO_MORE_ENTRIES)
    error(10,((struct Dir *)d)->name);
  return NULL;
}


void close_dir(char *d)
/* finish directory access */
{
  if (d) {
    UnLock(((struct Dir *)d)->lock);
    free(d);
  }
}


void set_exec(const char *path)
{
  SetProtection(path,0);  /* "rwed" */
}


#elif defined(ATARI)

char *open_dir(const char *dirname)
/* open a directory for examination */
{
  struct Dir *d;

  if (d = malloc(sizeof(struct Dir))) {
    strncpy(d->name,dirname,MAX_PATH_LEN);
    d->olddta = Fgetdta();
    Fsetdta(&d->dta);
    d->err = Fsfirst(d->name,FA_READONLY|FA_ARCHIVE);
    if (d->err != E_OK) {
      Fsetdta(d->olddta);
      free(d);
      d = NULL;
    }
  }
  return (char *)d;
}


char *read_dir(char *p)
/* get next file name from opened directory, NULL if no more entries */
{
  struct Dir *d = (struct Dir *)p;

  if (d->err == E_OK) {
    strncpy(d->name,d->dta.d_fname,MAX_PATH_LEN);
    d->err = Fsnext();
    return d->name;
  }
  return NULL;
}


void close_dir(char *d)
/* finish directory access */
{
  if (d) {
    Fsetdta(((struct Dir *)d)->olddta);
    free(d);
  }
}


void set_exec(const char *path)
{
  /* Fattrib() - no flag for executables exists? */
}


#elif defined(_WIN32)

char *open_dir(const char *dirname)
/* open a directory for examination */
{
  struct Dir *d;

  if (d = (struct Dir *)malloc(sizeof(struct Dir))) {
    wsprintf(d->name, "%s\\*", dirname);
    d->hndl = NULL;
  }
  return (char *)d;
}


char *read_dir(char *d)
/* get next file name from opened directory, NULL if no more entries */
{
  do {
    if (!((struct Dir *)d)->hndl) {
      ((struct Dir *)d)->hndl = FindFirstFile(((struct Dir *)d)->name,
                                              &((struct Dir *)d)->fnd);
      if (((struct Dir *)d)->hndl == INVALID_HANDLE_VALUE) {
        ((struct Dir *)d)->hndl = NULL;
        return NULL;
      }
    }
    else {
      if (!FindNextFile(((struct Dir *)d)->hndl, &((struct Dir *)d)->fnd))
        return NULL;
    }
  }
  while (((struct Dir *)d)->fnd.dwFileAttributes
         & (FILE_ATTRIBUTE_DIRECTORY |
            FILE_ATTRIBUTE_HIDDEN |
            FILE_ATTRIBUTE_OFFLINE));

  return (char *)((struct Dir *)d)->fnd.cFileName;
}


void close_dir(char *d)
/* finish directory access */
{
  if (d) {
    if (((struct Dir *)d)->hndl)
      FindClose(((struct Dir *)d)->hndl);
    free(d);
  }
}

/* @@@ FIXME! */
void set_exec(const char *path)
{
  chmod(path,0755);  /* rwxr-xr-x */
}


#else /* UNIX */

char *open_dir(const char *dirname)
/* open a directory for examination */
{
  return (char *)opendir(dirname);
}


char *read_dir(char *d)
/* get next file name from opened directory, NULL if no more entries */
{
  struct dirent *dp;

  if (dp = readdir((DIR *)d))
    return dp->d_name;
  return NULL;
}


void close_dir(char *d)
/* finish directory access */
{
  if (d)
    closedir((DIR *)d);
}


void set_exec(const char *path)
{
  chmod(path,0755);  /* rwxr-xr-x */
}

#endif
