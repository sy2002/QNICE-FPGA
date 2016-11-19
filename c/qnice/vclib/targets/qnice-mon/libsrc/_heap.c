#include <stdlib.h>

#define HEAPSIZE (512)

char __heap[HEAPSIZE],*__heapptr=__heap;
size_t __heapsize=HEAPSIZE;
