#include <stdio.h>

extern FILE *__firstfile,*__lastfile;


int fclose(FILE *f)
{
  if (!f) return EOF;
  if (f->filehandle == -1) return EOF;
  fflush(f);
  if ((unsigned int) f->filehandle > 2) { /* patched by sy2002 in August 2022: we need (unsigned int) for this comparison */
    __close(f->filehandle);
  }
  if (f->prev) f->prev->next = f->next; else __firstfile = f->next;
  if (f->next) f->next->prev = f->prev; else __lastfile = f->prev;
  if (f->base && !(f->flags&_NOTMYBUF)) free(f->base-1);
  free(f);
  return 0;
}
