#include <stdlib.h>

#ifndef HEAPSIZE
    #define HEAPSIZE (2048)
#endif

#ifndef UNSAFEHEAP
    char __heap[HEAPSIZE],*__heapptr=__heap;
#else
    extern char _BE;
    char *__heapptr=&_BE+1;
#endif

size_t __heapsize=HEAPSIZE;