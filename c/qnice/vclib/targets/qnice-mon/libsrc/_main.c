/* modified for qnice to fix ctpr/dtor problem mismatch */

#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

struct __exitfuncs *__firstexit;

extern int main(int, char **);
extern void __exit();  /* from startup-code */

typedef void (*fp)(void);

/* from linker */
extern long __CTOR_LIST__[],__DTOR_LIST__[];

static int convptr(long)="\tshr\t1,R8\n"
                         "\tand\t1,R9\n"
                         "\trbra\t$+6,z\n"
                         "\tor\t32768,R8";

/* Specified in c99. */
void _Exit(int returncode)
{
  long *dtors;
  int i;

  if (dtors = __DTOR_LIST__) {
    for (i=1; dtors[i]; i++);
    while (--i) (*(fp)convptr(dtors[i]))();  /* call destructors */
  }

  __exit(returncode);
}


void exit(int returncode)
{
  static int in_exit = 0;

  if (!in_exit) {
    struct __exitfuncs *p=__firstexit;

    /* run atexit-functions */
    in_exit = 1;
    while(p) {
      p->func();
      p=p->next;
    }
    _Exit(returncode);
  }
}


/*
  This function has to be called by the startup-code.

  The startup-code typically has to:
  - setup hardware, stack etc. (if needed)
  - initialize variables (if needed)
  - parse command line (if needed)
  - call __main
*/

void __main(int argc,char **argv)
{
  long *ctors = __CTOR_LIST__;
  
  if (ctors++) {
    while (*ctors){
      (*(fp)convptr(*ctors))();  /* call constructors */
      ctors++;
    }
  }

  exit(main(argc,argv));
}
