#ifndef __STDARG_H
#define __STDARG_H 1

/*
  stdarg for qnice
*/

typedef char *va_list;

va_list __va_start(void);

#define __va_rounded_size(__TYPE)  sizeof(__TYPE)

#define va_start(__AP,__LA) (__AP=__va_start())

#define va_arg(__AP, __TYPE) \
 (__AP = ((char *) (__AP) + __va_rounded_size (__TYPE)),     \
  *((__TYPE *)((__AP) - __va_rounded_size (__TYPE))))

#define va_end(__AP) ((__AP) = 0)

#if __STDC_VERSION__ >= 199901L
#define va_copy(new,old) ((new)=(old))
#endif


#endif

