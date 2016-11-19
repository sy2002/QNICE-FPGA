#ifndef __STDARG_H
#define __STDARG_H 1

#error stdarg.h has to be overridden by a machine-specific version!

/*
  This is an example for a machine with arguments passed on the
  stack and a stackpointer which always will be aligned on a
  4byte boundary.

  Completely dependent on the architecture and ABI.

  In many cases special backend-support will be needed!
*/


typedef unsigned char *va_list;

#define __va_align(type) (__alignof(type)>=4?__alignof(type):4)

#define __va_do_align(vl,type) ((vl)=(char *)((((unsigned int)(vl))+__va_align(type)-1)/__va_align(type)*__va_align(type)))

#define __va_mem(vl,type) (__va_do_align((vl),type),(vl)+=sizeof(type),((type*)(vl))[-1])

#define va_start(ap, lastarg) ((ap)=(va_list)(&lastarg+1))
 
#define va_arg(vl,type) __va_mem(vl,type)
 
#define va_end(vl) ((vl)=0)

#if __STDC_VERSION__ >= 199901L
#define va_copy(new,old) ((new)=(old))
#endif

#endif
