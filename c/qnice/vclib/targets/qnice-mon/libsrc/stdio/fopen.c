#include <stddef.h>
#include <stdio.h>
#include <limits.h>
#include <stdarg.h>
#include <stdlib.h>

extern FILE *__firstfile,*__lastfile;


FILE *__open_file(const char *name,const char *mode,FILE *f)
{
  int append;
  const char *om=mode;

  if (*mode == 'a') append = 1; else append = 0;
  f->count = 0;
  f->base = 0;
  f->bufsize = 0;
  f->prev = 0;
  f->next = 0;
  if (*mode == 'r') f->flags = _READABLE; else f->flags = _WRITEABLE;
  if (*++mode == 'b') mode++;
#ifdef _CLE
  else f->flags |= _CLE;
  f->clebuf = -1;
#endif
  if (*mode == '+') f->flags |= _READABLE|_WRITEABLE;

  f->filehandle = __open(name,om);
  if (f->filehandle == -1) {
    free(f);
    return 0;
  }
#if HAVE_TTYS
  if (__isatty(f->filehandle)) {
    f->flags |= _LINEBUF|_ISTTY;
  }
#endif
  if (__lastfile) {
    __lastfile->next = f;
    f->prev = __lastfile;
    __lastfile = f;
  }
  else{
    __firstfile = __lastfile = f;
  }
  if (append) fseek(f,0,SEEK_END);
  return f;
}


FILE *fopen(const char *name,const char *mode)
{
  FILE *f;

  if (!(f = malloc(sizeof(FILE)))) return 0;
  return __open_file(name,mode,f);
}


void _EXIT_2_fopen(void)
{
  //while(__firstfile && !fclose(__firstfile));  /* close all open files */
}
