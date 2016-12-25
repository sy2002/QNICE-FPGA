/*
  Functions to get suitably aligned core memory from the
  environment and return it (if possible).
*/

/*
  Simple implementation, assuming a single memory block allocated
  as heap, e.g. for stand-alone systems. Unix systems might provide brk
  or sbrk system calls.
*/

/*
    comment by sy2002 in December 2016:
    
    QNICE contraint and TODO:
    either implement some reasonable memory management on operating
    system level OR implement some more sophisticated heap management
    here, particularly we need to be able to free core memory.

    For now, as long as we have 4096 words of heap and a TRESHOLD
    (see Makefile) of 1022 (= 4088 words plus space for management info),
    everything will work fine.
*/

#include <stdlib.h>

extern char *__heapptr;
extern size_t __heapsize;

void *__getcore(size_t s)
{
  /* If the block is aligned at the beginning, this is sufficient,
     because malloc() will only ask for multiples of memblocks. */
  void *tmp;

  if(s>__heapsize)
    return 0;

  tmp=(void *)__heapptr;
  __heapptr+=s;
  __heapsize-=s;
  return tmp;
}

void __freecore(void *p,size_t s){}
