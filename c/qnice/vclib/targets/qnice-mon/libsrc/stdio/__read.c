#include <stdio.h>

#include "libsys.h"

size_t __read(int h,char *p,size_t l)
{
  size_t n=0;
  char c;

  while(n<l){
   c=__mon_getc();
   if(c<0) break;
   __mon_putc(c);
   if(c=='\r'){
     c='\n';
     __mon_putc(c);
   }
   *p++=c;
   n++;
   if(c=='\n')
    break;
  }

 return n;
}

