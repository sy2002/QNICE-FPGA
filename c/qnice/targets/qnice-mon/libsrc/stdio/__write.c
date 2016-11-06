#include <stdio.h>
#include "libsys.h"

size_t __write(int h,const char *p,size_t l)
{
  size_t i;
  for(i=l;i;i--)
    __mon_putc(*p++);
  return l;
}

